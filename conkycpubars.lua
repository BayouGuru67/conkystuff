require 'cairo'
require 'cairo_xlib'

-- === CONFIGURATION TABLES ===
local COLORS = {
    bg       = {0.251, 0.251, 0.251, 0.8},
    green    = {0, 1, 0, 1},
    yellow   = {1, 1, 0, 1},
    red      = {1, 0, 0, 1},
    orange   = {1, 0.549, 0, 1},
    lightblue= {0.678, 0.847, 0.902, 1},
}

local BAR_CONFIG = {
    {4,   26, 'cpu1',  25},
    {136, 26, 'cpu2',  25},
    {4,   54, 'cpu3',  25},
    {136, 54, 'cpu4',  25},
    {4,   82, 'cpu5',  25},
    {136, 82, 'cpu6',  25},
    {4,  110, 'cpu0',  51},
}
local GPU_BAR = {9, 159, 'exec', 'cat /sys/class/drm/card1/device/gpu_busy_percent', 100, 42}
local GPU_BAR_BLOCK_X_OFFSET = 50  -- <<<< Adjust this value as needed for your layout

local BAR_STYLE = {
    max = 100,
    cap = CAIRO_LINE_CAP_SQUARE, w = 8, h = 4, space = 1,
    bgc = COLORS.bg,    bga = 0.8,
    fgc = COLORS.green, fga = 1,
    alarm = 75,
    led_effect = true,  led_alpha = 0.8,
    rotation = 90,
}

local LEDS = {
    {x = 210, y = 15,  sensor = '${hwmon 4 temp 1}', thresholds = {green = 140, red = 155}},
    {x = 210, y = 147, sensor = '${hwmon 0 temp 1}', thresholds = {green = 170, red = 190}},
}

-- === PRECOMPUTED ANGLES ===
local ANGLE = (BAR_STYLE.rotation or 0) * math.pi / 180

-- === PRECOMPUTED BAR BLOCK GEOMETRY AND INACTIVE PATTERNS (CPU bars only) ===
local bar_block_geometry = {}     -- bar index -> { {x2, y2, xx1, yy1}, ... }
local bar_inactive_patterns = {}  -- bar index -> { [block_idx] = pattern }

local function precompute_bar_blocks(xb, yb, nb_blocks)
    local y_step = BAR_STYLE.h + BAR_STYLE.space
    local blocks = {}
    for pt = 1, nb_blocks do
        local radius = (pt - 1) * y_step
        local x2 = xb + radius * math.sin(ANGLE)
        local y2 = yb - radius * math.cos(ANGLE)
        local xx1 = x2 + BAR_STYLE.w * math.cos(ANGLE)
        local yy1 = y2 + BAR_STYLE.w * math.sin(ANGLE)
        blocks[pt] = {x2 = x2, y2 = y2, xx1 = xx1, yy1 = yy1}
    end
    return blocks
end

local function precompute_inactive_patterns(blocks)
    local patterns = {}
    local r, g, b, a = table.unpack(COLORS.bg)
    for pt, blk in ipairs(blocks) do
        local pat = cairo_pattern_create_linear(blk.x2, blk.y2, blk.x2, blk.yy1)
        cairo_pattern_add_color_stop_rgba(pat, 0, r, g, b, a * 0.4)
        cairo_pattern_add_color_stop_rgba(pat, 0.5, r, g, b, a)
        cairo_pattern_add_color_stop_rgba(pat, 1, r, g, b, a * 0.4)
        patterns[pt] = pat
    end
    return patterns
end

-- Precompute for CPU bars only
for idx, bar in ipairs(BAR_CONFIG) do
    local blocks = precompute_bar_blocks(bar[1], bar[2], bar[4])
    bar_block_geometry[idx] = blocks
    bar_inactive_patterns[idx] = precompute_inactive_patterns(blocks)
end

local function draw_block(cr, x2, y2, xx1, yy1, color, led_effect, led_alpha)
    local r, g, b, a = table.unpack(color)
    local pat = cairo_pattern_create_linear(x2, y2, x2, yy1)
    cairo_pattern_add_color_stop_rgba(pat, 0, r, g, b, a * 0.4)
    cairo_pattern_add_color_stop_rgba(pat, 0.5, r, g, b, a)
    cairo_pattern_add_color_stop_rgba(pat, 1, r, g, b, a * 0.4)
    cairo_set_source(cr, pat)
    cairo_move_to(cr, x2, y2)
    cairo_line_to(cr, xx1, yy1)
    cairo_stroke(cr)
    cairo_pattern_destroy(pat)
    if led_effect then
        local xc, yc = (x2 + xx1) * 0.5, (y2 + yy1) * 0.5
        local led_pat = cairo_pattern_create_radial(xc, yc, 0, xc, yc, (xx1-x2 + yy1-y2) * 0.25)
        cairo_pattern_add_color_stop_rgba(led_pat, 0, r, g, b, led_alpha)
        cairo_pattern_add_color_stop_rgba(led_pat, 1, r, g, b, a)
        cairo_set_source(cr, led_pat)
        cairo_stroke(cr)
        cairo_pattern_destroy(led_pat)
    end
end

local function equalizer_cpu(cr, bar_idx, name, arg, max, nb_blocks, style, show_percentage)
    local value = tonumber(conky_parse('${' .. name .. ' ' .. arg .. '}')) or 0
    local pct = math.min(100, math.max(0, 100 * value / max))
    local lit_blocks = math.floor(nb_blocks * pct / 100 + 0.5)
    local yellow_threshold, red_threshold = 75, 90

    cairo_set_line_width(cr, style.h)
    cairo_set_line_cap(cr, style.cap)
    local bar_blocks = bar_block_geometry[bar_idx]
    local inactive_patterns = bar_inactive_patterns[bar_idx]

    for pt = 1, nb_blocks do
        local blk = bar_blocks[pt]
        if pt <= lit_blocks then
            local block_pct_threshold = (pt - 1) * 100 / nb_blocks
            local color
            if block_pct_threshold < yellow_threshold then
                color = COLORS.green
            elseif block_pct_threshold < red_threshold then
                color = COLORS.yellow
            else
                color = COLORS.red
            end
            draw_block(cr, blk.x2, blk.y2, blk.xx1, blk.yy1, color, style.led_effect, style.led_alpha)
        else
            cairo_set_source(cr, inactive_patterns[pt])
            cairo_move_to(cr, blk.x2, blk.y2)
            cairo_line_to(cr, blk.xx1, blk.yy1)
            cairo_stroke(cr)
            if style.led_effect then
                local xc, yc = (blk.x2 + blk.xx1) * 0.5, (blk.y2 + blk.yy1) * 0.5
                local r, g, b, a = table.unpack(COLORS.bg)
                local led_pat = cairo_pattern_create_radial(xc, yc, 0, xc, yc, (blk.xx1-blk.x2 + blk.yy1-blk.y2) * 0.25)
                cairo_pattern_add_color_stop_rgba(led_pat, 0, r, g, b, style.led_alpha)
                cairo_pattern_add_color_stop_rgba(led_pat, 1, r, g, b, a)
                cairo_set_source(cr, led_pat)
                cairo_stroke(cr)
                cairo_pattern_destroy(led_pat)
            end
        end
    end
end

local function equalizer_gpu(cr, name, arg, max, nb_blocks, style, show_percentage, overlay_x, overlay_y)
    local value = tonumber(conky_parse('${' .. name .. ' ' .. arg .. '}')) or 0
    local pct = math.min(100, math.max(0, 100 * value / max))
    local lit_blocks = math.floor(nb_blocks * pct / 100 + 0.5)
    local yellow_threshold, red_threshold = 75, 90
    local y_step = BAR_STYLE.h + BAR_STYLE.space
    local angle = ANGLE

    -- Draw GPU percentage text overlay at the original location
    if show_percentage then
        local xb, yb = overlay_x, overlay_y
        cairo_new_path(cr)
        cairo_select_font_face(cr, "Larabiefont", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
        cairo_set_font_size(cr, 13)
        cairo_set_source_rgba(cr, table.unpack(COLORS.orange))
        local pct_text = string.format('%d', math.floor(pct + 0.5))
        local num_x_pos = xb + ((pct < 10 and 26) or (pct < 100 and 18) or 10)
        cairo_move_to(cr, num_x_pos, yb + 9)
        cairo_show_text(cr, pct_text)
        cairo_set_source_rgba(cr, table.unpack(COLORS.lightblue))
        cairo_move_to(cr, xb + 36, yb + 9)
        cairo_show_text(cr, "%")
    end

    -- Draw GPU bar blocks at offset X
    local xb, yb = GPU_BAR[1] + GPU_BAR_BLOCK_X_OFFSET, GPU_BAR[2]
    cairo_set_line_width(cr, style.h)
    cairo_set_line_cap(cr, style.cap)

    for pt = 1, nb_blocks do
        local radius = (pt - 1) * y_step
        local x2 = xb + radius * math.sin(angle)
        local y2 = yb - radius * math.cos(angle)
        local xx1 = x2 + BAR_STYLE.w * math.cos(angle)
        local yy1 = y2 + BAR_STYLE.w * math.sin(angle)
        if pt <= lit_blocks then
            local block_pct_threshold = (pt - 1) * 100 / nb_blocks
            local color
            if block_pct_threshold < yellow_threshold then
                color = COLORS.green
            elseif block_pct_threshold < red_threshold then
                color = COLORS.yellow
            else
                color = COLORS.red
            end
            draw_block(cr, x2, y2, xx1, yy1, color, style.led_effect, style.led_alpha)
        else
            local r, g, b, a = table.unpack(COLORS.bg)
            local pat = cairo_pattern_create_linear(x2, y2, x2, yy1)
            cairo_pattern_add_color_stop_rgba(pat, 0, r, g, b, a * 0.4)
            cairo_pattern_add_color_stop_rgba(pat, 0.5, r, g, b, a)
            cairo_pattern_add_color_stop_rgba(pat, 1, r, g, b, a * 0.4)
            cairo_set_source(cr, pat)
            cairo_move_to(cr, x2, y2)
            cairo_line_to(cr, xx1, yy1)
            cairo_stroke(cr)
            cairo_pattern_destroy(pat)
            if style.led_effect then
                local xc, yc = (x2 + xx1) * 0.5, (y2 + yy1) * 0.5
                local led_pat = cairo_pattern_create_radial(xc, yc, 0, xc, yc, (xx1-x2 + yy1-y2) * 0.25)
                cairo_pattern_add_color_stop_rgba(led_pat, 0, r, g, b, style.led_alpha)
                cairo_pattern_add_color_stop_rgba(led_pat, 1, r, g, b, a)
                cairo_set_source(cr, led_pat)
                cairo_stroke(cr)
                cairo_pattern_destroy(led_pat)
            end
        end
    end
end

local function draw_led(cr, x, y, value, thresholds)
    local color
    if type(value) ~= "number" then value = thresholds.red + 1 end
    if value <= thresholds.green then
        color = COLORS.green
    elseif value >= thresholds.red then
        color = COLORS.red
    else
        color = COLORS.yellow
    end
    local r, g, b, a = table.unpack(color)
    local radius = 8
    local pat = cairo_pattern_create_radial(x, y, 0, x, y, radius)
    cairo_pattern_add_color_stop_rgba(pat, 0.0, r, g, b, a)
    cairo_pattern_add_color_stop_rgba(pat, 0.5, r, g, b, a)
    cairo_pattern_add_color_stop_rgba(pat, 1.0, r, g, b, 0.0)
    cairo_set_source(cr, pat)
    cairo_arc(cr, x, y, radius, 0, 2 * math.pi)
    cairo_fill(cr)
    cairo_pattern_destroy(pat)
end

function conky_conkycpubars_draw_pre()
    if conky_window == nil then return end
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
        conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)
    cairo_set_source_rgba(cr, 0.431, 0.133, 0.710, 0.3)
    cairo_rectangle(cr, 4, 50, 260, 28)
    cairo_rectangle(cr, 4, 106, 260, 28)
    cairo_fill(cr)
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

function conky_conkycpubars_widgets()
    if conky_window == nil then return end
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
        conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)
    -- CPU Bars
    for idx, bar in ipairs(BAR_CONFIG) do
        equalizer_cpu(cr, idx, 'cpu', bar[3], BAR_STYLE.max, bar[4], BAR_STYLE, false)
    end
    -- GPU Bar (shows percentage); overlay text at original, blocks at offset
    equalizer_gpu(cr, GPU_BAR[3], GPU_BAR[4], GPU_BAR[5], GPU_BAR[6], BAR_STYLE, true, GPU_BAR[1], GPU_BAR[2])
    -- LEDs
    for _, led in ipairs(LEDS) do
        local value = tonumber(conky_parse(led.sensor))
        draw_led(cr, led.x, led.y, value, led.thresholds)
    end
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

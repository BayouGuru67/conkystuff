require 'cairo'
require 'cairo_xlib'

-- === CONFIGURATION TABLES ===
local COLORS = {
    bg       = {0.251, 0.251, 0.251, 0.8},    -- 0x404040, 0.8
    green    = {0, 1, 0, 1},                  -- 0x00ff00, 1
    yellow   = {1, 1, 0, 1},                  -- 0xffff00, 1
    red      = {1, 0, 0, 1},                  -- 0xff0000, 1
    orange   = {1, 0.549, 0, 1},              -- 0xFF8C00, 1
    lightblue= {0.678, 0.847, 0.902, 1},      -- 0xADD8E6, 1
}

local BAR_CONFIG = {
    -- {x, y, conky_arg, blocks}
    {4,   26, 'cpu1',  25},
    {136, 26, 'cpu2',  25},
    {4,   54, 'cpu3',  25},
    {136, 54, 'cpu4',  25},
    {4,   82, 'cpu5',  25},
    {136, 82, 'cpu6',  25},
    {4,  110, 'cpu0',  51}, -- CPU average
}
local GPU_BAR = {9, 159, 'exec', 'cat /sys/class/drm/card1/device/gpu_busy_percent', 100, 42}

local BAR_STYLE = {
    max = 100,
    cap = CAIRO_LINE_CAP_SQUARE, w = 8, h = 4, space = 1,
    bgc = COLORS.bg,    bga = 0.8,
    fgc = COLORS.green, fga = 1,
    alarm = 75,         -- yellow @75, red @90
    led_effect = true,  led_alpha = 0.8,
    rotation = 90,
}

local LEDS = {
    {x = 210, y = 15,  sensor = '${hwmon 4 temp 1}', thresholds = {green = 140, red = 155}},
    {x = 210, y = 147, sensor = '${hwmon 0 temp 1}', thresholds = {green = 170, red = 190}},
}

-- === PRECOMPUTED ANGLES ===
local ANGLE = (BAR_STYLE.rotation or 0) * math.pi / 180
local COS_ANGLE, SIN_ANGLE = math.cos(ANGLE), math.sin(ANGLE)

-- === LOCAL HELPERS ===
local function draw_block(cr, x2, y2, w, angle, color, led_effect, led_alpha, pattern_cache)
    local r, g, b, a = table.unpack(color)
    local xx1 = x2 + w * math.cos(angle)
    local yy1 = y2 + w * math.sin(angle)
    local pat_key = string.format("%.3f,%.3f,%.3f,%.3f,%.1f", r, g, b, a, w)
    local pat = pattern_cache[pat_key]
    if not pat then
        pat = cairo_pattern_create_linear(x2, y2, x2, yy1)
        cairo_pattern_add_color_stop_rgba(pat, 0, r, g, b, a * 0.4)
        cairo_pattern_add_color_stop_rgba(pat, 0.5, r, g, b, a)
        cairo_pattern_add_color_stop_rgba(pat, 1, r, g, b, a * 0.4)
        pattern_cache[pat_key] = pat
    end
    cairo_set_source(cr, pat)
    cairo_move_to(cr, x2, y2)
    cairo_line_to(cr, xx1, yy1)
    cairo_stroke(cr)
    if led_effect then
        local xc, yc = (x2 + xx1) * 0.5, (y2 + yy1) * 0.5
        local led_pat = cairo_pattern_create_radial(xc, yc, 0, xc, yc, w * 0.5)
        cairo_pattern_add_color_stop_rgba(led_pat, 0, r, g, b, led_alpha)
        cairo_pattern_add_color_stop_rgba(led_pat, 1, r, g, b, a)
        cairo_set_source(cr, led_pat)
        cairo_stroke(cr)
        cairo_pattern_destroy(led_pat)
    end
end

local function equalizer(cr, xb, yb, name, arg, max, nb_blocks, style, show_percentage)
    local value = tonumber(conky_parse('${' .. name .. ' ' .. arg .. '}')) or 0
    local pct = math.min(100, math.max(0, 100 * value / max))
    local pcb = 100 / nb_blocks
    local angle = ANGLE
    local yellow_threshold, red_threshold = 75, 90

    if show_percentage then
        cairo_new_path(cr)
        cairo_select_font_face(cr, "Larabiefont", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
        cairo_set_font_size(cr, 13)
        cairo_set_source_rgba(cr, table.unpack(COLORS.orange))
        local pct_text = string.format('%d', math.floor(pct + 0.5))
        local num_x_pos = xb + ( (pct < 10 and 26) or (pct < 100 and 18) or 10 )
        cairo_move_to(cr, num_x_pos, yb + 9)
        cairo_show_text(cr, pct_text)
        cairo_set_source_rgba(cr, table.unpack(COLORS.lightblue))
        cairo_move_to(cr, xb + 36, yb + 9)
        cairo_show_text(cr, "%")
        xb = xb + 44
    end

    cairo_set_line_width(cr, style.h)
    cairo_set_line_cap(cr, style.cap)
    local y_step = style.h + style.space
    local pattern_cache = {}
    for pt = 1, nb_blocks do
        local block_pct_threshold = (pt - 1) * pcb
        local color
        if pct >= block_pct_threshold then
            if block_pct_threshold < yellow_threshold then
                color = COLORS.green
            elseif block_pct_threshold < red_threshold then
                color = COLORS.yellow
            else
                color = COLORS.red
            end
        else
            color = COLORS.bg
        end
        local radius = pt * y_step
        local x2 = xb + radius * math.sin(angle)
        local y2 = yb - radius * math.cos(angle)
        draw_block(cr, x2, y2, style.w, angle, color, style.led_effect, style.led_alpha, pattern_cache)
    end
    for _, pat in pairs(pattern_cache) do cairo_pattern_destroy(pat) end
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

-- === CONKY HOOKS ===
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
    for _, bar in ipairs(BAR_CONFIG) do
        equalizer(cr, bar[1], bar[2], 'cpu', bar[3], BAR_STYLE.max, bar[4], BAR_STYLE, false)
    end
    -- GPU Bar (shows percentage)
    equalizer(cr, GPU_BAR[1], GPU_BAR[2], GPU_BAR[3], GPU_BAR[4], GPU_BAR[5], GPU_BAR[6], BAR_STYLE, true)
    -- LEDs
    for _, led in ipairs(LEDS) do
        local value = tonumber(conky_parse(led.sensor))
        draw_led(cr, led.x, led.y, value, led.thresholds)
    end
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

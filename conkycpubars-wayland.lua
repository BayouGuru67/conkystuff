require 'cairo'

-- ============================================================
-- USER CONFIGURATION – POSITIONING
-- Edit these values to adjust bar and LED positions
-- ============================================================

-- CPU bar positions: {x, y, cpu_name, num_blocks}
local CPU_BAR_POSITIONS = {
    {6,   20,  'cpu1',  30},
    {136, 20,  'cpu2',  30},
    {6,   49,  'cpu3',  30},
    {136, 49,  'cpu4',  30},
    {6,   78,  'cpu5',  30},
    {136, 78,  'cpu6',  30},
    {6,   107, 'cpu7',  30},
    {136, 107, 'cpu8',  30},
    {6,   136, 'cpu9',  30},
    {136, 136, 'cpu10', 30},
    {6,   165, 'cpu11', 30},
    {136, 165, 'cpu12', 30},
    {6,   193, 'cpu',  63},  -- Average
}

-- GPU bar positions
-- block_x/y = where the bar blocks start
local GPU_BAR_POSITIONS = {
    {
        card = "card1",      -- RX580
        block_x = 42, block_y = 235,
        nb_blocks = 54
    },
    {
        card = "card0",      -- Integrated GPU
        block_x = 42, block_y = 282,
        nb_blocks = 54
    }
}

-- LED positions: {x, y, sensor, thresholds}
local LED_POSITIONS = {
    {x = 210, y = 10,  sensor = '${hwmon 4 temp 1}', thresholds = {green = 140, red = 155}},
    {x = 210, y = 223, sensor = '${hwmon 7 temp 1}', thresholds = {green = 140, red = 155}},
    {x = 210, y = 269, sensor = '${hwmon 8 temp 1}', thresholds = {green = 140, red = 155}}
}

-- Bar style
local BAR_STYLE = {
    max = 100,
    cap = CAIRO_LINE_CAP_SQUARE,
    w = 8,
    h = 3,
    space = 1,
    led_effect = true,
    led_alpha = 0.7,
    rotation = 90,
    alarm = 75,
    high_alarm = 90,
}

-- ============================================================
-- END USER CONFIGURATION
-- ============================================================

-- === COLORS ===
local COLORS = {
    bg       = {0.251, 0.251, 0.251, 0.8},
    green    = {0, 1, 0, 1},
    yellow   = {1, 1, 0, 1},
    red      = {1, 0, 0, 1},
    orange   = {1, 0.549, 0, 1},
    lightblue= {0.678, 0.847, 0.902, 1},
}

-- === BUILD CONFIG TABLES FROM USER POSITIONS ===
local BAR_CONFIG = {}
for _, pos in ipairs(CPU_BAR_POSITIONS) do
    table.insert(BAR_CONFIG, {pos[1], pos[2], pos[3], pos[4]})
end

local GPU_BARS = GPU_BAR_POSITIONS
local LEDS = LED_POSITIONS

-- === PRECOMPUTED ANGLES & BAR BLOCKS ===
local ANGLE = (BAR_STYLE.rotation or 0) * math.pi / 180
local COS_ANGLE, SIN_ANGLE = math.cos(ANGLE), math.sin(ANGLE)

local bar_block_geometry = {}
local bar_active_patterns = {}
local bar_inactive_patterns = {}
local bar_led_geometry = {}

local function precompute_bar_blocks(xb, yb, nb_blocks)
    local y_step = BAR_STYLE.h + BAR_STYLE.space
    local blocks = {}
    for pt = 1, nb_blocks do
        local radius = (pt - 1) * y_step
        local x2 = xb + radius * SIN_ANGLE
        local y2 = yb - radius * COS_ANGLE
        local xx1 = x2 + BAR_STYLE.w * COS_ANGLE
        local yy1 = y2 + BAR_STYLE.w * SIN_ANGLE
        blocks[pt] = {x2 = x2, y2 = y2, xx1 = xx1, yy1 = yy1}
    end
    return blocks
end

local function precompute_patterns(blocks, nb_blocks, is_active, threshold)
    local patterns = {}
    for pt, blk in ipairs(blocks) do
        local r, g, b, a
        if is_active then
            local block_pct = (pt - 1) * 100 / nb_blocks
            local color
            if block_pct < BAR_STYLE.alarm then
                color = COLORS.green
            elseif block_pct < BAR_STYLE.high_alarm then
                color = COLORS.yellow
            else
                color = COLORS.red
            end
            r, g, b, a = table.unpack(color)
        else
            r, g, b, a = table.unpack(COLORS.bg)
        end
        local pat = cairo_pattern_create_linear(blk.x2, blk.y2, blk.x2, blk.yy1)
        cairo_pattern_add_color_stop_rgba(pat, 0, r, g, b, a * 0.4)
        cairo_pattern_add_color_stop_rgba(pat, 0.5, r, g, b, a)
        cairo_pattern_add_color_stop_rgba(pat, 1, r, g, b, a * 0.4)
        patterns[pt] = pat
    end
    return patterns
end

local function precompute_led_geometry(blocks)
    local leds = {}
    for pt, blk in ipairs(blocks) do
        local xc, yc = (blk.x2 + blk.xx1) * 0.5, (blk.y2 + blk.yy1) * 0.5
        local radius = (blk.xx1 - blk.x2 + blk.yy1 - blk.y2) * 0.25
        leds[pt] = {xc = xc, yc = yc, radius = radius}
    end
    return leds
end

for idx, bar in ipairs(BAR_CONFIG) do
    local blocks = precompute_bar_blocks(bar[1], bar[2], bar[4])
    bar_block_geometry[idx] = blocks
    bar_active_patterns[idx] = precompute_patterns(blocks, bar[4], true)
    bar_inactive_patterns[idx] = precompute_patterns(blocks, bar[4], false)
    bar_led_geometry[idx] = precompute_led_geometry(blocks)
end

-- Precompute GPU bar data
local gpu_geometry = {}
local gpu_active_patterns = {}
local gpu_inactive_patterns = {}
local gpu_led_geometry = {}

for idx, gpu in ipairs(GPU_BARS) do
    local blocks = {}
    local y_step = BAR_STYLE.h + BAR_STYLE.space
    for pt = 1, gpu.nb_blocks do
        local radius = (pt - 1) * y_step
        local x2 = gpu.block_x + radius * SIN_ANGLE
        local y2 = gpu.block_y - radius * COS_ANGLE
        local xx1 = x2 + BAR_STYLE.w * COS_ANGLE
        local yy1 = y2 + BAR_STYLE.w * SIN_ANGLE
        blocks[pt] = {x2 = x2, y2 = y2, xx1 = xx1, yy1 = yy1}
    end
    gpu_geometry[idx] = blocks
    gpu_active_patterns[idx] = precompute_patterns(blocks, gpu.nb_blocks, true)
    gpu_inactive_patterns[idx] = precompute_patterns(blocks, gpu.nb_blocks, false)
    gpu_led_geometry[idx] = precompute_led_geometry(blocks)
end

-- === GPU READ ===
local function get_gpu_usage(card)
    local value = tonumber(conky_parse('${exec cat /sys/class/drm/' .. card .. '/device/gpu_busy_percent}')) or 0
    if value < 0 then value = 0 end
    if value > 100 then value = 100 end
    return value
end

-- === DRAWING HELPERS ===
local function draw_block_with_pattern(cr, blk, pattern)
    cairo_set_source(cr, pattern)
    cairo_move_to(cr, blk.x2, blk.y2)
    cairo_line_to(cr, blk.xx1, blk.yy1)
    cairo_stroke(cr)
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

-- === CPU BAR DRAWING ===
local function equalizer_cpu(cr, bar_idx, name, arg, max, nb_blocks, style)
    local value = tonumber(conky_parse('${' .. name .. ' ' .. arg .. '}')) or 0
    local pct = math.min(100, math.max(0, 100 * value / max))
    local lit_blocks = math.floor(nb_blocks * pct / 100 + 0.5)

    cairo_set_line_width(cr, style.h)
    cairo_set_line_cap(cr, style.cap)

    local blocks = bar_block_geometry[bar_idx]
    local active_patterns = bar_active_patterns[bar_idx]
    local inactive_patterns = bar_inactive_patterns[bar_idx]
    local leds = bar_led_geometry[bar_idx]

    for pt = 1, nb_blocks do
        local blk = blocks[pt]
        if pt <= lit_blocks then
            draw_block_with_pattern(cr, blk, active_patterns[pt])
            if style.led_effect then
                local led = leds[pt]
                local block_pct = (pt - 1) * 100 / nb_blocks
                local color
                if block_pct < BAR_STYLE.alarm then
                    color = COLORS.green
                elseif block_pct < BAR_STYLE.high_alarm then
                    color = COLORS.yellow
                else
                    color = COLORS.red
                end
                local r, g, b, a = table.unpack(color)
                local led_pat = cairo_pattern_create_radial(led.xc, led.yc, 0, led.xc, led.yc, led.radius)
                cairo_pattern_add_color_stop_rgba(led_pat, 0, r, g, b, style.led_alpha)
                cairo_pattern_add_color_stop_rgba(led_pat, 1, r, g, b, a)
                cairo_set_source(cr, led_pat)
                cairo_stroke(cr)
                cairo_pattern_destroy(led_pat)
            end
        else
            draw_block_with_pattern(cr, blk, inactive_patterns[pt])
        end
    end
end

-- === GPU BAR DRAWING ===
local function draw_gpu_bar(cr, idx, gpu)
    local value = get_gpu_usage(gpu.card)
    local pct = math.min(100, math.max(0, value))
    local lit_blocks = math.floor(gpu.nb_blocks * pct / 100 + 0.5)

    cairo_set_line_width(cr, BAR_STYLE.h)
    cairo_set_line_cap(cr, BAR_STYLE.cap)

    local blocks = gpu_geometry[idx]
    local active_patterns = gpu_active_patterns[idx]
    local inactive_patterns = gpu_inactive_patterns[idx]
    local leds = gpu_led_geometry[idx]

    for pt = 1, gpu.nb_blocks do
        local blk = blocks[pt]
        if pt <= lit_blocks then
            draw_block_with_pattern(cr, blk, active_patterns[pt])
            if BAR_STYLE.led_effect then
                local led = leds[pt]
                local block_pct = (pt - 1) * 100 / gpu.nb_blocks
                local color
                if block_pct < BAR_STYLE.alarm then
                    color = COLORS.green
                elseif block_pct < BAR_STYLE.high_alarm then
                    color = COLORS.yellow
                else
                    color = COLORS.red
                end
                local r, g, b, a = table.unpack(color)
                local led_pat = cairo_pattern_create_radial(led.xc, led.yc, 0, led.xc, led.yc, led.radius)
                cairo_pattern_add_color_stop_rgba(led_pat, 0, r, g, b, BAR_STYLE.led_alpha)
                cairo_pattern_add_color_stop_rgba(led_pat, 1, r, g, b, a)
                cairo_set_source(cr, led_pat)
                cairo_stroke(cr)
                cairo_pattern_destroy(led_pat)
            end
        else
            draw_block_with_pattern(cr, blk, inactive_patterns[pt])
        end
    end
end

-- === CONKY HOOKS (Wayland) ===
function conky_conkycpubars_draw_pre()
    return
end

function conky_conkycpubars_widgets()
    local surface = conky_surface()
    if not surface then return end
    local cr = cairo_create(surface)
    if not cr then return end

    -- Draw CPU bars
    for idx, bar in ipairs(BAR_CONFIG) do
        equalizer_cpu(cr, idx, 'cpu', bar[3], BAR_STYLE.max, bar[4], BAR_STYLE)
    end

    -- Draw GPU bars
    for idx, gpu in ipairs(GPU_BARS) do
        draw_gpu_bar(cr, idx, gpu)
    end

    -- Draw LEDs
    for _, led in ipairs(LEDS) do
        local value = tonumber(conky_parse(led.sensor))
        draw_led(cr, led.x, led.y, value, led.thresholds)
    end

    cairo_destroy(cr)
    cairo_surface_flush(surface)
end

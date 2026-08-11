require 'cairo'

-- ============================================================
-- USER CONFIGURATION – POSITIONING (bars and LEDs)
-- ============================================================

-- Bar positions: {xb, yb, name, arg, max, nb_blocks}
local BAR_CONFIG = {
    {xb = 18, yb = 129, name = 'memperc',        arg = '',                              max = 100, nb_blocks = 60},
    {xb = 18, yb = 255, name = 'fs_used_perc',   arg = '/',                             max = 100, nb_blocks = 60},
    {xb = 18, yb = 323, name = 'fs_used_perc',   arg = '/home/bayouguru/PNY-500Gb/',    max = 100, nb_blocks = 60},
    {xb = 18, yb = 391, name = 'swapperc',       arg = '',                              max = 100, nb_blocks = 60},
}

-- LED positions
-- For temperature sensors, thresholds are in Fahrenheit
-- For keyboard LEDs, we use the 'path' field instead of 'sensor'
local LEDS = {
    -- System temperature sensors
    {x = 90,   y = 7, sensor = '${hwmon 5 temp 3}', thresholds = {green = 158, red = 185}, label = 'Skt'},
    {x = 186,   y = 7, sensor = '${hwmon 5 temp 1}', thresholds = {green = 140, red = 167}, label = 'Brd'},
    {x = 211,   y = 243, sensor = '${hwmon 5 temp 1}', thresholds = {green = 158, red = 185}, label = 'NVMe'},
    {x = 211,   y = 310, sensor = '${hwmon 5 temp 1}', thresholds = {green = 140, red = 167}, label = 'PNY'},
    -- Keyboard LEDs (reading directly from sysfs)
    {x = 120,  y = 55,  path = '/sys/class/leds/input4::capslock/brightness', label = 'CapsLock'},
    {x = 250,  y = 55,  path = '/sys/class/leds/input4::numlock/brightness',  label = 'NumLock'},
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
    bg    = {0.251, 0.251, 0.251, 0.8},
    green = {0, 1, 0, 1},
    yellow= {1, 1, 0, 1},
    red   = {1, 0, 0, 1},
}

-- === PRECOMPUTE BAR BLOCKS ===
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

local function precompute_patterns(blocks, nb_blocks, is_active)
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
    local blocks = precompute_bar_blocks(bar.xb, bar.yb, bar.nb_blocks)
    bar_block_geometry[idx] = blocks
    bar_active_patterns[idx] = precompute_patterns(blocks, bar.nb_blocks, true)
    bar_inactive_patterns[idx] = precompute_patterns(blocks, bar.nb_blocks, false)
    bar_led_geometry[idx] = precompute_led_geometry(blocks)
end

-- === HELPER: Read a sysfs file ===
local function read_sysfs_file(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*all")
    file:close()
    if content then
        content = content:gsub("%s+", "")
        return tonumber(content) or 0
    end
    return 0
end

-- === DRAWING HELPERS ===
local function draw_block_with_pattern(cr, blk, pattern)
    cairo_set_source(cr, pattern)
    cairo_move_to(cr, blk.x2, blk.y2)
    cairo_line_to(cr, blk.xx1, blk.yy1)
    cairo_stroke(cr)
end

local function draw_led(cr, x, y, state, thresholds, is_keyboard_led, led)
    local color

    if is_keyboard_led then
        if led.label == "CapsLock" then
            color = (state == 1) and COLORS.red or COLORS.green
        elseif led.label == "NumLock" then
            color = (state == 1) and COLORS.green or COLORS.red
        else
            color = (state == 1) and COLORS.green or COLORS.red
        end
    else
        if type(state) ~= "number" then state = thresholds.red + 1 end
        if state <= thresholds.green then
            color = COLORS.green
        elseif state >= thresholds.red then
            color = COLORS.red
        else
            color = COLORS.yellow
        end
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

-- === BAR DRAWING ===
local function draw_bar(cr, bar_idx, bar)
    local value = tonumber(conky_parse(string.format('${%s %s}', bar.name, bar.arg))) or 0
    local pct = math.min(100, math.max(0, 100 * value / bar.max))
    local lit_blocks = math.floor(bar.nb_blocks * pct / 100 + 0.5)

    cairo_set_line_width(cr, BAR_STYLE.h)
    cairo_set_line_cap(cr, BAR_STYLE.cap)

    local blocks = bar_block_geometry[bar_idx]
    local active_patterns = bar_active_patterns[bar_idx]
    local inactive_patterns = bar_inactive_patterns[bar_idx]
    local leds = bar_led_geometry[bar_idx]

    for pt = 1, bar.nb_blocks do
        local blk = blocks[pt]
        if pt <= lit_blocks then
            draw_block_with_pattern(cr, blk, active_patterns[pt])
            if BAR_STYLE.led_effect then
                local led = leds[pt]
                local r, g, b, a = table.unpack(COLORS.green) -- Approximate, but pattern handles actual color
                -- Recreate LED with proper color from active pattern
                local block_pct = (pt - 1) * 100 / bar.nb_blocks
                local color
                if block_pct < BAR_STYLE.alarm then
                    color = COLORS.green
                elseif block_pct < BAR_STYLE.high_alarm then
                    color = COLORS.yellow
                else
                    color = COLORS.red
                end
                local cr2, cg, cb, ca = table.unpack(color)
                local led_pat = cairo_pattern_create_radial(led.xc, led.yc, 0, led.xc, led.yc, led.radius)
                cairo_pattern_add_color_stop_rgba(led_pat, 0, cr2, cg, cb, BAR_STYLE.led_alpha)
                cairo_pattern_add_color_stop_rgba(led_pat, 1, cr2, cg, cb, ca)
                cairo_set_source(cr, led_pat)
                cairo_stroke(cr)
                cairo_pattern_destroy(led_pat)
            end
        else
            draw_block_with_pattern(cr, blk, inactive_patterns[pt])
        end
    end
end

-- === CONKY HOOK (Wayland) ===
function conky_draw_post()
    local surface = conky_surface()
    if not surface then return end
    local cr = cairo_create(surface)
    if not cr then return end

    -- Draw bars
    for idx, bar in ipairs(BAR_CONFIG) do
        draw_bar(cr, idx, bar)
    end

    -- Draw LEDs
    for _, led in ipairs(LEDS) do
        local state, thresholds
        local is_keyboard_led = false

        if led.path then
            state = read_sysfs_file(led.path)
            thresholds = {green = 1, red = 0}
            is_keyboard_led = true
        elseif led.sensor then
            state = tonumber(conky_parse(led.sensor))
            thresholds = led.thresholds
            is_keyboard_led = false
        else
            goto continue
        end

        draw_led(cr, led.x, led.y, state, thresholds, is_keyboard_led, led)

        ::continue::
    end

    cairo_destroy(cr)
    cairo_surface_flush(surface)
end

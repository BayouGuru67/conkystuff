require 'cairo'

-- ============================================================
-- USER CONFIGURATION – POSITIONING (bars and LEDs)
-- ============================================================

-- Bar positions: {xb, yb, name, arg, max, nb_blocks}
local BAR_CONFIG = {
    {xb = 18, yb = 128, name = 'memperc',        arg = '',                              max = 100, nb_blocks = 49},
    {xb = 18, yb = 251, name = 'fs_used_perc',   arg = '/',                             max = 100, nb_blocks = 49},
    {xb = 18, yb = 319, name = 'fs_used_perc',   arg = '/home/bayouguru/PNY-500Gb/',    max = 100, nb_blocks = 49},
    {xb = 18, yb = 387, name = 'swapperc',       arg = '',                              max = 100, nb_blocks = 49},
}

-- LED positions
-- For temperature sensors, thresholds are in Fahrenheit
-- For keyboard LEDs, we use the 'path' field instead of 'sensor'
local LEDS = {
    -- Ssystem temperature sensors
    {x = 90,   y = 7, sensor = '${hwmon 6 temp 3}', thresholds = {green = 158, red = 185}, label = 'Skt'},
    {x = 186,   y = 7, sensor = '${hwmon 6 temp 1}', thresholds = {green = 140, red = 167}, label = 'Brd'},
    {x = 211,   y = 239, sensor = '${hwmon 2 temp 1}', thresholds = {green = 158, red = 185}, label = 'NVMe'},
    {x = 211,   y = 306, sensor = '${hwmon 3 temp 1}', thresholds = {green = 140, red = 167}, label = 'PNY'},
    -- Keyboard LEDs (reading directly from sysfs)
    {x = 120,  y = 55,  path = '/sys/class/leds/input4::capslock/brightness', label = 'CapsLock'},
    {x = 250,  y = 55,  path = '/sys/class/leds/input4::numlock/brightness',  label = 'NumLock'},
}

-- Bar style
local BAR_STYLE = {
    max = 100,
    cap = CAIRO_LINE_CAP_SQUARE,
    w = 8,
    h = 4,
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
local bar_inactive_patterns = {}

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

        for idx, bar in ipairs(BAR_CONFIG) do
            local blocks = precompute_bar_blocks(bar.xb, bar.yb, bar.nb_blocks)
            bar_block_geometry[idx] = blocks
            bar_inactive_patterns[idx] = precompute_inactive_patterns(blocks)
            end

            -- === HELPER: Read a sysfs file ===
            local function read_sysfs_file(path)
            local file = io.open(path, "r")
            if not file then return nil end
                local content = file:read("*all")
                file:close()
                if content then
                    content = content:gsub("%s+", "")  -- Remove whitespace
                    return tonumber(content) or 0
                    end
                    return 0
                    end

                    -- === DRAWING HELPERS ===
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

                        local function draw_led(cr, x, y, state, thresholds, is_keyboard_led, led)
                        local color

                        if is_keyboard_led then
                            -- Keyboard LED: state is 0 or 1 (brightness)
                            if led.label == "CapsLock" then
                                -- CapsLock: Green when off (0), Red when on (1)
                                color = (state == 1) and COLORS.red or COLORS.green
                                elseif led.label == "NumLock" then
                                    -- NumLock: Red when off (0), Green when on (1)
                                    color = (state == 1) and COLORS.green or COLORS.red
                                    else
                                        -- Default behavior for any other keyboard LEDs
                                        color = (state == 1) and COLORS.green or COLORS.red
                                        end
                                        else
                                            -- Temperature/percentage LED: use thresholds
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
                                                            local inactive_patterns = bar_inactive_patterns[bar_idx]

                                                            for pt = 1, bar.nb_blocks do
                                                                local blk = blocks[pt]
                                                                if pt <= lit_blocks then
                                                                    local block_pct = (pt - 1) * 100 / bar.nb_blocks
                                                                    local color
                                                                    if block_pct < BAR_STYLE.alarm then
                                                                        color = COLORS.green
                                                                        elseif block_pct < BAR_STYLE.high_alarm then
                                                                            color = COLORS.yellow
                                                                            else
                                                                                color = COLORS.red
                                                                                end
                                                                                draw_block(cr, blk.x2, blk.y2, blk.xx1, blk.yy1, color, BAR_STYLE.led_effect, BAR_STYLE.led_alpha)
                                                                                else
                                                                                    cairo_set_source(cr, inactive_patterns[pt])
                                                                                    cairo_move_to(cr, blk.x2, blk.y2)
                                                                                    cairo_line_to(cr, blk.xx1, blk.yy1)
                                                                                    cairo_stroke(cr)
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
                                                                                                        -- This is a keyboard LED, read from sysfs
                                                                                                        state = read_sysfs_file(led.path)
                                                                                                        thresholds = {green = 1, red = 0}  -- Dummy thresholds
                                                                                                        is_keyboard_led = true
                                                                                                        elseif led.sensor then
                                                                                                            -- This is a temperature or percentage sensor
                                                                                                            state = tonumber(conky_parse(led.sensor))
                                                                                                            thresholds = led.thresholds
                                                                                                            is_keyboard_led = false
                                                                                                            else
                                                                                                                -- Skip if neither path nor sensor is defined
                                                                                                                goto continue
                                                                                                                end

                                                                                                                draw_led(cr, led.x, led.y, state, thresholds, is_keyboard_led, led)

                                                                                                                ::continue::
                                                                                                                end

                                                                                                                cairo_destroy(cr)
    cairo_surface_flush(surface)
    end

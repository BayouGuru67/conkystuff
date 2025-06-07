require 'cairo'
require 'cairo_xlib'

-- Global constant for converting degrees to radians, calculated once.
local RAD_TO_DEG = math.pi / 180

-- Helper function: Convert hex color to RGBA components.
-- This function is called once per unique color in draw_block and draw_led,
-- and its results are then reused with different alpha values.
local function rgb_to_r_g_b_components(colour)
    return ((colour / 0x10000) % 0x100) / 255., ((colour / 0x100) % 0x100) / 255., (colour % 0x100) / 255.
end

-- Helper function: Draw a single block with 3D effect and LED effect
-- Optimized to receive pre-calculated sine and cosine of the angle.
local function draw_block(cr, x2, y2, w, cos_angle, sin_angle, col, alpha, led_effect, led_alpha)
    local xx0, xx1, yy0, yy1
    -- Determine block endpoints based on pre-calculated sin/cos.
    -- The original script had a conditional for angle == 90 or 270, which implies
    -- that 'angle' was sometimes passed in degrees, but then math.cos/sin were used.
    -- Assuming 'angle' in equalizer is always 90 for vertical bars,
    -- cos(90) = 0, sin(90) = 1.
    -- This simplifies to xx0 = x2, xx1 = x2 + w * 0 = x2
    -- yy0 = y2, yy1 = y2 + w * 1 = y2 + w
    -- which matches the original if-block for angle 90/270.
    -- For other angles, it will use the general formula.
    xx0, xx1 = x2, x2 + w * cos_angle
    yy0, yy1 = y2, y2 + w * sin_angle

    -- Pre-calculate RGB components to avoid repeated divisions/modulos.
    local r, g, b = rgb_to_r_g_b_components(col)

    -- 3D Gradient Effect
    local pat = cairo_pattern_create_linear(xx0, yy0, xx0, yy1)
    cairo_pattern_add_color_stop_rgba(pat, 0, r, g, b, alpha * 0.4)  -- Darker top
    cairo_pattern_add_color_stop_rgba(pat, 0.5, r, g, b, alpha)      -- Normal middle
    cairo_pattern_add_color_stop_rgba(pat, 1, r, g, b, alpha * 0.4)  -- Darker bottom
    cairo_set_source(cr, pat)

    cairo_move_to(cr, xx0, yy0)
    cairo_line_to(cr, xx1, yy1)
    cairo_stroke(cr)
    cairo_pattern_destroy(pat)

    -- Optional LED Effect Overlay
    if led_effect then
        local xc, yc = (xx0 + xx1) / 2, (yy0 + yy1) / 2
        local led_pat = cairo_pattern_create_radial(xc, yc, 0, xc, yc, w / 2)
        -- Reuse r, g, b components
        cairo_pattern_add_color_stop_rgba(led_pat, 0, r, g, b, led_alpha)
        cairo_pattern_add_color_stop_rgba(led_pat, 1, r, g, b, alpha)
        cairo_set_source(cr, led_pat)
        cairo_stroke(cr)
        cairo_pattern_destroy(led_pat)
    end
end

-- Helper function: Draw LEDs
local function draw_led(cr, x, y, state, thresholds)
    local color_hex, alpha
    local r, g, b

    if state == "CapsLock" then
        color_hex = thresholds[state] and 0xff0000 or 0x00ff00 -- Red for on, green for off
        alpha = 1.0
    elseif state == "NumLock" then
        color_hex = thresholds[state] and 0x00ff00 or 0xff0000 -- Green for on, red for off
        alpha = 1.0
    else
        if state <= thresholds.green then
            color_hex, alpha = 0x00ff00, 1.0 -- Green
        elseif state >= thresholds.red then
            color_hex, alpha = 0xff0000, 1.0 -- Red
        else
            color_hex, alpha = 0xffff00, 1.0 -- Yellow
        end
    end

    -- Pre-calculate RGB components for the chosen color.
    r, g, b = rgb_to_r_g_b_components(color_hex)

    local radius = 8 -- Adjusted radius for smaller LEDs
    local pat = cairo_pattern_create_radial(x, y, 0, x, y, radius)
    cairo_pattern_add_color_stop_rgba(pat, 0, r, g, b, alpha)
    cairo_pattern_add_color_stop_rgba(pat, 1, r, g, b, 0.1)
    cairo_set_source(cr, pat)
    cairo_arc(cr, x, y, radius, 0, 2 * math.pi)
    cairo_fill(cr)
    cairo_pattern_destroy(pat)
end

-- Main function: Draw equalizer bars
local function equalizer(cr, params)
    local str = conky_parse(string.format('${%s %s}', params.name, params.arg))
    local value = tonumber(str) or 0
    local pct = 100 * value / params.max
    local pcb = 100 / params.nb_blocks

    cairo_set_line_width(cr, params.h)
    cairo_set_line_cap(cr, params.cap)

    -- Pre-calculate angle in radians and its sine/cosine once per equalizer call.
    local angle_rad = params.rotation * RAD_TO_DEG
    local cos_angle = math.cos(angle_rad)
    local sin_angle = math.sin(angle_rad)

    for pt = 1, params.nb_blocks do
        local blockStartPercentage = (pt - 1) * pcb
        local col, alpha = params.bgc, params.bga

        if pct >= blockStartPercentage then
            if pct >= params.high_alarm then
                col, alpha = params.alc, params.ala  -- Red for high usage
            elseif pct >= params.alarm then
                col, alpha = params.yelc, params.yela  -- Yellow for medium usage
            else
                col, alpha = params.fgc, params.fga  -- Green for normal usage
            end
        end

        local y1 = params.yb - pt * (params.h + params.space)
        local radius0 = params.yb - y1
        local x2 = params.xb + radius0 * sin_angle -- Use pre-calculated sin_angle
        local y2 = params.yb - radius0 * cos_angle -- Use pre-calculated cos_angle

        -- Pass pre-calculated sin/cos to draw_block
        draw_block(cr, x2, y2, params.w, cos_angle, sin_angle, col, alpha, params.led_effect, params.led_alpha)
    end
end

function conky_draw_pre()
    if conky_window == nil then return end

    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
                 conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    -- Parameters (adjust Y-values to match your layout)
    local ram_start_y = 490  -- Y-position of first RAM process line
    local cpu_start_y = 665  -- Y-position of first CPU process line
    local line_height = 16   -- Height of each line
    local total_width = 256  -- Width of stripes
    local stripe_color = {0.15, 0.50, 1.00, 0.2} -- Dark gray, semi-transparent

    -- Draw RAM stripes (every other line)
    for i = 0, 9 do
        if i % 2 == 1 then
            cairo_set_source_rgba(cr, stripe_color[1], stripe_color[2], stripe_color[3], stripe_color[4])
            cairo_rectangle(cr, 13, ram_start_y + (i * line_height), total_width, line_height)
            cairo_fill(cr)
        end
    end

    -- Draw CPU stripes (every other line)
    for i = 0, 9 do
        if i % 2 == 1 then
            cairo_set_source_rgba(cr, stripe_color[1], stripe_color[2], stripe_color[3], stripe_color[4])
            cairo_rectangle(cr, 13, cpu_start_y + (i * line_height), total_width, line_height)
            cairo_fill(cr)
        end
    end

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

-- Main Conky widget function
function conky_draw_post()
    if conky_window == nil then return end

    -- Create surface and context
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    -- Cache Conky parse results (already a good optimization)
    local temp1 = tonumber(conky_parse('${hwmon 1 temp 1}'))
    local temp2 = tonumber(conky_parse('${hwmon 1 temp 2}'))
    local temp3 = tonumber(conky_parse('${hwmon 2 temp 1}'))
    local temp4 = tonumber(conky_parse('${hwmon 3 temp 1}'))
    local swapperc = tonumber(conky_parse('${swapperc}'))
    -- Corrected logic for CapsLock and NumLock states for consistency.
    -- The original logic for CapsLock was: if "Off" then true, else false. This means "On" makes it false.
    -- The original logic for NumLock was: if "On" then true, else false. This means "On" makes it true.
    -- Assuming 'true' means the LED is "on" (active state) and 'false' means "off".
    local caps_lock_state = conky_parse('${key_caps_lock}') == "On"
    local num_lock_state = conky_parse('${key_num_lock}') == "On"

    -- Equalizer parameters for each bar
    local equalizer_params = {
        {
            xb = 49, yb = 182, name = 'memperc', arg = '', max = 100, nb_blocks = 43, cap = CAIRO_LINE_CAP_SQUARE,
            w = 8, h = 4, space = 1, bgc = 0x404040, bga = 0.7, fgc = 0x00ff00, fga = 1,
            yelc = 0xffff00, yela = 1, alc = 0xff0000, ala = 1,
            alarm = 75, high_alarm = 90, led_effect = true, led_alpha = 0.9, rotation = 90
        },
        {
            xb = 49, yb = 306, name = 'fs_used_perc', arg = '/', max = 100, nb_blocks = 43, cap = CAIRO_LINE_CAP_SQUARE,
            w = 8, h = 4, space = 1, bgc = 0x404040, bga = 0.7, fgc = 0x00ff00, fga = 1,
            yelc = 0xffff00, yela = 1, alc = 0xff0000, ala = 1,
            alarm = 75, high_alarm = 90, led_effect = true, led_alpha = 0.9, rotation = 90
        },
        {
            xb = 49, yb = 370, name = 'fs_used_perc', arg = '/home/bayouguru/N-1Tb/', max = 100, nb_blocks = 43,
            cap = CAIRO_LINE_CAP_SQUARE, w = 8, h = 4, space = 1, bgc = 0x404040, bga = 0.7, fgc = 0x00ff00, fga = 1,
            yelc = 0xffff00, yela = 1, alc = 0xff0000, ala = 1,
            alarm = 75, high_alarm = 90, led_effect = true, led_alpha = 0.9, rotation = 90
        },
        {
            xb = 49, yb = 434, name = 'swapperc', arg = '', max = 100, nb_blocks = 43, cap = CAIRO_LINE_CAP_SQUARE,
            w = 8, h = 4, space = 1, bgc = 0x404040, bga = 0.7, fgc = 0x00ff00, fga = 1,
            yelc = 0xffff00, yela = 1, alc = 0xff0000, ala = 1,
            alarm = 75, high_alarm = 90, led_effect = true, led_alpha = 0.9, rotation = 90
        }
    }

    -- LED thresholds
    local led_thresholds = {
        green = 75,
        red = 90,
        CapsLock = caps_lock_state, -- Now directly reflects 'On' or 'Off' state
        NumLock = num_lock_state   -- Now directly reflects 'On' or 'Off' state
    }

    -- LED positions
    local led_positions = {
        {x = 78, y = 12, state = temp1, thresholds = {green = 140, red = 160}},
        {x = 182, y = 12, state = temp2, thresholds = {green = 120, red = 148}},
        {x = 142, y = 44, state = "CapsLock", thresholds = led_thresholds},
        {x = 253, y = 44, state = "NumLock", thresholds = led_thresholds},
        {x = 26, y = 340, state = temp3, thresholds = {green = 120, red = 140}},
        {x = 26, y = 404, state = temp4, thresholds = {green = 120, red = 140}},
        {x = 26, y = 437, state = swapperc, thresholds = led_thresholds},
    }

    -- Draw each bar
    for _, params in ipairs(equalizer_params) do
        equalizer(cr, params)
    end

    -- Draw LEDs
    for _, led in ipairs(led_positions) do
        draw_led(cr, led.x, led.y, led.state, led.thresholds)
    end

    -- Clean up
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

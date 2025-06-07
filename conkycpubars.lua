require 'cairo'
require 'cairo_xlib'

local color_cache = {}  -- Only initialize once here!

-- Utility: Convert RGB Hex to normalized RGBA
local function rgb_to_r_g_b(colour, alpha)
    local cache_key
    if type(colour) == "number" and type(alpha) == "number" then
        cache_key = colour * 1000 + alpha
    else
        cache_key = tostring(colour) .. "_" .. tostring(alpha)
    end

    if color_cache[cache_key] then
        return table.unpack(color_cache[cache_key])
    end

    if type(colour) ~= "number" then
        local result = {0, 0, 0, alpha or 1}
        color_cache[cache_key] = result
        return 0, 0, 0, alpha or 1
    end

    local r = math.floor(colour / 0x10000) % 256 / 255.
    local g = math.floor(colour / 0x100) % 256 / 255.
    local b = (colour % 0x100) / 255.
    local result = {r, g, b, alpha}
    color_cache[cache_key] = result
    return r, g, b, alpha
end

-- Utility: Color based on usage percentage
local function calculate_color(pct)
    if type(pct) ~= "number" then
        return 0xff0000, 1 -- Default to red if invalid
    end

    if pct < 75 then
        return 0x00ff00, 1 -- Green
    elseif pct <= 90 then
        return 0xffff00, 1 -- Yellow
    else
        return 0xff0000, 1 -- Red
    end
end

-- Draw a gradient "bar block"
local function draw_block(cr, x2, y2, w, angle, col, alpha, led_effect, led_alpha)
    local xx1 = x2 + w * math.cos(angle)
    local yy1 = y2 + w * math.sin(angle)

    local pat = cairo_pattern_create_linear(x2, y2, x2, yy1)
    cairo_pattern_add_color_stop_rgba(pat, 0, rgb_to_r_g_b(col, alpha * 0.4))
    cairo_pattern_add_color_stop_rgba(pat, 0.5, rgb_to_r_g_b(col, alpha))
    cairo_pattern_add_color_stop_rgba(pat, 1, rgb_to_r_g_b(col, alpha * 0.4))
    cairo_set_source(cr, pat)
    cairo_move_to(cr, x2, y2)
    cairo_line_to(cr, xx1, yy1)
    cairo_stroke(cr)
    cairo_pattern_destroy(pat)

    if led_effect then
        local xc = (x2 + xx1) * 0.5
        local yc = (y2 + yy1) * 0.5
        local led_pat = cairo_pattern_create_radial(xc, yc, 0, xc, yc, w * 0.5)
        cairo_pattern_add_color_stop_rgba(led_pat, 0, rgb_to_r_g_b(col, led_alpha))
        cairo_pattern_add_color_stop_rgba(led_pat, 1, rgb_to_r_g_b(col, alpha))
        cairo_set_source(cr, led_pat)
        cairo_stroke(cr)
        cairo_pattern_destroy(led_pat)
    end
end

-- Draw equalizer bar with optional percentage
local function equalizer(cr, xb, yb, name, arg, max, nb_blocks, cap, w, h, space,
                         bgc, bga, fgc, fga, alc, ala, alarm, led_effect, led_alpha,
                         rotation_degrees, show_percentage, precalculated_angle)

    local value_str = conky_parse('${' .. name .. ' ' .. arg .. '}')
    local value = tonumber(value_str) or 0

    local pct = math.min(100, math.max(0, 100 * value / max))
    local pcb = 100 / nb_blocks
    local angle = precalculated_angle

    if show_percentage then
        cairo_new_path(cr)
        cairo_select_font_face(cr, "Larabiefont", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
        cairo_set_font_size(cr, 13)
        cairo_set_source_rgba(cr, rgb_to_r_g_b(0xFF8C00, 1))
        local pct_text = string.format('%d', math.floor(pct + 0.5))
        local num_x_pos = xb + ( (pct < 10 and 26) or (pct < 100 and 18) or 10 )
        cairo_move_to(cr, num_x_pos, yb + 9)
        cairo_show_text(cr, pct_text)
        cairo_set_source_rgba(cr, rgb_to_r_g_b(0xADD8E6, 1))
        cairo_move_to(cr, xb + 36, yb + 9)
        cairo_show_text(cr, "%")
        xb = xb + 44
    end

    cairo_set_line_width(cr, h)
    cairo_set_line_cap(cr, cap)

    local y_step = h + space
    for pt = 1, nb_blocks do
        local block_center_offset = (pt - 0.5) * y_step
        local radius_calc = pt * y_step
        local y1_equivalent_for_radius = yb - radius_calc
        local actual_radius_from_base = yb - y1_equivalent_for_radius
        local x2 = xb + actual_radius_from_base * math.sin(angle)
        local y2 = yb - actual_radius_from_base * math.cos(angle)

        local block_pct_threshold = (pt - 1) * pcb
        local col, current_alpha
        if pct >= block_pct_threshold then
            if alarm > 0 and pct >= alarm then
                col, current_alpha = calculate_color(pct)
            else
                col, current_alpha = fgc, fga
            end
        else
            col, current_alpha = bgc, bga
        end
        draw_block(cr, x2, y2, w, angle, col, current_alpha, led_effect, led_alpha)
    end
end

-- Draw status LEDs with proper color handling
local function draw_led(cr, x, y, state, thresholds)
    local color_hex, base_alpha = 0x000000, 1

    if type(state) ~= "number" then state = thresholds.red + 1 end

    if state <= thresholds.green then
        color_hex = 0x00ff00
    elseif state >= thresholds.red then
        color_hex = 0xff0000
    else
        color_hex = 0xffff00
    end

    local r_led, g_led, b_led = rgb_to_r_g_b(color_hex, 1)
    local radius = 8
    local pat = cairo_pattern_create_radial(x, y, 0, x, y, radius)
    cairo_pattern_add_color_stop_rgba(pat, 0, r_led, g_led, b_led, base_alpha)
    cairo_pattern_add_color_stop_rgba(pat, 0.7, r_led, g_led, b_led, base_alpha*0.5)
    cairo_pattern_add_color_stop_rgba(pat, 1, r_led, g_led, b_led, 0.0)
    cairo_set_source(cr, pat)
    cairo_arc(cr, x, y, radius, 0, 2 * math.pi)
    cairo_fill(cr)
    cairo_pattern_destroy(pat)
end

-- Background shading (runs before text drawing)
function conky_conkycpubars_draw_pre()
    if conky_window == nil then return end
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
                                         conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    cairo_set_source_rgba(cr, 0.15, 0.50, 1.00, 0.2)
    cairo_rectangle(cr, 3, 52, 262, 28)
    cairo_rectangle(cr, 3, 108, 262, 28)
    cairo_fill(cr)

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

-- Main function
function conky_conkycpubars_widgets()
    if conky_window == nil then return end

    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
                                         conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    local bgc, bga = 0x404040, 0.8
    local fgc, fga = 0x00ff00, 1
    local alarm_threshold = 75

    local bar_rotation_degrees = 90
    local precalculated_bar_angle = bar_rotation_degrees * math.pi / 180

    local bars = {
        -- x, y, conky_arg_cpu_num, num_blocks
        {4, 26, 'cpu1', 25}, {136, 26, 'cpu2', 25},
        {4, 54, 'cpu3', 25}, {136, 54, 'cpu4', 25},
        {4, 82, 'cpu5', 25}, {136, 82, 'cpu6', 25},
        {4, 110, 'cpu0', 51} -- CPU Average, more blocks
    }

    for _, bar_config in ipairs(bars) do
        equalizer(cr, bar_config[1], bar_config[2], 'cpu', bar_config[3], 100, bar_config[4],
                  CAIRO_LINE_CAP_SQUARE, 8, 4, 1, -- w=8, h=4
                  bgc, bga, fgc, fga, 0, 0,
                  alarm_threshold, true, 0.8,
                  bar_rotation_degrees, false, precalculated_bar_angle)
    end

    -- GPU Bar
    equalizer(cr, 9, 159, 'exec', 'cat /sys/class/drm/card1/device/gpu_busy_percent',
              100, 42, CAIRO_LINE_CAP_SQUARE, 8, 4, 1,
              bgc, bga, fgc, fga, 0, 0, alarm_threshold, true, 0.8,
              bar_rotation_degrees, true, precalculated_bar_angle)

    local temp_pch_str = conky_parse('${hwmon 4 temp 1}')
    local temp_pch = tonumber(temp_pch_str)
    draw_led(cr, 210, 15, temp_pch, {green = 140, red = 155})

    local temp_cpu_pkg_str = conky_parse('${hwmon 0 temp 1}')
    local temp_cpu_pkg = tonumber(temp_cpu_pkg_str)
    draw_led(cr, 210, 147, temp_cpu_pkg, {green = 170, red = 190})

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

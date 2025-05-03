require 'cairo'
require 'cairo_xlib'

-- Utility: Convert RGB Hex to normalized RGBA
local function rgb_to_r_g_b(colour, alpha)
    -- Ensure colour is a valid number
    if type(colour) ~= "number" then
        return 0, 0, 0, alpha  -- Return black if invalid
    end

    local r = math.floor(colour / 0x10000) % 256 / 255.
    local g = math.floor(colour / 0x100) % 256 / 255.
    local b = (colour % 0x100) / 255.
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

    -- Draw main block
    local pat = cairo_pattern_create_linear(x2, y2, x2, yy1)
    cairo_pattern_add_color_stop_rgba(pat, 0, rgb_to_r_g_b(col, alpha * 0.4))
    cairo_pattern_add_color_stop_rgba(pat, 0.5, rgb_to_r_g_b(col, alpha))
    cairo_pattern_add_color_stop_rgba(pat, 1, rgb_to_r_g_b(col, alpha * 0.4))
    cairo_set_source(cr, pat)
    cairo_move_to(cr, x2, y2)
    cairo_line_to(cr, xx1, yy1)
    cairo_stroke(cr)
    cairo_pattern_destroy(pat)

    -- Draw LED effect if enabled
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
                         rotation, show_percentage)

    local value = tonumber(conky_parse('${' .. name .. ' ' .. arg .. '}')) or 0
    local pct = math.min(100, 100 * value / max)
    local pcb = 100 / nb_blocks
    local angle = rotation * math.pi / 180

    -- Display percentage if requested
    if show_percentage then
        cairo_new_path(cr)
        cairo_select_font_face(cr, "Larabiefont", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
        cairo_set_font_size(cr, 13)
        cairo_set_source_rgba(cr, 1, 0.647, 0, 1)

        local num_x_pos = xb + (pct < 10 and 26 or (pct < 100 and 18 or 10))
        cairo_move_to(cr, num_x_pos, yb + 9)
        cairo_show_text(cr, string.format('%d', pct))

        cairo_set_source_rgba(cr, 0.678, 0.847, 0.902, 1)
        cairo_move_to(cr, xb + 36, yb + 9)
        cairo_show_text(cr, "%")

        xb = xb + 44
    end

    -- Set up line width and cap
    cairo_set_line_width(cr, h)
    cairo_set_line_cap(cr, cap)

    -- Draw the blocks
    local y_step = h + space
    for pt = 1, nb_blocks do
        local y1 = yb - pt * y_step
        local radius = yb - y1
        local x2 = xb + radius * math.sin(angle)
        local y2 = yb - radius * math.cos(angle)

        local block_pct = (pt - 1) * pcb
        local col, alpha = bgc, bga
        if pct >= block_pct then
            col, alpha = (pct < alarm) and fgc, fga or calculate_color(pct)
        end

        draw_block(cr, x2, y2, w, angle, col, alpha, led_effect, led_alpha)
    end
end

-- Draw status LEDs with proper color handling
local function draw_led(cr, x, y, state, thresholds)
    local color, alpha

    -- Check state and assign the appropriate color
    if state <= thresholds.green then
        color, alpha = 0x00ff00, 1 -- Green
    elseif state >= thresholds.red then
        color, alpha = 0xff0000, 1 -- Red
    else
        color, alpha = 0xffff00, 1 -- Yellow
    end

    -- Draw the LED
    local radius = 8
    local pat = cairo_pattern_create_radial(x, y, 0, x, y, radius)
    cairo_pattern_add_color_stop_rgba(pat, 0, rgb_to_r_g_b(color, alpha))
    cairo_pattern_add_color_stop_rgba(pat, 1, rgb_to_r_g_b(color, 0.1))
    cairo_set_source(cr, pat)
    cairo_arc(cr, x, y, radius, 0, 2 * math.pi)
    cairo_fill(cr)
    cairo_pattern_destroy(pat)
end

-- Main function
function conky_conkycpubars_widgets()
    if conky_window == nil then return end

    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
                                         conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    local bgc, bga = 0x404040, 0.8
    local fgc, fga = 0x00ff00, 1
    local alc, ala = 0xff0000, 1
    local alarm = 75

    -- CPU Bars
    local bars = {
        {4, 26, 'cpu1'}, {136, 26, 'cpu2'},
        {4, 54, 'cpu3'}, {136, 54, 'cpu4'},
        {4, 82, 'cpu5'}, {136, 82, 'cpu6'},
        {4, 110, 'cpu0', 86}
    }
    for _, bar in ipairs(bars) do
        equalizer(cr, bar[1], bar[2], 'cpu', bar[3], 100, bar[4] or 42, CAIRO_LINE_CAP_SQUARE, 8, 2, 1,
                  bgc, bga, fgc, fga, alc, ala, alarm, true, 0.8, 90, false)
    end

    -- GPU Bar
    equalizer(cr, 9, 159, 'exec', 'cat /sys/class/drm/card1/device/gpu_busy_percent',
              100, 70, CAIRO_LINE_CAP_SQUARE, 8, 2, 1,
              bgc, bga, fgc, fga, alc, ala, alarm, true, 0.8, 90, true)

    -- LEDs
    draw_led(cr, 210, 15, tonumber(conky_parse('${hwmon 4 temp 1}')), {green = 140, red = 155})
    draw_led(cr, 210, 147, tonumber(conky_parse('${hwmon 0 temp 1}')), {green = 170, red = 190})

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

-- conkycpubars.lua
require 'cairo'
require 'cairo_xlib'

function rgb_to_r_g_b(colour, alpha)
    return ((colour / 0x10000) % 0x100) / 255., ((colour / 0x100) % 0x100) / 255., (colour % 0x100) / 255., alpha
end

function calculate_color(pct)
    local col, alpha
    if pct < 75 then
        col, alpha = 0x00ff00, 1
    elseif pct <= 90 then
        local factor = (pct - 75) / 15
        col = 0xffff00 * (1 - factor) + 0xff0000 * factor
        alpha = 1
    else
        col, alpha = 0xff0000, 1
    end
    return col, alpha
end

function equalizer(cr, xb, yb, name, arg, max, nb_blocks, cap, w, h, space, bgc, bga, fgc, fga, alc, ala, alarm, led_effect, led_alpha, rotation, show_percentage)
    local str = conky_parse(string.format('${%s %s}', name, arg))
    local value = tonumber(str) or 0
    local pct = 100 * value / max
    local pcb = 100 / nb_blocks

    -- Render the percentage with adjusted spacing
    if show_percentage then
        cairo_new_path(cr)

        cairo_select_font_face(cr, "Larabiefont", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
        cairo_set_font_size(cr, 13)

        cairo_set_source_rgba(cr, 1, 0.647, 0, 1)

        local num_x_pos = xb + 10  -- Shifted right for alignment
        if pct < 10 then
            num_x_pos = xb + 26
        elseif pct < 100 then
            num_x_pos = xb + 18
        end
        cairo_move_to(cr, num_x_pos, yb + 9)
        cairo_show_text(cr, string.format('%d', pct))

        cairo_set_source_rgba(cr, 0.678, 0.847, 0.902, 1)

        cairo_move_to(cr, xb + 36, yb + 9) -- Shifted percentage symbol to align
        cairo_show_text(cr, "%")

        xb = xb + 44  -- Adjust bar start position to match shortened numeric section
    end

    cairo_set_line_width(cr, h)
    cairo_set_line_cap(cr, cap)

    local angle = rotation * math.pi / 180
    for pt = 1, nb_blocks do
        local blockStartPercentage = (pt - 1) * pcb
        local col, alpha = bgc, bga

        if pct >= blockStartPercentage then
            if pct < alarm then
                col, alpha = fgc, fga
            else
                col, alpha = calculate_color(pct)
            end
        end

        local y1 = yb - pt * (h + space)
        local radius0 = yb - y1
        local x2 = xb + radius0 * math.sin(angle)
        local y2 = yb - radius0 * math.cos(angle)

        cairo_move_to(cr, x2, yb)
        cairo_line_to(cr, x2 + w * math.cos(angle), y2 + w * math.sin(angle))

        if led_effect and pct >= blockStartPercentage then
            local xc, yc = (x2 + x2 + w * math.cos(angle)) / 2, (yb + y2 + w * math.sin(angle)) / 2
            local pat = cairo_pattern_create_radial(xc, yc, 0, xc, yc, w / 2)
            cairo_pattern_add_color_stop_rgba(pat, 0, rgb_to_r_g_b(col, led_alpha))
            cairo_pattern_add_color_stop_rgba(pat, 1, rgb_to_r_g_b(col, alpha))
            cairo_set_source(cr, pat)
            cairo_pattern_destroy(pat)
        else
            cairo_set_source_rgba(cr, rgb_to_r_g_b(col, alpha))
        end

        cairo_stroke(cr)
    end
end

function conky_conkycpubars_widgets()
    if conky_window == nil then return end
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    local bgc = 0x404040
    local bga = 0.7
    local fgc = 0x00ff00
    local fga = 1
    local alc = 0xff0000
    local ala = 1
    local alarm = 75

    local bars = {
        {4, 26, 'cpu1'}, {136, 26, 'cpu2'},
        {4, 54, 'cpu3'}, {136, 54, 'cpu4'},
        {4, 82, 'cpu5'}, {136, 82, 'cpu6'},
        {4, 110, 'cpu0', 86}
    }

    -- Adjusted GPU usage display for alignment
    equalizer(cr, 9, 159, 'exec', 'cat /sys/class/drm/card1/device/gpu_busy_percent', 100, 70, CAIRO_LINE_CAP_SQUARE, 8, 2, 1,
              bgc, bga, fgc, fga, alc, ala, alarm, true, 0.8, 90, true)

    for i, bar in ipairs(bars) do
        local x, y, cpu_label, width = bar[1], bar[2], bar[3], bar[4] or 42
        equalizer(cr, x, y, 'cpu', cpu_label, 100, width, CAIRO_LINE_CAP_SQUARE, 8, 2, 1,
                  bgc, bga, fgc, fga, alc, ala, alarm, true, 0.8, 90, false)
    end

    -- Helper function: Draw LEDs
    local function draw_led(cr, x, y, state, thresholds)
        local color, alpha

        if state <= thresholds.green then
            color, alpha = 0x00ff00, 1.0 -- Green
        elseif state >= thresholds.red then
            color, alpha = 0xff0000, 1.0 -- Red
        else
            color, alpha = 0xffff00, 1.0 -- Yellow
        end

        local radius = 8 -- Adjusted radius for smaller LEDs
        local pat = cairo_pattern_create_radial(x, y, 0, x, y, radius)
        cairo_pattern_add_color_stop_rgba(pat, 0, rgb_to_r_g_b(color, alpha))
        cairo_pattern_add_color_stop_rgba(pat, 1, rgb_to_r_g_b(color, 0.1))
        cairo_set_source(cr, pat)
        cairo_arc(cr, x, y, radius, 0, 2 * math.pi)
        cairo_fill(cr)
        cairo_pattern_destroy(pat)
    end

    -- LED positions and thresholds
    local led_positions = {
        {x = 210, y = 15, state = tonumber(conky_parse('${hwmon 4 temp 1}')), thresholds = {green = 140, red = 155}},
        {x = 210, y = 147, state = tonumber(conky_parse('${hwmon 0 temp 1}')), thresholds = {green = 170, red = 190}}
    }

    -- Draw LEDs
    for _, led in ipairs(led_positions) do
        draw_led(cr, led.x, led.y, led.state, led.thresholds)
    end

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end
-- conkycpubars.lua
require 'cairo'
require 'cairo_xlib'

function rgb_to_r_g_b(colour, alpha)
    return ((colour / 0x10000) % 0x100) / 255., ((colour / 0x100) % 0x100) / 255., (colour % 0x100) / 255., alpha
end

function equalizer(cr, xb, yb, name, arg, max, nb_blocks, cap, w, h, space, bgc, bga, fgc, fga, alc, ala, alarm, led_effect, led_alpha, rotation)
    local str = conky_parse(string.format('${%s %s}', name, arg))
    local value = tonumber(str) or 0
    local pct = 100 * value / max
    local pcb = 100 / nb_blocks

    cairo_set_line_width(cr, h)
    cairo_set_line_cap(cr, cap)

    local angle = rotation * math.pi / 180
    for pt = 1, nb_blocks do
        local blockStartPercentage = (pt - 1) * pcb
        local col, alpha = bgc, bga

        if pct >= blockStartPercentage then
            col, alpha = fgc, fga
            if pct >= alarm then
                col, alpha = alc, ala
            end
        end

        local y1 = yb - pt * (h + space)
        local radius0 = yb - y1
        local x2 = xb + radius0 * math.sin(angle)
        local y2 = yb - radius0 * math.cos(angle)

        cairo_move_to(cr, x2, yb)
        cairo_line_to(cr, x2 + w * math.cos(angle), y2 + w * math.sin(angle))

        if led_effect then
            local xc, yc = (x2 + x2 + w * math.cos(angle)) / 2, (yb + y2 + w * math.sin(angle)) / 2
            local pat = cairo_pattern_create_radial(xc, yc, 0, xc, yc, w / 1.5)
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

    -- Bar configuration: x, y, CPU label
    local bars = {
        {4, 27, 'cpu1'}, {136, 27, 'cpu2'},
        {4, 65, 'cpu3'}, {136, 65, 'cpu4'},
        {4, 105, 'cpu5'}, {136, 105, 'cpu6'},
        {4, 143, 'cpu0', 86}  -- The last bar spans full width
    }

    for i, bar in ipairs(bars) do
        local x, y, cpu_label, width = bar[1], bar[2], bar[3], bar[4] or 42
        equalizer(cr, x, y, 'cpu', cpu_label, 100, width, CAIRO_LINE_CAP_SQUARE, 10, 2, 1,
                  0x606070, 1, 0x00ff0c, 1, 0xff0000, 1, 75, true, 1, 90)
    end

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

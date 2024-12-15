-- updownbars.lua
require 'cairo'
require 'cairo_xlib'

-- Optimized RGB to RGBA conversion (cached)
local function rgb_to_r_g_b(colour, alpha)
    return ((colour / 0x10000) % 0x100) / 255., ((colour / 0x100) % 0x100) / 255., (colour % 0x100) / 255., alpha
end

-- Optimized equalizer function
function updownbars_equalizer(cr, xb, yb, name, arg, max, nb_blocks, cap, w, h, space, bgc, bga, fgc, fga, alc, ala, alarm, led_effect, led_alpha, smooth, mid_color, mid_alpha, rotation)
    -- Parse the value just once instead of repeatedly
    local str = conky_parse(string.format('${%s %s}', name, arg))
    local value = tonumber(str) or 0
    local pct = 100 * value / max
    local pcb = 100 / nb_blocks

    cairo_set_line_width(cr, h)
    cairo_set_line_cap(cr, cap)

    local angle = rotation * math.pi / 180
    local alpha_bg, alpha_fg, alpha_alarm
    -- Precompute the color values
    local bg_r, bg_g, bg_b = rgb_to_r_g_b(bgc, bga)
    local fg_r, fg_g, fg_b = rgb_to_r_g_b(fgc, fga)
    local alc_r, alc_g, alc_b = rgb_to_r_g_b(alc, ala)

    for pt = 1, nb_blocks do
        local blockStartPercentage = (pt - 1) * pcb
        -- Conditional for changing colors
        local col_r, col_g, col_b, alpha = bg_r, bg_g, bg_b, bga
        if pct >= blockStartPercentage then
            col_r, col_g, col_b, alpha = fg_r, fg_g, fg_b, fga
            if pct >= alarm then
                col_r, col_g, col_b, alpha = alc_r, alc_g, alc_b, ala
            end
        end

        local y1 = yb - pt * (h + space)
        local radius0 = yb - y1
        local x2 = xb + radius0 * math.sin(angle)
        local y2 = yb - radius0 * math.cos(angle)

        local xx0, xx1, yy0, yy1
        if rotation == 90 or rotation == 270 then
            xx0, xx1 = x2, x2
            yy0, yy1 = yb, yb + w
        else
            xx0, xx1 = x2, x2 + w * math.cos(angle)
            yy0, yy1 = y2 - (y2 - yb) / ((y2 - yb) / (x2 - xb)), y2 + w * math.sin(angle)
        end

        cairo_move_to(cr, xx0, yy0)
        cairo_line_to(cr, xx1, yy1)

        -- If LED effect is enabled, apply radial pattern
        if led_effect then
            local xc, yc = (xx0 + xx1) / 2, (yy0 + yy1) / 2
            local pat = cairo_pattern_create_radial(xc, yc, 0, xc, yc, w / 1.5)
            cairo_pattern_add_color_stop_rgba(pat, 0, col_r, col_g, col_b, led_alpha)
            cairo_pattern_add_color_stop_rgba(pat, 1, col_r, col_g, col_b, alpha)
            cairo_set_source(cr, pat)
            cairo_pattern_destroy(pat)
        else
            cairo_set_source_rgba(cr, col_r, col_g, col_b, alpha)
        end

        cairo_stroke(cr)
    end
end

-- Optimized Conky widget rendering function
function conky_updownbars_widgets()
    if conky_window == nil then return end
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)

    local cr = cairo_create(cs)

    -- Upload equalizer
    updownbars_equalizer(cr, 74, 331, 'upspeedf', 'enp4s0', 20000, 75, CAIRO_LINE_CAP_SQUARE, 10, 2, 1, 0x606070, 1, 0x00ff0c, 1, 0xff0000, 1, 80, true, 1, true, 0xffff00, 1, 90)

    -- Download equalizer
    updownbars_equalizer(cr, 74, 348, 'downspeedf', 'enp4s0', 50000, 75, CAIRO_LINE_CAP_SQUARE, 10, 2, 1, 0x606070, 1, 0x00ff0c, 1, 0xff0000, 1, 80, true, 1, true, 0xffff00, 1, 90)

    cairo_destroy(cr)
end

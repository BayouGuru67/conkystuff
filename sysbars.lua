-- sysbars.lua
require 'cairo'
require 'cairo_xlib'

-- Helper function: Convert hex color to RGBA
local function rgb_to_r_g_b(colour, alpha)
    return ((colour / 0x10000) % 0x100) / 255., ((colour / 0x100) % 0x100) / 255., (colour % 0x100) / 255., alpha
end

-- Helper function: Draw a single block
local function draw_block(cr, x2, y2, w, angle, col, alpha, led_effect, led_alpha)
    local xx0, xx1, yy0, yy1
    if angle == 90 or angle == 270 then
        xx0, xx1 = x2, x2
        yy0, yy1 = y2, y2 + w
    else
        xx0, xx1 = x2, x2 + w * math.cos(angle)
        yy0, yy1 = y2, y2 + w * math.sin(angle)
    end

    cairo_move_to(cr, xx0, yy0)
    cairo_line_to(cr, xx1, yy1)

    if led_effect then
        local xc, yc = (xx0 + xx1) / 2, (yy0 + yy1) / 2
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

-- Main function: Draw equalizer bars
local function equalizer(cr, params)
    local str = conky_parse(string.format('${%s %s}', params.name, params.arg))
    local value = tonumber(str) or 0
    local pct = 100 * value / params.max
    local pcb = 100 / params.nb_blocks

    cairo_set_line_width(cr, params.h)
    cairo_set_line_cap(cr, params.cap)

    local angle = params.rotation * math.pi / 180
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
        local x2 = params.xb + radius0 * math.sin(angle)
        local y2 = params.yb - radius0 * math.cos(angle)

        draw_block(cr, x2, y2, params.w, angle, col, alpha, params.led_effect, params.led_alpha)
    end
end

-- Main Conky widget function
function conky_sysbars_widgets()
    if conky_window == nil then return end

    -- Create surface and context
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    -- Equalizer parameters for each bar
    local equalizer_params = {
        {
            xb = 55, yb = 298, name = 'memperc', arg = '', max = 100, nb_blocks = 69, cap = CAIRO_LINE_CAP_SQUARE,
            w = 8, h = 2, space = 1, bgc = 0x404040, bga = 0.7, fgc = 0x00ff00, fga = 1,
            yelc = 0xffff00, yela = 1, alc = 0xff0000, ala = 1,
            alarm = 75, high_alarm = 90, led_effect = true, led_alpha = 0.9, rotation = 90
        },
        {
            xb = 55, yb = 466, name = 'fs_used_perc', arg = '/', max = 100, nb_blocks = 69, cap = CAIRO_LINE_CAP_SQUARE,
            w = 8, h = 2, space = 1, bgc = 0x404040, bga = 0.7, fgc = 0x00ff00, fga = 1,
            yelc = 0xffff00, yela = 1, alc = 0xff0000, ala = 1,
            alarm = 75, high_alarm = 90, led_effect = true, led_alpha = 0.9, rotation = 90
        },
        {
            xb = 55, yb = 526, name = 'fs_used_perc', arg = '/home/bayouguru/N-1Tb/', max = 100, nb_blocks = 69,
            cap = CAIRO_LINE_CAP_SQUARE, w = 8, h = 2, space = 1, bgc = 0x404040, bga = 0.7, fgc = 0x00ff00, fga = 1,
            yelc = 0xffff00, yela = 1, alc = 0xff0000, ala = 1,
            alarm = 75, high_alarm = 90, led_effect = true, led_alpha = 0.9, rotation = 90
        },
        {
            xb = 55, yb = 570, name = 'swapperc', arg = '', max = 100, nb_blocks = 69, cap = CAIRO_LINE_CAP_SQUARE,
            w = 8, h = 2, space = 1, bgc = 0x404040, bga = 0.7, fgc = 0x00ff00, fga = 1,
            yelc = 0xffff00, yela = 1, alc = 0xff0000, ala = 1,
            alarm = 75, high_alarm = 90, led_effect = true, led_alpha = 0.9, rotation = 90
        }
    }

    -- Draw each bar
    for _, params in ipairs(equalizer_params) do
        equalizer(cr, params)
    end

    -- Clean up
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

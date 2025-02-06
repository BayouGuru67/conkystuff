-- log_updownbars.lua
require 'cairo'
require 'cairo_xlib'

-- Helper function: Convert hex color to RGBA
local function rgb_to_r_g_b(colour, alpha)
    return ((colour / 0x10000) % 0x100) / 255., ((colour / 0x100) % 0x100) / 255., (colour % 0x100) / 255., alpha
end

-- Helper function: Draw a single block with LED and 3D effect
local function draw_block(cr, x2, y2, w, angle, col, alpha, led_effect, led_alpha)
    local xx0, xx1, yy0, yy1
    if angle == 90 or angle == 270 then
        xx0, xx1 = x2, x2
        yy0, yy1 = y2, y2 + w
    else
        xx0, xx1 = x2, x2 + w * math.cos(angle)
        yy0, yy1 = y2, y2 + w * math.sin(angle)
    end

    -- 3D Gradient Effect
    local pat = cairo_pattern_create_linear(xx0, yy0, xx0, yy1)
    cairo_pattern_add_color_stop_rgba(pat, 0, rgb_to_r_g_b(col, alpha * 0.4))  -- Darker top
    cairo_pattern_add_color_stop_rgba(pat, 0.5, rgb_to_r_g_b(col, alpha))      -- Normal middle
    cairo_pattern_add_color_stop_rgba(pat, 1, rgb_to_r_g_b(col, alpha * 0.4))  -- Darker bottom
    cairo_set_source(cr, pat)

    cairo_move_to(cr, xx0, yy0)
    cairo_line_to(cr, xx1, yy1)
    cairo_stroke(cr)
    cairo_pattern_destroy(pat)

    -- Optional LED Effect Overlay
    if led_effect then
        local xc, yc = (xx0 + xx1) / 2, (yy0 + yy1) / 2
        local led_pat = cairo_pattern_create_radial(xc, yc, 0, xc, yc, w / 2)
        cairo_pattern_add_color_stop_rgba(led_pat, 0, rgb_to_r_g_b(col, led_alpha))
        cairo_pattern_add_color_stop_rgba(led_pat, 1, rgb_to_r_g_b(col, alpha))
        cairo_set_source(cr, led_pat)
        cairo_stroke(cr)
        cairo_pattern_destroy(led_pat)
    end
end

-- Main function: Draw equalizer bars
local function updownbars_equalizer(cr, params)
    local str = conky_parse(string.format('${%s %s}', params.name, params.arg))
    local value = tonumber(str) or 0

    -- Apply logarithmic scaling
    local log_value = value > 0 and math.log(value + 1) or 0
    local log_max = math.log(params.max + 1)
    local pct = 100 * log_value / log_max

    local pcb = 100 / params.nb_blocks

    cairo_set_line_width(cr, params.h)
    cairo_set_line_cap(cr, params.cap)

    local angle = params.rotation * math.pi / 180
    for pt = 1, params.nb_blocks do
        local blockStartPercentage = (pt - 1) * pcb
        local col, alpha = params.bgc, params.bga

        if pct >= blockStartPercentage then
            col, alpha = params.fgc, params.fga
            if pct >= params.warning and pct < params.alarm then
                col, alpha = params.wc, params.wa  -- Yellow for warning
            elseif pct >= params.alarm then
                col, alpha = params.alc, params.ala  -- Red for alarm
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
function conky_updownbars_widgets()
    if conky_window == nil then return end

    -- Create surface and context
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    -- Parameters for upload and download bars
    local bars = {
        {
            xb = 65, yb = 220, name = 'upspeedf', arg = 'enp4s0', max = 20000, nb_blocks = 79,
            cap = CAIRO_LINE_CAP_SQUARE, w = 9, h = 2, space = 1,
            bgc = 0x404040, bga = 0.7,
            fgc = 0x00ff00, fga = 1,  -- Bright green
            wc = 0xffff00, wa = 1,   -- Bright yellow
            alc = 0xff0000, ala = 1, -- Bright red
            warning = 75, alarm = 90,
            led_effect = true, led_alpha = 0.8, rotation = 90
        },
        {
            xb = 65, yb = 236, name = 'downspeedf', arg = 'enp4s0', max = 100000, nb_blocks = 79,
            cap = CAIRO_LINE_CAP_SQUARE, w = 9, h = 2, space = 1,
            bgc = 0x404040, bga = 0.7,
            fgc = 0x00ff00, fga = 1,  -- Bright green
            wc = 0xffff00, wa = 1,   -- Bright yellow
            alc = 0xff0000, ala = 1, -- Bright red
            warning = 75, alarm = 90,
            led_effect = true, led_alpha = 0.8, rotation = 90
        }
    }

    -- Draw each bar
    for _, params in ipairs(bars) do
        updownbars_equalizer(cr, params)
    end

    -- Clean up
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

require 'cairo'
require 'cairo_xlib'

-- Helper functions remain unchanged
local function rgb_to_r_g_b(colour, alpha)
    return ((colour / 0x10000) % 0x100) / 255., ((colour / 0x100) % 0x100) / 255., (colour % 0x100) / 255., alpha
end

local function draw_block(cr, x2, y2, w, angle, col, alpha, led_effect, led_alpha)
    -- Original draw_block implementation
    local xx0, xx1, yy0, yy1
    if angle == 90 or angle == 270 then
        xx0, xx1 = x2, x2
        yy0, yy1 = y2, y2 + w
    else
        xx0, xx1 = x2, x2 + w * math.cos(angle)
        yy0, yy1 = y2, y2 + w * math.sin(angle)
    end

    local pat = cairo_pattern_create_linear(xx0, yy0, xx0, yy1)
    cairo_pattern_add_color_stop_rgba(pat, 0, rgb_to_r_g_b(col, alpha * 0.4))
    cairo_pattern_add_color_stop_rgba(pat, 0.5, rgb_to_r_g_b(col, alpha))
    cairo_pattern_add_color_stop_rgba(pat, 1, rgb_to_r_g_b(col, alpha * 0.4))
    cairo_set_source(cr, pat)

    cairo_move_to(cr, xx0, yy0)
    cairo_line_to(cr, xx1, yy1)
    cairo_stroke(cr)
    cairo_pattern_destroy(pat)

    if led_effect then
        local xc, yc = (xx0 + xx1)/2, (yy0 + yy1)/2
        local led_pat = cairo_pattern_create_radial(xc, yc, 0, xc, yc, w/2)
        cairo_pattern_add_color_stop_rgba(led_pat, 0, rgb_to_r_g_b(col, led_alpha))
        cairo_pattern_add_color_stop_rgba(led_pat, 1, rgb_to_r_g_b(col, alpha))
        cairo_set_source(cr, led_pat)
        cairo_stroke(cr)
        cairo_pattern_destroy(led_pat)
    end
end

local function is_network_connected(interface)
    local ip = conky_parse('${addr ' .. interface .. '}')
    return ip and ip ~= '' and ip ~= '0.0.0.0'
end

-- Pre-hook: Background shading
function conky_draw_pre()
    if conky_window == nil then return end
    if not is_network_connected('enp4s0') then return end

    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
               conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    -- Background stripe parameters
    local start_x = 13
    local start_y = 268
    local pair_height = 30
    local total_width = 294

    local in_count = tonumber(conky_parse("${tcp_portmon 1 32767 count}")) or 0
    local out_count = tonumber(conky_parse("${tcp_portmon 32768 61000 count}")) or 0
    local total_pairs = math.max(in_count, out_count)

    cairo_set_source_rgba(cr, 0.15, 0.15, 0.15, 0.7)

    for i = 0, total_pairs - 1 do
        if i % 2 == 1 then
            local y_pos = start_y + (i * pair_height)
            cairo_rectangle(cr, start_x, y_pos, total_width, pair_height)
            cairo_fill(cr)
        end
    end

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

-- Post-hook: Speed bars
function conky_draw_post()
    if conky_window == nil then return end
    if not is_network_connected('enp4s0') then return end

    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
               conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    -- Speed bars configuration
    local bars = {
        {
            xb = 60, yb = 222, name = 'upspeedf', arg = 'enp4s0', max = 20000, nb_blocks = 80,
            cap = CAIRO_LINE_CAP_SQUARE, w = 9, h = 2, space = 1,
            bgc = 0x404040, bga = 0.7,
            fgc = 0x00ff00, fga = 1, wc = 0xffff00, wa = 1,
            alc = 0xff0000, ala = 1, warning = 75, alarm = 90,
            led_effect = true, led_alpha = 0.8, rotation = 90
        },
        {
            xb = 60, yb = 240, name = 'downspeedf', arg = 'enp4s0', max = 100000, nb_blocks = 80,
            cap = CAIRO_LINE_CAP_SQUARE, w = 9, h = 2, space = 1,
            bgc = 0x404040, bga = 0.7,
            fgc = 0x00ff00, fga = 1, wc = 0xffff00, wa = 1,
            alc = 0xff0000, ala = 1, warning = 75, alarm = 90,
            led_effect = true, led_alpha = 0.8, rotation = 90
        }
    }

    -- Draw each speed bar
    for _, params in ipairs(bars) do
        local value = tonumber(conky_parse(string.format('${%s %s}', params.name, params.arg))) or 0
        local log_value = value > 0 and math.log(value + 1) or 0
        local log_max = math.log(params.max + 1)
        local pct = 100 * log_value / log_max
        local pcb = 100 / params.nb_blocks
        local angle = params.rotation * math.pi / 180

        cairo_set_line_width(cr, params.h)
        cairo_set_line_cap(cr, params.cap)

        for pt = 1, params.nb_blocks do
            local blockStartPercentage = (pt - 1) * pcb
            local col, alpha = params.bgc, params.bga

            if pct >= blockStartPercentage then
                col, alpha = params.fgc, params.fga
                if pct >= params.warning and pct < params.alarm then
                    col, alpha = params.wc, params.wa
                elseif pct >= params.alarm then
                    col, alpha = params.alc, params.ala
                end
            end

            local y1 = params.yb - pt * (params.h + params.space)
            local radius0 = params.yb - y1
            local x2 = params.xb + radius0 * math.sin(angle)
            local y2 = params.yb - radius0 * math.cos(angle)

            draw_block(cr, x2, y2, params.w, angle, col, alpha, params.led_effect, params.led_alpha)
        end
    end

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

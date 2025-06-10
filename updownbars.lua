require 'cairo'
require 'cairo_xlib'

-- Global constant for converting degrees to radians, calculated once.
local RAD_TO_DEG = math.pi / 180

-- Helper function: Convert hex color to RGBA components.
-- This function is optimized to return only the R, G, B components.
local function get_rgb_components(colour)
    return ((colour / 0x10000) % 0x100) / 255., ((colour / 0x100) % 0x100) / 255., (colour % 0x100) / 255.
end

-- Helper function: Draw a single block with 3D effect and LED effect
-- Optimized to accept pre-calculated RGB components and sine/cosine of the angle.
local function draw_block(cr, x2, y2, w, cos_angle, sin_angle, r, g, b, alpha, led_effect, led_alpha)
    local xx0, xx1, yy0, yy1

    xx0, xx1 = x2, x2 + w * cos_angle
    yy0, yy1 = y2, y2 + w * sin_angle

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
        local xc, yc = (xx0 + xx1)/2, (yy0 + yy1)/2
        local led_pat = cairo_pattern_create_radial(xc, yc, 0, xc, yc, w/2)
        cairo_pattern_add_color_stop_rgba(led_pat, 0, r, g, b, led_alpha)
        cairo_pattern_add_color_stop_rgba(led_pat, 1, r, g, b, alpha)
        cairo_set_source(cr, led_pat)
        cairo_stroke(cr)
        cairo_pattern_destroy(led_pat)
    end
end

-- Cached network connection check (remains unchanged, already efficient)
local function is_network_connected_cached()
    if _G.cached_is_network_connected == nil then
        local ip = conky_parse('${addr enp4s0}')
        _G.cached_is_network_connected = (ip and ip ~= '' and ip ~= '0.0.0.0')
    end
    return _G.cached_is_network_connected
end

function conky_limit_connections(max_in, max_total)
    -- Convert arguments to numbers
    max_in = tonumber(max_in) or 0
    max_total = tonumber(max_total) or 0

    local in_count = tonumber(conky_parse("${tcp_portmon 1 32767 count}")) or 0
    local out_count = tonumber(conky_parse("${tcp_portmon 32768 61000 count}")) or 0

    -- Limit incoming connections to max_in
    in_count = math.min(in_count, max_in)

    -- Calculate how many outgoing connections we can show without exceeding max_total
    local out_to_show = math.min(out_count, max_total - in_count)

    local out = ""  -- Accumulate output here

    -- Display incoming connections
    for i = 0, in_count - 1 do
        if i >= max_in then break end

        local rip = conky_parse("${tcp_portmon 1 32768 rip " .. i .. "}")
        local rservice = conky_parse("${tcp_portmon 1 32768 rservice " .. i .. "}")
        local rhost = conky_parse("${tcp_portmon 1 32768 rhost " .. i .. "}")

        out = out
            .. "${goto 4}${color6}${voffset -1}${template4}├${color yellow}${template2}In${template4} ←${color2} ${template2}"
            .. rip .. "${alignr 4}" .. rservice .. "\n"
            .. "${voffset -1}${goto 4}${template4}└ ${color3}${template3}" .. rhost .. "\n"
    end

    -- Display outgoing connections
    for i = 0, out_to_show - 1 do
        local rip = conky_parse("${tcp_portmon 32768 61000 rip " .. i .. "}")
        local rservice = conky_parse("${tcp_portmon 32768 61000 rservice " .. i .. "}")
        local rhost = conky_parse("${tcp_portmon 32768 61000 rhost " .. i .. "}")

        out = out
            .. "${goto 4}${color6}${voffset -1}${template4}├${color5}${template2}Out${template4} →${color2} ${template2}"
            .. rip .. "${alignr 4}" .. rservice .. "\n"
            .. "${voffset -1}${goto 4}${template4}└ ${color3}${template3}" .. rhost .. "\n"
    end

    return out
end

-- Pre-hook: Background shading
function conky_draw_pre()
    if conky_window == nil then return end
    if not is_network_connected_cached() then return end

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
    local total_pairs = math.min(in_count + out_count, 25) -- Limit total connections to 25
    local max_pairs = 25
    local draw_pairs = math.min(total_pairs, max_pairs)

    cairo_set_source_rgba(cr, 0.15, 0.50, 1.00, 0.2)

    for i = 0, draw_pairs - 1 do
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
    if not is_network_connected_cached() then return end

    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
                 conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    -- Speed bars configuration
    local bars = {
        {
            xb = 60, yb = 222, name = 'upspeedf', arg = 'enp4s0', max = 20000, nb_blocks = 48,
            cap = CAIRO_LINE_CAP_SQUARE, w = 9, h = 4, space = 1,
            bgc = 0x404040, bga = 0.8,
            fgc = 0x00ff00, fga = 1, wc = 0xffff00, wa = 1,
            alc = 0xff0000, ala = 1, warning = 75, alarm = 90,
            led_effect = true, led_alpha = 0.8, rotation = 90
        },
        {
            xb = 60, yb = 240, name = 'downspeedf', arg = 'enp4s0', max = 100000, nb_blocks = 48,
            cap = CAIRO_LINE_CAP_SQUARE, w = 9, h = 4, space = 1,
            bgc = 0x404040, bga = 0.8,
            fgc = 0x00ff00, fga = 1, wc = 0xffff00, wa = 1,
            alc = 0xff0000, ala = 1, warning = 75, alarm = 90,
            led_effect = true, led_alpha = 0.8, rotation = 90
        }
    }

    for _, params in ipairs(bars) do
        local value = tonumber(conky_parse(string.format('${%s %s}', params.name, params.arg))) or 0
        local log_value = value > 0 and math.log(value + 1) or 0

        params._log_max = params._log_max or math.log(params.max + 1)
        params._angle = params._angle or (params.rotation * RAD_TO_DEG)

        local cos_angle = math.cos(params._angle)
        local sin_angle = math.sin(params._angle)

        local r_bgc, g_bgc, b_bgc = get_rgb_components(params.bgc)
        local r_fgc, g_fgc, b_fgc = get_rgb_components(params.fgc)
        local r_wc, g_wc, b_wc = get_rgb_components(params.wc)
        local r_alc, g_alc, b_alc = get_rgb_components(params.alc)

        local pct = 100 * log_value / params._log_max
        local pcb = 100 / params.nb_blocks

        local yellow_threshold = params.warning
        local red_threshold = params.alarm

        cairo_set_line_width(cr, params.h)
        cairo_set_line_cap(cr, params.cap)

        for pt = 1, params.nb_blocks do
            local blockStartPercentage = (pt - 1) * pcb
            local current_r, current_g, current_b, current_alpha

            if pct >= blockStartPercentage then
                if blockStartPercentage < yellow_threshold then
                    current_r, current_g, current_b, current_alpha = r_fgc, g_fgc, b_fgc, params.fga -- Green
                elseif blockStartPercentage < red_threshold then
                    current_r, current_g, current_b, current_alpha = r_wc, g_wc, b_wc, params.wa     -- Yellow
                else
                    current_r, current_g, current_b, current_alpha = r_alc, g_alc, b_alc, params.ala -- Red
                end
            else
                current_r, current_g, current_b, current_alpha = r_bgc, g_bgc, b_bgc, params.bga
            end

            local y1 = params.yb - pt * (params.h + params.space)
            local radius0 = params.yb - y1
            local x2 = params.xb + radius0 * sin_angle
            local y2 = params.yb - radius0 * cos_angle

            draw_block(cr, x2, y2, params.w, cos_angle, sin_angle,
                       current_r, current_g, current_b, current_alpha,
                       params.led_effect, params.led_alpha)
        end
    end

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

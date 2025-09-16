require 'cairo'
require 'cairo_xlib'

-- CONFIG
local COLORS = {
    bg      = {0.251, 0.251, 0.251, 0.8},
    green   = {0, 1, 0, 1},
    yellow  = {1, 1, 0, 1},
    red     = {1, 0, 0, 1},
    white   = {1, 1, 1, 1},
    bar_bg  = {0.431, 0.133, 0.710, 0.3},
}
local BAR_CONFIG = {
    {
        xb = 60, yb = 220, name = 'upspeedf', arg = 'enp4s0', max = 20000, nb_blocks = 48,
        cap = CAIRO_LINE_CAP_SQUARE, w = 9, h = 4, space = 1,
        warning = 75, alarm = 90,
        led_effect = true, led_alpha = 0.8, rotation = 90
    },
    {
        xb = 60, yb = 238, name = 'downspeedf', arg = 'enp4s0', max = 100000, nb_blocks = 48,
        cap = CAIRO_LINE_CAP_SQUARE, w = 9, h = 4, space = 1,
        warning = 75, alarm = 90,
        led_effect = true, led_alpha = 0.8, rotation = 90
    }
}
local BG_STRIPE = {start_x = 10, start_y = 266, pair_height = 30, total_width = 290, max_pairs = 25}

-- Set your preferred connection limits here:
local MAX_IN = 10      -- maximum inbound connections shown (used if you want per-direction limits)
local MAX_TOTAL = 25   -- maximum total connections shown

-- Precompute
for _, params in ipairs(BAR_CONFIG) do
    params._log_max = math.log(params.max + 1)
    params._angle = (params.rotation or 0) * math.pi / 180
    params._cos_angle = math.cos(params._angle)
    params._sin_angle = math.sin(params._angle)
end

-- Per-update connection table cache
local conn_cache = {
    last_update = -1,
    in_table = nil,
    in_order = nil,
    out_table = nil,
    out_order = nil
}

local function get_update_number()
    return tonumber(conky_parse("${updates}")) or 0
end

local function get_cached_connections(max_in, max_total)
    local upd = get_update_number()
    if conn_cache.last_update ~= upd then
        conn_cache.in_table, conn_cache.in_order = collect_connections(1, 32767, max_total)
        conn_cache.out_table, conn_cache.out_order = collect_connections(32768, 61000, max_total)
        conn_cache.last_update = upd
    end
    return conn_cache.in_table, conn_cache.in_order, conn_cache.out_table, conn_cache.out_order
end

-- NETWORK CONNECTED
local function is_network_connected()
    local ip = conky_parse('${addr enp4s0}')
    return (ip and ip ~= '' and ip ~= '0.0.0.0')
end

-- DRAW BLOCK: NO CACHE
local function draw_block(cr, x2, y2, w, cos_angle, sin_angle, color, led_effect, led_alpha)
    local r, g, b, a = table.unpack(color)
    local xx0, xx1 = x2, x2 + w * cos_angle
    local yy0, yy1 = y2, y2 + w * sin_angle

    local pat = cairo_pattern_create_linear(xx0, yy0, xx0, yy1)
    cairo_pattern_add_color_stop_rgba(pat, 0, r, g, b, a * 0.4)
    cairo_pattern_add_color_stop_rgba(pat, 0.5, r, g, b, a)
    cairo_pattern_add_color_stop_rgba(pat, 1, r, g, b, a * 0.4)
    cairo_set_source(cr, pat)
    cairo_move_to(cr, xx0, yy0)
    cairo_line_to(cr, xx1, yy1)
    cairo_stroke(cr)
    cairo_pattern_destroy(pat)

    if led_effect then
        local xc, yc = (xx0 + xx1)/2, (yy0 + yy1)/2
        local led_pat = cairo_pattern_create_radial(xc, yc, 0, xc, yc, w/2)
        cairo_pattern_add_color_stop_rgba(led_pat, 0, r, g, b, led_alpha)
        cairo_pattern_add_color_stop_rgba(led_pat, 1, r, g, b, a)
        cairo_set_source(cr, led_pat)
        cairo_stroke(cr)
        cairo_pattern_destroy(led_pat)
    end
end

-- Connection condensation logic: always scan ALL connections for the range, fill up to max_display unique
function collect_connections(start_port, end_port, max_display)
    local total_conns = tonumber(conky_parse("${tcp_portmon " .. start_port .. " " .. end_port .. " count}")) or 0
    local ip_table = {}
    local order = {}
    for i = 0, total_conns - 1 do
        if #order >= max_display then break end
        local rip = conky_parse("${tcp_portmon " .. start_port .. " " .. end_port .. " rip " .. i .. "}")
        if not rip or rip == "" then break end
        if not ip_table[rip] then
            local rservice = conky_parse("${tcp_portmon " .. start_port .. " " .. end_port .. " rservice " .. i .. "}")
            local rhost = conky_parse("${tcp_portmon " .. start_port .. " " .. end_port .. " rhost " .. i .. "}")
            ip_table[rip] = {count = 1, service = rservice, host = rhost}
            table.insert(order, rip)
        else
            ip_table[rip].count = ip_table[rip].count + 1
        end
    end
    return ip_table, order
end

-- New: Get the displayed connections as a single ordered list (for stripes and display)
local function get_displayed_connections(max_in, max_total)
    local in_table, in_order, out_table, out_order = get_cached_connections(max_in, max_total)
    local entries = {}
    local total = 0

    for _, rip in ipairs(in_order) do
        if total >= max_total then break end
        table.insert(entries, {direction="in", rip=rip, info=in_table[rip]})
        total = total + 1
    end
    for _, rip in ipairs(out_order) do
        if total >= max_total then break end
        table.insert(entries, {direction="out", rip=rip, info=out_table[rip]})
        total = total + 1
    end

    return entries
end

-- BACKGROUND STRIPES: Shade every other displayed connection row, not just visible slots
local function draw_background_stripes(cr, display_entries)
    cairo_set_source_rgba(cr, table.unpack(COLORS.bar_bg))
    for idx, _ in ipairs(display_entries) do
        if idx % 2 == 0 then -- shade every other row; Lua arrays are 1-based
            local y_pos = BG_STRIPE.start_y + ((idx-1) * BG_STRIPE.pair_height)
            cairo_rectangle(cr, BG_STRIPE.start_x, y_pos, BG_STRIPE.total_width, BG_STRIPE.pair_height)
            cairo_fill(cr)
        end
    end
end

-- CONKY HOOKS

function conky_limit_connections(max_in, max_total)
    max_in = tonumber(max_in) or 0
    max_total = tonumber(max_total) or 0

    local display_entries = get_displayed_connections(max_in, max_total)
    local out = ""

    for _, entry in ipairs(display_entries) do
        local info = entry.info
        local display_ip = info.count > 1 and (entry.rip .. " (" .. info.count .. ")") or entry.rip
        if entry.direction == "in" then
            out = out
                .. "${goto 4}${color6}${voffset -1}${template4}├${color yellow}${template2}In${template4} ←${color2} ${template2}"
                .. display_ip .. "${alignr 4}" .. info.service .. "\n"
                .. "${voffset -1}${goto 4}${template4}└ ${color3}${template3}" .. info.host .. "\n"
        else
            out = out
                .. "${color6}${voffset -1}${template4}├${color5}${template2}Out${template4} →${color2} ${template2}"
                .. display_ip .. "${alignr 4}" .. info.service .. "\n"
                .. "${voffset -1}${template4}└ ${color3}${template3}" .. info.host .. "\n"
        end
    end

    return out
end

function conky_draw_pre()
    if conky_window == nil then return end
    if not is_network_connected() then return end
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
                 conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    local display_entries = get_displayed_connections(MAX_IN, MAX_TOTAL)
    draw_background_stripes(cr, display_entries)

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

function conky_draw_post()
    if conky_window == nil then return end
    if not is_network_connected() then return end
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
                 conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)
    for _, params in ipairs(BAR_CONFIG) do
        local value = tonumber(conky_parse(string.format('${%s %s}', params.name, params.arg))) or 0
        local log_value = (value > 0) and math.log(value + 1) or 0
        local pct = 100 * log_value / params._log_max
        local pcb = 100 / params.nb_blocks
        local y_step = params.h + params.space

        cairo_set_line_width(cr, params.h)
        cairo_set_line_cap(cr, params.cap)

        for pt = 1, params.nb_blocks do
            local blockStartPercentage = (pt - 1) * pcb
            local color
            if pct >= blockStartPercentage then
                if blockStartPercentage < params.warning then
                    color = COLORS.green
                elseif blockStartPercentage < params.alarm then
                    color = COLORS.yellow
                else
                    color = COLORS.red
                end
            else
                color = COLORS.bg
            end
            local y1 = params.yb - pt * y_step
            local radius0 = params.yb - y1
            local x2 = params.xb + radius0 * params._sin_angle
            local y2 = params.yb - radius0 * params._cos_angle
            draw_block(cr, x2, y2, params.w, params._cos_angle, params._sin_angle, color,
                       params.led_effect, params.led_alpha)
        end
    end
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

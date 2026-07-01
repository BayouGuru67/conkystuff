require 'cairo'

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
        xb = 52, yb = 225, name = 'upspeedf', arg = 'enp7s0', max = 20000, nb_blocks = 40,
        cap = CAIRO_LINE_CAP_SQUARE, w = 9, h = 4, space = 1,
        warning = 75, alarm = 90,
        led_effect = true, led_alpha = 0.8, rotation = 90
    },
    {
        xb = 52, yb = 241, name = 'downspeedf', arg = 'enp7s0', max = 100000, nb_blocks = 40,
        cap = CAIRO_LINE_CAP_SQUARE, w = 9, h = 4, space = 1,
        warning = 75, alarm = 90,
        led_effect = true, led_alpha = 0.8, rotation = 90
    }
}

local BG_STRIPE = {start_x = 8, start_y = 271, pair_height = 34, total_width = 252}

-- Precompute bar parameters once at load time
for _, params in ipairs(BAR_CONFIG) do
    params._log_max = math.log(params.max + 1)
    params._angle = (params.rotation or 0) * math.pi / 180
    params._cos_angle = math.cos(params._angle)
    params._sin_angle = math.sin(params._angle)
    params._y_step = params.h + params.space
    params._pcb = 100 / params.nb_blocks
end

-- Cache for connection data
local conn_cache = {
    last_update = -1,
    in_table = {},
    in_order = {},
    out_table = {},
    out_order = {}
}

local last_sync_update = -1
local last_display_entries = {}

local function get_update_number()
    return tonumber(conky_parse("${updates}")) or 0
end

function conky_sync_connections()
    local upd = get_update_number()
    if last_sync_update ~= upd then
        last_sync_update = upd
        conn_cache.last_update = -1
    end
    return ""
end

local function collect_connections(start_port, end_port, max_display)
    local total_conns = tonumber(conky_parse("${tcp_portmon " .. start_port .. " " .. end_port .. " count}")) or 0
    if total_conns == 0 then
        return {}, {}
    end

    local ip_table = {}
    local order = {}
    local safety_counter = 0

    for i = 0, total_conns - 1 do
        safety_counter = safety_counter + 1
        if safety_counter > 5000 then break end
        if #order >= max_display then break end

        local rip = conky_parse("${tcp_portmon " .. start_port .. " " .. end_port .. " rip " .. i .. "}")

        if rip and rip ~= "" then
            if not ip_table[rip] then
                local rservice = conky_parse("${tcp_portmon " .. start_port .. " " .. end_port .. " rservice " .. i .. "}") or ""
                local rhost = conky_parse("${tcp_portmon " .. start_port .. " " .. end_port .. " rhost " .. i .. "}") or ""
                ip_table[rip] = {count = 1, service = rservice, host = rhost}
                table.insert(order, rip)
            else
                ip_table[rip].count = ip_table[rip].count + 1
            end
        end
    end

    return ip_table, order
end

local function get_cached_connections(max_in, max_total)
    local upd = get_update_number()
    if conn_cache.last_update ~= upd then
        local in_table, in_order = collect_connections(1, 32767, max_total)
        local out_table, out_order = collect_connections(32768, 61000, max_total)
        conn_cache.in_table = in_table
        conn_cache.in_order = in_order
        conn_cache.out_table = out_table
        conn_cache.out_order = out_order
        conn_cache.last_update = upd
    end
    return conn_cache.in_table, conn_cache.in_order, conn_cache.out_table, conn_cache.out_order
end

local function get_displayed_connections(max_in, max_total)
    local in_table, in_order, out_table, out_order = get_cached_connections(max_in, max_total)
    local entries = {}
    local total = 0

    for _, rip in ipairs(in_order) do
        if total >= max_total then break end
        entries[total + 1] = {direction = "in", rip = rip, info = in_table[rip]}
        total = total + 1
    end

    for _, rip in ipairs(out_order) do
        if total >= max_total then break end
        entries[total + 1] = {direction = "out", rip = rip, info = out_table[rip]}
        total = total + 1
    end

    return entries
end

function conky_limit_connections(max_in, max_total)
    max_in = tonumber(max_in) or 6
    max_total = tonumber(max_total) or 25

    last_display_entries = get_displayed_connections(max_in, max_total)

    if #last_display_entries == 0 then
        return ""
    end

    local out = {}
    for _, entry in ipairs(last_display_entries) do
        local info = entry.info
        local display_ip = entry.rip
        if info.count > 1 then
            display_ip = display_ip .. " (" .. info.count .. ")"
        end

        local service = (info.service and info.service ~= "") and info.service or ""
        local host = (info.host and info.host ~= "") and info.host or ""

        if entry.direction == "in" then
            table.insert(out, "${goto 4}${color6}${template4}├${color yellow}${template2}In${template4} ←${color2} ${template2}"
                .. display_ip .. "${alignr 4}" .. service .. "\n"
                .. "${goto 4}${template4}└ ${color3}${template3}" .. host .. "\n")
        else
            table.insert(out, "${color6}${template4}├${color5}${template2}Out${template4} →${color2} ${template2}"
                .. display_ip .. "${alignr 4}" .. service .. "\n"
                .. "${template4}└ ${color3}${template3}" .. host .. "\n")
        end
    end

    return table.concat(out)
end

-- COMBINED DRAW HOOK - does both background stripes AND bars in one pass
function conky_draw_post()
    local surface = conky_surface()
    if not surface then
        return
    end

    local cr = cairo_create(surface)
    if not cr then
        return
    end

    -- Draw background stripes FIRST (moved from conky_draw_pre)
    if last_display_entries and #last_display_entries > 0 then
        cairo_set_source_rgba(cr, table.unpack(COLORS.bar_bg))
        for idx = 1, #last_display_entries do
            if idx % 2 == 0 then
                local y_pos = BG_STRIPE.start_y + ((idx - 1) * BG_STRIPE.pair_height)
                cairo_rectangle(cr, BG_STRIPE.start_x, y_pos, BG_STRIPE.total_width, BG_STRIPE.pair_height)
                cairo_fill(cr)
            end
        end
    end

    -- Draw speed bars
    for _, params in ipairs(BAR_CONFIG) do
        local value = tonumber(conky_parse(string.format('${%s %s}', params.name, params.arg))) or 0
        local log_value = (value > 0) and math.log(value + 1) or 0
        local pct = 100 * log_value / params._log_max

        cairo_set_line_width(cr, params.h)
        cairo_set_line_cap(cr, params.cap)

        for pt = 1, params.nb_blocks do
            local blockStartPercentage = (pt - 1) * params._pcb

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

            local radius0 = pt * params._y_step
            local x2 = params.xb + radius0 * params._sin_angle
            local y2 = params.yb - radius0 * params._cos_angle

            local r, g, b, a = table.unpack(color)
            local w = params.w
            local xx0, xx1 = x2, x2 + w * params._cos_angle
            local yy0, yy1 = y2, y2 + w * params._sin_angle

            local pat = cairo_pattern_create_linear(xx0, yy0, xx0, yy1)
            cairo_pattern_add_color_stop_rgba(pat, 0, r, g, b, a * 0.4)
            cairo_pattern_add_color_stop_rgba(pat, 0.5, r, g, b, a)
            cairo_pattern_add_color_stop_rgba(pat, 1, r, g, b, a * 0.4)
            cairo_set_source(cr, pat)
            cairo_move_to(cr, xx0, yy0)
            cairo_line_to(cr, xx1, yy1)
            cairo_stroke(cr)
            cairo_pattern_destroy(pat)

            if params.led_effect then
                local xc, yc = (xx0 + xx1) / 2, (yy0 + yy1) / 2
                local led_pat = cairo_pattern_create_radial(xc, yc, 0, xc, yc, w / 2)
                cairo_pattern_add_color_stop_rgba(led_pat, 0, r, g, b, params.led_alpha)
                cairo_pattern_add_color_stop_rgba(led_pat, 1, r, g, b, a)
                cairo_set_source(cr, led_pat)
                cairo_stroke(cr)
                cairo_pattern_destroy(led_pat)
            end
        end
    end

    cairo_destroy(cr)
    cairo_surface_flush(surface)
end

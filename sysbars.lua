require 'cairo'
require 'cairo_xlib'

-- === CONFIGURATION TABLES ===
local COLORS = {
    bg      = {0.251, 0.251, 0.251, 0.7},      -- 0x404040, 0.7
    green   = {0, 1, 0, 1},                    -- 0x00ff00, 1
    yellow  = {1, 1, 0, 1},                    -- 0xffff00, 1
    red     = {1, 0, 0, 1},                    -- 0xff0000, 1
}

local BAR_CONFIG = {
    {
        xb = 48, yb = 180, name = 'memperc', arg = '', max = 100, nb_blocks = 43,
    }, {
        xb = 48, yb = 304, name = 'fs_used_perc', arg = '/', max = 100, nb_blocks = 43,
    }, {
        xb = 48, yb = 368, name = 'fs_used_perc', arg = '/home/bayouguru/N-1Tb/', max = 100, nb_blocks = 43,
    }, {
        xb = 48, yb = 432, name = 'swapperc', arg = '', max = 100, nb_blocks = 43,
    }
}
local BAR_STYLE = {
    cap = CAIRO_LINE_CAP_SQUARE, w = 8, h = 4, space = 1,
    bgc = COLORS.bg,    bga = 0.7,
    fgc = COLORS.green, fga = 1,
    yelc = COLORS.yellow, yela = 1,
    alc = COLORS.red,   ala = 1,
    alarm = 75, high_alarm = 90,
    led_effect = true, led_alpha = 0.9,
    rotation = 90,
}
local ANGLE = (BAR_STYLE.rotation or 0) * math.pi / 180
local COS_ANGLE, SIN_ANGLE = math.cos(ANGLE), math.sin(ANGLE)

local LEDS = {
    {x = 78,  y = 10,  sensor = '${hwmon 1 temp 1}', thresholds = {green = 140, red = 160}},
    {x = 182, y = 10,  sensor = '${hwmon 1 temp 2}', thresholds = {green = 120, red = 148}},
    {x = 142, y = 42,  state = "CapsLock"},
    {x = 253, y = 42,  state = "NumLock"},
    {x = 26,  y = 338, sensor = '${hwmon 2 temp 1}', thresholds = {green = 120, red = 140}},
    {x = 26,  y = 402, sensor = '${hwmon 3 temp 1}', thresholds = {green = 120, red = 140}},
    {x = 26,  y = 435, sensor = '${swapperc}',       thresholds = {green = 75, red = 90}},
}

-- === LOCAL HELPERS ===
local function draw_block(cr, x2, y2, w, cos_angle, sin_angle, color, led_effect, led_alpha, pattern_cache)
    local r, g, b, a = table.unpack(color)
    local xx0, xx1 = x2, x2 + w * cos_angle
    local yy0, yy1 = y2, y2 + w * sin_angle
    local pat_key = string.format("%.3f,%.3f,%.3f,%.3f,%.1f", r, g, b, a, w)
    local pat = pattern_cache[pat_key]
    if not pat then
        pat = cairo_pattern_create_linear(xx0, yy0, xx0, yy1)
        cairo_pattern_add_color_stop_rgba(pat, 0, r, g, b, a * 0.4)
        cairo_pattern_add_color_stop_rgba(pat, 0.5, r, g, b, a)
        cairo_pattern_add_color_stop_rgba(pat, 1, r, g, b, a * 0.4)
        pattern_cache[pat_key] = pat
    end
    cairo_set_source(cr, pat)
    cairo_move_to(cr, xx0, yy0)
    cairo_line_to(cr, xx1, yy1)
    cairo_stroke(cr)
    if led_effect then
        local xc, yc = (xx0 + xx1) / 2, (yy0 + yy1) / 2
        local led_pat = cairo_pattern_create_radial(xc, yc, 0, xc, yc, w / 2)
        cairo_pattern_add_color_stop_rgba(led_pat, 0, r, g, b, led_alpha)
        cairo_pattern_add_color_stop_rgba(led_pat, 1, r, g, b, a)
        cairo_set_source(cr, led_pat)
        cairo_stroke(cr)
        cairo_pattern_destroy(led_pat)
    end
end

local function draw_led(cr, x, y, state, thresholds, caps_lock_state, num_lock_state)
    local color
    if state == "CapsLock" then
        color = caps_lock_state and COLORS.red or COLORS.green
    elseif state == "NumLock" then
        color = num_lock_state and COLORS.green or COLORS.red
    else
        if type(state) ~= "number" then state = thresholds.red + 1 end
        if state <= thresholds.green then
            color = COLORS.green
        elseif state >= thresholds.red then
            color = COLORS.red
        else
            color = COLORS.yellow
        end
    end
    local r, g, b, a = table.unpack(color)
    local radius = 8
    local pat = cairo_pattern_create_radial(x, y, 0, x, y, radius)
    cairo_pattern_add_color_stop_rgba(pat, 0.0, r, g, b, a)
    cairo_pattern_add_color_stop_rgba(pat, 0.5, r, g, b, a)
    cairo_pattern_add_color_stop_rgba(pat, 1.0, r, g, b, 0.0)
    cairo_set_source(cr, pat)
    cairo_arc(cr, x, y, radius, 0, 2 * math.pi)
    cairo_fill(cr)
    cairo_pattern_destroy(pat)
end

function conky_draw_post()
    if conky_window == nil then return end
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
        conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    local caps_lock_state = conky_parse('${key_caps_lock}') == "On"
    local num_lock_state = conky_parse('${key_num_lock}') == "On"

    -- Bars
    for _, bar in ipairs(BAR_CONFIG) do
        local value = tonumber(conky_parse(string.format('${%s %s}', bar.name, bar.arg))) or 0
        local pct = 100 * value / bar.max
        local pcb = 100 / bar.nb_blocks
        cairo_set_line_width(cr, BAR_STYLE.h)
        cairo_set_line_cap(cr, BAR_STYLE.cap)
        local pattern_cache = {}
        for pt = 1, bar.nb_blocks do
            local blockStartPercentage = (pt - 1) * pcb
            local color = BAR_STYLE.bgc
            if pct >= blockStartPercentage then
                if blockStartPercentage < BAR_STYLE.alarm then
                    color = BAR_STYLE.fgc
                elseif blockStartPercentage < BAR_STYLE.high_alarm then
                    color = BAR_STYLE.yelc
                else
                    color = BAR_STYLE.alc
                end
            end
            local y1 = bar.yb - pt * (BAR_STYLE.h + BAR_STYLE.space)
            local radius0 = bar.yb - y1
            local x2 = bar.xb + radius0 * SIN_ANGLE
            local y2 = bar.yb - radius0 * COS_ANGLE
            draw_block(cr, x2, y2, BAR_STYLE.w, COS_ANGLE, SIN_ANGLE, color, BAR_STYLE.led_effect, BAR_STYLE.led_alpha, pattern_cache)
        end
        for _, pat in pairs(pattern_cache) do cairo_pattern_destroy(pat) end
    end

    -- LEDs
    for _, led in ipairs(LEDS) do
        local state, thresholds = led.state, led.thresholds
        if led.sensor then
            state = tonumber(conky_parse(led.sensor))
        end
        draw_led(cr, led.x, led.y, state, thresholds or {green = 75, red = 90}, caps_lock_state, num_lock_state)
    end

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

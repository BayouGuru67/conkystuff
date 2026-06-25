require 'cairo'

-- ============================================================
-- USER CONFIGURATION – POSITIONING
-- Edit these values to adjust bar and LED positions
-- ============================================================

-- CPU bar positions: {x, y, cpu_name, num_blocks}
local CPU_BAR_POSITIONS = {
    {8,   20,  'cpu1',  25},
    {140, 20,  'cpu2',  25},
    {8,   49,  'cpu3',  25},
    {140, 49,  'cpu4',  25},
    {8,   78,  'cpu5',  25},
    {140, 78,  'cpu6',  25},
    {8,   107, 'cpu7',  25},
    {140, 107, 'cpu8',  25},
    {8,   136, 'cpu9',  25},
    {140, 136, 'cpu10', 25},
    {8,   165, 'cpu11', 25},
    {140, 165, 'cpu12', 25},
    {8,   193, 'cpu0',  51},  -- Average
}

-- GPU bar positions
-- block_x/y = where the bar blocks start
local GPU_BAR_POSITIONS = {
    {
        card = "card1",      -- RX580
        block_x = 44, block_y = 235,
        nb_blocks = 44
    },
    {
        card = "card0",      -- Integrated GPU
        block_x = 44, block_y = 281,
        nb_blocks = 44
    }
}

-- LED positions: {x, y, sensor, thresholds}
local LED_POSITIONS = {
    {x = 210, y = 10,  sensor = '${hwmon 4 temp 1}', thresholds = {green = 140, red = 155}},
    {x = 210, y = 223, sensor = '${hwmon 6 temp 1}', thresholds = {green = 140, red = 155}},
    {x = 210, y = 270, sensor = '${hwmon 7 temp 1}', thresholds = {green = 140, red = 155}}
}

-- Bar style
local BAR_STYLE = {
    max = 100,
    cap = CAIRO_LINE_CAP_SQUARE,
    w = 8,
    h = 4,
    space = 1,
    led_effect = true,
    led_alpha = 0.7,
    rotation = 90,
    alarm = 75,
}

-- ============================================================
-- END USER CONFIGURATION
-- ============================================================

-- === COLORS ===
local COLORS = {
    bg       = {0.251, 0.251, 0.251, 0.8},
    green    = {0, 1, 0, 1},
    yellow   = {1, 1, 0, 1},
    red      = {1, 0, 0, 1},
    orange   = {1, 0.549, 0, 1},
    lightblue= {0.678, 0.847, 0.902, 1},
}

-- === BUILD CONFIG TABLES FROM USER POSITIONS ===
local BAR_CONFIG = {}
for _, pos in ipairs(CPU_BAR_POSITIONS) do
    table.insert(BAR_CONFIG, {pos[1], pos[2], pos[3], pos[4]})
    end

    local GPU_BARS = GPU_BAR_POSITIONS
    local LEDS = LED_POSITIONS

    -- === PRECOMPUTED ANGLES & BAR BLOCKS ===
    local ANGLE = (BAR_STYLE.rotation or 0) * math.pi / 180

    local bar_block_geometry = {}
    local bar_inactive_patterns = {}

    local function precompute_bar_blocks(xb, yb, nb_blocks)
    local y_step = BAR_STYLE.h + BAR_STYLE.space
    local blocks = {}
    for pt = 1, nb_blocks do
        local radius = (pt - 1) * y_step
        local x2 = xb + radius * math.sin(ANGLE)
        local y2 = yb - radius * math.cos(ANGLE)
        local xx1 = x2 + BAR_STYLE.w * math.cos(ANGLE)
        local yy1 = y2 + BAR_STYLE.w * math.sin(ANGLE)
        blocks[pt] = {x2 = x2, y2 = y2, xx1 = xx1, yy1 = yy1}
        end
        return blocks
        end

        local function precompute_inactive_patterns(blocks)
        local patterns = {}
        local r, g, b, a = table.unpack(COLORS.bg)
        for pt, blk in ipairs(blocks) do
            local pat = cairo_pattern_create_linear(blk.x2, blk.y2, blk.x2, blk.yy1)
            cairo_pattern_add_color_stop_rgba(pat, 0, r, g, b, a * 0.4)
            cairo_pattern_add_color_stop_rgba(pat, 0.5, r, g, b, a)
            cairo_pattern_add_color_stop_rgba(pat, 1, r, g, b, a * 0.4)
            patterns[pt] = pat
            end
            return patterns
            end

            for idx, bar in ipairs(BAR_CONFIG) do
                local blocks = precompute_bar_blocks(bar[1], bar[2], bar[4])
                bar_block_geometry[idx] = blocks
                bar_inactive_patterns[idx] = precompute_inactive_patterns(blocks)
                end

                -- === DRAWING HELPERS ===
                local function draw_block(cr, x2, y2, xx1, yy1, color, led_effect, led_alpha)
                local r, g, b, a = table.unpack(color)
                local pat = cairo_pattern_create_linear(x2, y2, x2, yy1)
                cairo_pattern_add_color_stop_rgba(pat, 0, r, g, b, a * 0.4)
                cairo_pattern_add_color_stop_rgba(pat, 0.5, r, g, b, a)
                cairo_pattern_add_color_stop_rgba(pat, 1, r, g, b, a * 0.4)
                cairo_set_source(cr, pat)
                cairo_move_to(cr, x2, y2)
                cairo_line_to(cr, xx1, yy1)
                cairo_stroke(cr)
                cairo_pattern_destroy(pat)
                if led_effect then
                    local xc, yc = (x2 + xx1) * 0.5, (y2 + yy1) * 0.5
                    local led_pat = cairo_pattern_create_radial(xc, yc, 0, xc, yc, (xx1-x2 + yy1-y2) * 0.25)
                    cairo_pattern_add_color_stop_rgba(led_pat, 0, r, g, b, led_alpha)
                    cairo_pattern_add_color_stop_rgba(led_pat, 1, r, g, b, a)
                    cairo_set_source(cr, led_pat)
                    cairo_stroke(cr)
                    cairo_pattern_destroy(led_pat)
                    end
                    end

                    -- === CPU BAR DRAWING ===
                    local function equalizer_cpu(cr, bar_idx, name, arg, max, nb_blocks, style)
                    local value = tonumber(conky_parse('${' .. name .. ' ' .. arg .. '}')) or 0
                    local pct = math.min(100, math.max(0, 100 * value / max))
                    local lit_blocks = math.floor(nb_blocks * pct / 100 + 0.5)
                    local yellow_threshold, red_threshold = 75, 90

                    cairo_set_line_width(cr, style.h)
                    cairo_set_line_cap(cr, style.cap)
                    local bar_blocks = bar_block_geometry[bar_idx]
                    local inactive_patterns = bar_inactive_patterns[bar_idx]

                    for pt = 1, nb_blocks do
                        local blk = bar_blocks[pt]
                        if pt <= lit_blocks then
                            local block_pct_threshold = (pt - 1) * 100 / nb_blocks
                            local color
                            if block_pct_threshold < yellow_threshold then
                                color = COLORS.green
                                elseif block_pct_threshold < red_threshold then
                                    color = COLORS.yellow
                                    else
                                        color = COLORS.red
                                        end
                                        draw_block(cr, blk.x2, blk.y2, blk.xx1, blk.yy1, color, style.led_effect, style.led_alpha)
                                        else
                                            cairo_set_source(cr, inactive_patterns[pt])
                                            cairo_move_to(cr, blk.x2, blk.y2)
                                            cairo_line_to(cr, blk.xx1, blk.yy1)
                                            cairo_stroke(cr)
                                            if style.led_effect then
                                                local xc, yc = (blk.x2 + blk.xx1) * 0.5, (blk.y2 + blk.yy1) * 0.5
                                                local r, g, b, a = table.unpack(COLORS.bg)
                                                local led_pat = cairo_pattern_create_radial(xc, yc, 0, xc, yc, (blk.xx1-blk.x2 + blk.yy1-blk.y2) * 0.25)
                                                cairo_pattern_add_color_stop_rgba(led_pat, 0, r, g, b, style.led_alpha)
                                                cairo_pattern_add_color_stop_rgba(led_pat, 1, r, g, b, a)
                                                cairo_set_source(cr, led_pat)
                                                cairo_stroke(cr)
                                                cairo_pattern_destroy(led_pat)
                                                end
                                                end
                                                end
                                                end

                                                -- === GPU BAR DRAWING (no percentage overlay) ===
                                                local function draw_gpu_bar(cr, card, block_x, block_y, nb_blocks, style)
                                                local value = tonumber(conky_parse('${exec cat /sys/class/drm/' .. card .. '/device/gpu_busy_percent}')) or 0
                                                local pct = math.min(100, math.max(0, value))
                                                local lit_blocks = math.floor(nb_blocks * pct / 100 + 0.5)
                                                local yellow_threshold, red_threshold = 75, 90
                                                local y_step = BAR_STYLE.h + BAR_STYLE.space
                                                local angle = ANGLE

                                                -- Draw bar blocks only (no percentage overlay text)
                                                cairo_set_line_width(cr, style.h)
                                                cairo_set_line_cap(cr, style.cap)

                                                for pt = 1, nb_blocks do
                                                    local radius = (pt - 1) * y_step
                                                    local x2 = block_x + radius * math.sin(angle)
                                                    local y2 = block_y - radius * math.cos(angle)
                                                    local xx1 = x2 + BAR_STYLE.w * math.cos(angle)
                                                    local yy1 = y2 + BAR_STYLE.w * math.sin(angle)
                                                    if pt <= lit_blocks then
                                                        local block_pct_threshold = (pt - 1) * 100 / nb_blocks
                                                        local color
                                                        if block_pct_threshold < yellow_threshold then
                                                            color = COLORS.green
                                                            elseif block_pct_threshold < red_threshold then
                                                                color = COLORS.yellow
                                                                else
                                                                    color = COLORS.red
                                                                    end
                                                                    draw_block(cr, x2, y2, xx1, yy1, color, style.led_effect, style.led_alpha)
                                                                    else
                                                                        local r, g, b, a = table.unpack(COLORS.bg)
                                                                        local pat = cairo_pattern_create_linear(x2, y2, x2, yy1)
                                                                        cairo_pattern_add_color_stop_rgba(pat, 0, r, g, b, a * 0.4)
                                                                        cairo_pattern_add_color_stop_rgba(pat, 0.5, r, g, b, a)
                                                                        cairo_pattern_add_color_stop_rgba(pat, 1, r, g, b, a * 0.4)
                                                                        cairo_set_source(cr, pat)
                                                                        cairo_move_to(cr, x2, y2)
                                                                        cairo_line_to(cr, xx1, yy1)
                                                                        cairo_stroke(cr)
                                                                        cairo_pattern_destroy(pat)
                                                                        if style.led_effect then
                                                                            local xc, yc = (x2 + xx1) * 0.5, (y2 + yy1) * 0.5
                                                                            local led_pat = cairo_pattern_create_radial(xc, yc, 0, xc, yc, (xx1-x2 + yy1-y2) * 0.25)
                                                                            cairo_pattern_add_color_stop_rgba(led_pat, 0, r, g, b, style.led_alpha)
                                                                            cairo_pattern_add_color_stop_rgba(led_pat, 1, r, g, b, a)
                                                                            cairo_set_source(cr, led_pat)
                                                                            cairo_stroke(cr)
                                                                            cairo_pattern_destroy(led_pat)
                                                                            end
                                                                            end
                                                                            end
                                                                            end

                                                                            -- === LED DRAWING ===
                                                                            local function draw_led(cr, x, y, value, thresholds)
                                                                            local color
                                                                            if type(value) ~= "number" then value = thresholds.red + 1 end
                                                                                if value <= thresholds.green then
                                                                                    color = COLORS.green
                                                                                    elseif value >= thresholds.red then
                                                                                        color = COLORS.red
                                                                                        else
                                                                                            color = COLORS.yellow
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

                                                                                            -- === CONKY HOOKS (Wayland) ===
                                                                                            function conky_conkycpubars_draw_pre()
                                                                                            -- No background rectangles
                                                                                            return
                                                                                            end

                                                                                            function conky_conkycpubars_widgets()
                                                                                            local surface = conky_surface()
                                                                                            if not surface then return end
                                                                                                local cr = cairo_create(surface)
                                                                                                if not cr then return end

                                                                                                    for idx, bar in ipairs(BAR_CONFIG) do
                                                                                                        equalizer_cpu(cr, idx, 'cpu', bar[3], BAR_STYLE.max, bar[4], BAR_STYLE)
                                                                                                        end

                                                                                                        for _, gpu in ipairs(GPU_BARS) do
                                                                                                            draw_gpu_bar(cr, gpu.card, gpu.block_x, gpu.block_y, gpu.nb_blocks, BAR_STYLE)
                                                                                                            end

                                                                                                            for _, led in ipairs(LEDS) do
                                                                                                                local value = tonumber(conky_parse(led.sensor))
                                                                                                                draw_led(cr, led.x, led.y, value, led.thresholds)
                                                                                                                end

                                                                                                                cairo_destroy(cr)
                                                                                                                end

require 'cairo'

-- ==========================================================
-- BayouGuru's Top CPU/RAM Conky Background Stripes
-- Wayland Display Output Version
-- ==========================================================

local STRIPE_COLOR = {0.431, 0.133, 0.710, 0.30} -- Purple with 30% opacity

local SECTIONS = {
    {start_y = 31,  line_height = 16, total_width = 256, lines = 10}, -- RAM
    {start_y = 207, line_height = 16, total_width = 256, lines = 10}, -- CPU
}

local function draw_stripes(cr, section)
cairo_set_operator(cr, CAIRO_OPERATOR_OVER)

for i = 0, section.lines - 1 do
    if (i % 2) == 1 then
        cairo_set_source_rgba(
            cr,
            STRIPE_COLOR[1],
            STRIPE_COLOR[2],
            STRIPE_COLOR[3],
            STRIPE_COLOR[4]
        )

        cairo_rectangle(
            cr,
            8,
            section.start_y + (i * section.line_height),
                        section.total_width,
                        section.line_height
        )

        cairo_fill(cr)
        end
        end
        end

        function conky_draw_pre()
        -- Use the backend-neutral conky_surface() function
        local surface = conky_surface()
        if not surface then
            return
            end

            local cr = cairo_create(surface)
            if not cr then
                return
                end

                for _, section in ipairs(SECTIONS) do
                    draw_stripes(cr, section)
                    end

                    cairo_destroy(cr)
                    end

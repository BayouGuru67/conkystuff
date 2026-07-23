require 'cairo'

local STRIPE_COLOR = {0.431, 0.133, 0.710, 0.30}

local SECTIONS = {
    {start_y = 31,  line_height = 16, total_width = 256, lines = 5},
    {start_y = 127, line_height = 16, total_width = 256, lines = 10},
}

-- Precompute stripe positions at load time
local STRIPE_POSITIONS = {}
for _, section in ipairs(SECTIONS) do
    for i = 0, section.lines - 1 do
        if (i % 2) == 1 then
            table.insert(STRIPE_POSITIONS, {
                y = section.start_y + (i * section.line_height),
                w = section.total_width,
                h = section.line_height
            })
        end
    end
end

function conky_draw_pre()
    local surface = conky_surface()
    if not surface then return end
    local cr = cairo_create(surface)
    if not cr then return end

    cairo_set_operator(cr, CAIRO_OPERATOR_OVER)
    cairo_set_source_rgba(cr, table.unpack(STRIPE_COLOR))

    for _, pos in ipairs(STRIPE_POSITIONS) do
        cairo_rectangle(cr, 8, pos.y, pos.w, pos.h)
        cairo_fill(cr)
    end

    cairo_destroy(cr)
    cairo_surface_flush(surface)
end

require 'cairo'
require 'cairo_xlib'

-- === CONFIG ===
local STRIPE_COLOR = {0.431, 0.133, 0.710, 0.3}
local SECTIONS = {
    {start_y = 32,  line_height = 16, total_width = 254, lines = 10},  -- RAM
    {start_y = 207, line_height = 16, total_width = 254, lines = 10},  -- CPU
}

-- === LOCAL HELPERS ===
local function draw_stripes(cr, section)
    for i = 0, section.lines - 1 do
        if i % 2 == 1 then
            cairo_set_source_rgba(cr, table.unpack(STRIPE_COLOR))
            cairo_rectangle(cr, 12, section.start_y + (i * section.line_height), section.total_width, section.line_height)
            cairo_fill(cr)
        end
    end
end

function conky_draw_pre()
    if conky_window == nil then return end
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
        conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)
    for _, section in ipairs(SECTIONS) do
        draw_stripes(cr, section)
    end
    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

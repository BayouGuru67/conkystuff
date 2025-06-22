require 'cairo'
require 'cairo_xlib'

-- Helper function to draw stripes
local function draw_stripes(cr, start_y, line_height, total_width, stripe_color)
    for i = 0, 9 do
        if i % 2 == 1 then
            cairo_set_source_rgba(cr, stripe_color[1], stripe_color[2], stripe_color[3], stripe_color[4])
            cairo_rectangle(cr, 13, start_y + (i * line_height), total_width, line_height)
            cairo_fill(cr)
        end
    end
end

function conky_draw_pre()
    if conky_window == nil then return end

    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
                 conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)

    local ram_start_y = 33
    local cpu_start_y = 208
    local line_height = 16
    local total_width = 256
    local stripe_color = {0.15, 0.50, 1.00, 0.2}

    draw_stripes(cr, ram_start_y, line_height, total_width, stripe_color)
    draw_stripes(cr, cpu_start_y, line_height, total_width, stripe_color)

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end
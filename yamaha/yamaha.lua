require 'cairo'
require 'cairo_xlib'
local last_update = 0
local update_interval = 10  -- seconds
local yamaha_data = {}

-- Safe command execution
local function execute_command(cmd)
    local handle = io.popen(cmd)
    if not handle then return nil end
    local result = handle:read("*a")
    handle:close()
    return result
end

function conky_yamaha_main()
    if conky_window == nil then return end
    local now = os.time()
    if now - last_update > update_interval then
        yamaha_data = fetch_yamaha_data()
        last_update = now
    end
end

-- [Keep all the fetch/parse functions from previous versions]

function conky_yamaha_display()
    if not yamaha_data.main_zone then
        return "Loading receiver data..."
    end

    -- Apply Conky formatting through concatenation
    local output = {}
    
    -- Header
    table.insert(output, conky_parse("${color4}${font Larabiefont-Regular:bold:size=11}") .. "Yamaha RX-A840 " .. 
                    conky_parse("${voffset -2}${color6}${hr 2}"))

    -- Main Zone Data
    table.insert(output, format_line("Power", yamaha_data.main_zone.Power))
    -- [Add all other lines similarly...]

    return table.concat(output, "\n")
end

function format_line(label, value)
    return conky_parse("${template3}├ ${template1}") .. label .. 
           conky_parse("${goto 125}${color2}${template2}") .. (value or "N/A")
end
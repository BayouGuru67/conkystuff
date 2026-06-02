-- Top Processes Display for Wayland (Conky Text-based)
-- Compatible with all Wayland compositors

-- === CONFIGURATION ===
local COLORS = {
    header  = '${color6}',
    normal  = '${color}',
    warning = '${color4}',
    critical = '${color1}',
    reset   = '${color}',
}

local DISPLAY_LINES = 10  -- Number of processes to show in each section

-- === HELPER FUNCTIONS ===
local function format_memory(mem_kb)
    if mem_kb >= 1000000 then
        return string.format('%6.1f G', mem_kb / 1000000)
    elseif mem_kb >= 1000 then
        return string.format('%6.1f M', mem_kb / 1000)
    else
        return string.format('%6.1f K', mem_kb)
    end
end

local function get_color_for_percentage(pct, warning, critical)
    if pct >= critical then
        return COLORS.critical
    elseif pct >= warning then
        return COLORS.warning
    else
        return COLORS.normal
    end
end

-- === MAIN OUTPUT FUNCTION ===
function conky_top_processes_wayland()
    local output = ''
    
    -- Header
    output = output .. COLORS.header .. '${font Larabiefont:size=11}TOP PROCESSES${font}' .. COLORS.reset .. '\n'
    output = output .. '${hr 2}\n'
    
    -- Memory usage header
    output = output .. COLORS.header .. 'TOP MEMORY CONSUMERS:' .. COLORS.reset .. '\n'
    
    -- Top memory processes
    for i = 1, DISPLAY_LINES do
        local proc_name = conky_parse('${top_mem name ' .. i .. '}')
        local proc_mem = tonumber(conky_parse('${top_mem mem ' .. i .. '}')) or 0
        local proc_pid = conky_parse('${top_mem pid ' .. i .. '}')
        
        if proc_name and proc_name ~= '' then
            output = output .. string.format('%s%-20s %s %s\n',
                COLORS.normal,
                proc_name:sub(1, 20),
                format_memory(tonumber(conky_parse('${top_mem mem_res ' .. i .. '}')) or 0),
                proc_pid
            )
        end
    end
    
    output = output .. '\n'
    
    -- CPU usage header
    output = output .. COLORS.header .. 'TOP CPU CONSUMERS:' .. COLORS.reset .. '\n'
    
    -- Top CPU processes
    for i = 1, DISPLAY_LINES do
        local proc_name = conky_parse('${top name ' .. i .. '}')
        local proc_cpu = tonumber(conky_parse('${top cpu ' .. i .. '}')) or 0
        local proc_pid = conky_parse('${top pid ' .. i .. '}')
        
        if proc_name and proc_name ~= '' then
            local cpu_color = get_color_for_percentage(proc_cpu, 25, 50)
            output = output .. string.format('%s%-20s %s%% %s\n',
                COLORS.normal,
                proc_name:sub(1, 20),
                cpu_color,
                string.format('%6.1f', proc_cpu),
                proc_pid
            )
        end
    end
    
    output = output .. COLORS.reset
    return output
end

-- Alternative compact version (single section)
function conky_top_cpu_processes_wayland()
    local output = ''
    
    output = output .. COLORS.header .. 'Top CPU Processes:' .. COLORS.reset .. '\n'
    
    for i = 1, 5 do
        local proc_name = conky_parse('${top name ' .. i .. '}')
        local proc_cpu = tonumber(conky_parse('${top cpu ' .. i .. '}')) or 0
        
        if proc_name and proc_name ~= '' then
            local cpu_color = get_color_for_percentage(proc_cpu, 25, 50)
            output = output .. string.format('  %s%-18s %s%5.1f%%\n',
                COLORS.normal,
                proc_name:sub(1, 18),
                cpu_color,
                proc_cpu
            )
        end
    end
    
    output = output .. COLORS.reset
    return output
end

function conky_top_mem_processes_wayland()
    local output = ''
    
    output = output .. COLORS.header .. 'Top Memory Processes:' .. COLORS.reset .. '\n'
    
    for i = 1, 5 do
        local proc_name = conky_parse('${top_mem name ' .. i .. '}')
        local proc_mem_pct = tonumber(conky_parse('${top_mem mem_perc ' .. i .. '}')) or 0
        
        if proc_name and proc_name ~= '' then
            local mem_color = get_color_for_percentage(proc_mem_pct, 10, 25)
            output = output .. string.format('  %s%-18s %s%5.1f%%\n',
                COLORS.normal,
                proc_name:sub(1, 18),
                mem_color,
                proc_mem_pct
            )
        end
    end
    
    output = output .. COLORS.reset
    return output
end

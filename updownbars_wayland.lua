-- Network Speed Display for Wayland (Conky Text-based)
-- Compatible with all Wayland compositors

-- === CONFIGURATION ===
local NETWORK_INTERFACE = 'enp7s0'
local MAX_UP_SPEED = 20000      -- kB/s
local MAX_DOWN_SPEED = 100000   -- kB/s

local COLORS = {
    green   = '${color2}',
    yellow  = '${color4}',
    red     = '${color1}',
    reset   = '${color}',
}

-- Connection display limits
local MAX_TOTAL_CONNECTIONS = 25

-- === HELPER FUNCTIONS ===
local function get_up_speed()
    return tonumber(conky_parse('${upspeedf ' .. NETWORK_INTERFACE .. '}')) or 0
end

local function get_down_speed()
    return tonumber(conky_parse('${downspeedf ' .. NETWORK_INTERFACE .. '}')) or 0
end

local function is_connected()
    local ip = conky_parse('${addr ' .. NETWORK_INTERFACE .. '}')
    return (ip and ip ~= '' and ip ~= '0.0.0.0')
end

local function get_color_for_percentage(pct, warning, alarm)
    if pct < warning then
        return COLORS.green
    elseif pct < alarm then
        return COLORS.yellow
    else
        return COLORS.red
    end
end

local function draw_bar(current, max, num_blocks, warning_pct, alarm_pct)
    local pct = math.min(100, math.max(0, (current / max) * 100))
    local lit_blocks = math.floor((num_blocks * pct / 100) + 0.5)
    
    local bar = ''
    for i = 1, num_blocks do
        if i <= lit_blocks then
            local block_threshold = ((i - 1) / num_blocks) * 100
            bar = bar .. get_color_for_percentage(block_threshold, warning_pct, alarm_pct) .. '█'
        else
            bar = bar .. '${color8}░'
        end
    end
    
    return bar .. COLORS.reset
end

local function format_speed(speed_kb)
    if speed_kb >= 1000 then
        return string.format('%6.1f MB/s', speed_kb / 1000)
    else
        return string.format('%6.1f KB/s', speed_kb)
    end
end

local function get_tcp_connections(port_start, port_end)
    local count = tonumber(conky_parse("${tcp_portmon " .. port_start .. " " .. port_end .. " count}")) or 0
    return count
end

-- === MAIN OUTPUT FUNCTION ===
function conky_network_display_wayland()
    local output = ''
    
    if not is_connected() then
        output = output .. '${color1}Network: DISCONNECTED${color}\n'
        return output
    end
    
    -- Title
    output = output .. '${color6}${font Larabiefont:size=11}NETWORK${font}${color}\n'
    output = output .. '${hr 2}\n'
    
    -- Get speeds
    local up_speed = get_up_speed()
    local down_speed = get_down_speed()
    
    -- Upload bar
    output = output .. '${color}Upload:  '
    output = output .. draw_bar(up_speed, MAX_UP_SPEED, 48, 75, 90)
    output = output .. ' ' .. format_speed(up_speed) .. '\n'
    
    -- Download bar
    output = output .. '${color}Download: '
    output = output .. draw_bar(down_speed, MAX_DOWN_SPEED, 48, 75, 90)
    output = output .. ' ' .. format_speed(down_speed) .. '\n'
    
    output = output .. '${hr 2}\n'
    
    -- Connection counts
    local in_conns = get_tcp_connections(1, 32767)
    local out_conns = get_tcp_connections(32768, 61000)
    
    output = output .. string.format('${color}Incoming: %3d connections\n', in_conns)
    output = output .. string.format('${color}Outgoing: %3d connections\n', out_conns)
    output = output .. string.format('${color}Total:    %3d connections\n', in_conns + out_conns)
    
    return output
end

-- Alternative function for minimal display (single line)
function conky_network_status_wayland()
    if not is_connected() then
        return '${color1}✗ Disconnected'
    end
    
    local up = get_up_speed()
    local down = get_down_speed()
    
    return string.format('${color2}↑ %s  ${color2}↓ %s', format_speed(up), format_speed(down))
end

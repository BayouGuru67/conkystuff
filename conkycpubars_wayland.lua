-- CPU Bar Display for Wayland (Conky Text-based)
-- This version uses Conky's text output instead of Cairo drawing
-- Compatible with all Wayland compositors

-- === CONFIGURATION ===
local COLORS = {
    -- Conky color codes (0-9 for template colors)
    green   = '${color2}',
    yellow  = '${color4}',
    red     = '${color1}',
    reset   = '${color}',
}

-- Temperature sensor mappings for your system
local TEMP_SENSORS = {
    gpu_vrm = '${hwmon 4 temp 1}',   -- Gigabyte WMI temp1 (VRM/NB)
    cpu     = '${hwmon 3 temp 1}',   -- k10temp Tctl (CPU)
}

-- Bar configuration: {name, core_id, max_value, num_blocks}
local BAR_CONFIG = {
    {name = 'CPU1',  core = 'cpu1',  max = 100, blocks = 25},
    {name = 'CPU2',  core = 'cpu2',  max = 100, blocks = 25},
    {name = 'CPU3',  core = 'cpu3',  max = 100, blocks = 25},
    {name = 'CPU4',  core = 'cpu4',  max = 100, blocks = 25},
    {name = 'CPU5',  core = 'cpu5',  max = 100, blocks = 25},
    {name = 'CPU6',  core = 'cpu6',  max = 100, blocks = 50},
    {name = 'AVG',   core = 'cpu0',  max = 100, blocks = 50},
}

local GPU_CONFIG = {
    name    = 'GPU',
    cmd     = 'cat /sys/class/drm/card1/device/gpu_busy_percent',
    max     = 100,
    blocks  = 40,
}

-- === HELPER FUNCTIONS ===
local function get_cpu_usage(core_name)
    return tonumber(conky_parse('${cpu ' .. core_name .. '}')) or 0
end

local function get_gpu_usage()
    return tonumber(conky_parse('${exec cat /sys/class/drm/card1/device/gpu_busy_percent}')) or 0
end

local function get_temp(sensor_cmd)
    return tonumber(conky_parse(sensor_cmd)) or 0
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
    
    return bar .. COLORS.reset .. ' ' .. string.format('%3d%%', math.floor(pct + 0.5))
end

local function draw_temp_led(value, green_threshold, red_threshold)
    if value <= green_threshold then
        return '${color2}●'  -- Green LED
    elseif value >= red_threshold then
        return '${color1}●'  -- Red LED
    else
        return '${color4}●'  -- Yellow LED
    end
end

-- === MAIN OUTPUT FUNCTION ===
function conky_cpu_bars_wayland()
    local output = ''
    
    -- Title
    output = output .. '${color6}${font Larabiefont:size=11}CPU CORES${font}${color}\n'
    output = output .. '${hr 2}\n'
    
    -- Individual CPU cores
    for _, config in ipairs(BAR_CONFIG) do
        local usage = get_cpu_usage(config.core)
        output = output .. string.format('${color}%-5s ', config.name)
        output = output .. draw_bar(usage, config.max, config.blocks, 75, 90)
        output = output .. '\n'
    end
    
    output = output .. '${hr 2}\n'
    
    -- GPU Bar
    local gpu_usage = get_gpu_usage()
    output = output .. string.format('${color}%-5s ', GPU_CONFIG.name)
    output = output .. draw_bar(gpu_usage, GPU_CONFIG.max, GPU_CONFIG.blocks, 75, 90)
    output = output .. '\n'
    
    output = output .. '${hr 2}\n'
    
    -- Temperature LEDs
    local gpu_vrm_temp = get_temp(TEMP_SENSORS.gpu_vrm)
    local cpu_temp = get_temp(TEMP_SENSORS.cpu)
    
    output = output .. string.format('${color}GPU VRM: %s ${color}%5.1f°C\n', 
                                      draw_temp_led(gpu_vrm_temp, 140, 155), gpu_vrm_temp)
    output = output .. string.format('${color}CPU:     %s ${color}%5.1f°C\n', 
                                      draw_temp_led(cpu_temp, 175, 190), cpu_temp)
    
    return output
end

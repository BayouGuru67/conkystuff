-- yamaha.lua: Single-call, self-updating for Conky

local last_update = 0
local update_interval = 10 -- seconds
local yamaha_data = {}

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function extract_tag(xml, tag)
    if not xml then return nil end
    local pattern = "<" .. tag .. ">(.-)</" .. tag .. ">"
    local val = xml:match(pattern)
    if val and #val > 0 then return trim(val) else return nil end
end

local function extract_block(xml, tag)
    if not xml then return nil end
    local pattern = "<" .. tag .. ">(.-)</" .. tag .. ">"
    return xml:match(pattern)
end

local function fetch_yamaha_data()
    local yamaha_ip = "192.168.1.106"
    local main_cmd = string.format(
        "curl -s -m 5 'http://%s/YamahaRemoteControl/ctrl' -d '<YAMAHA_AV cmd=\"GET\"><Main_Zone><Basic_Status>GetParam</Basic_Status></Main_Zone></YAMAHA_AV>'",
        yamaha_ip
    )
    local zone2_cmd = string.format(
        "curl -s -m 5 'http://%s/YamahaRemoteControl/ctrl' -d '<YAMAHA_AV cmd=\"GET\"><Zone_2><Basic_Status>GetParam</Basic_Status></Zone_2></YAMAHA_AV>'",
        yamaha_ip
    )

    local main_xml = io.popen(main_cmd):read("*a")
    local zone2_xml = io.popen(zone2_cmd):read("*a")

    local data = { main_zone = {}, zone2 = {} }

    -- Main Zone
    local main_block = extract_block(main_xml, "Basic_Status")
    if main_block then
        data.main_zone.Power         = extract_tag(main_block, "Power") or "N/A"
        data.main_zone.Input_Sel     = extract_tag(main_block, "Input_Sel") or "N/A"
        local title                  = extract_tag(main_block, "Title") or "N/A"
        data.main_zone.Title         = (#title > 22) and (title:sub(1,22) .. "...") or title
        -- Volume
        local vol_block = extract_block(main_block, "Volume")
        local vol_val = extract_tag(vol_block, "Val")
        if vol_val and tonumber(vol_val) then
            data.main_zone.Volume = string.format("%.1f", tonumber(vol_val) / 10)
        else
            data.main_zone.Volume = "N/A"
        end
        data.main_zone.Mute          = extract_tag(main_block, "Mute") or "N/A"
        data.main_zone.Sound_Program = extract_tag(main_block, "Sound_Program") or "N/A"
        data.main_zone.Straight      = extract_tag(main_block, "Straight") or "N/A"
        data.main_zone.Enhancer      = extract_tag(main_block, "Enhancer") or "N/A"
        data.main_zone.OUT_1         = extract_tag(main_block, "OUT_1") or "N/A"
        data.main_zone.OUT_2         = extract_tag(main_block, "OUT_2") or "N/A"
        -- Bass
        local bass_block = extract_block(main_block, "Bass")
        local bass_val = extract_tag(bass_block, "Val")
        if bass_val and tonumber(bass_val) then
            data.main_zone.Bass = string.format("%.1f", tonumber(bass_val) / 10)
        else
            data.main_zone.Bass = "N/A"
        end
        -- Treble
        local treble_block = extract_block(main_block, "Treble")
        local treble_val = extract_tag(treble_block, "Val")
        if treble_val and tonumber(treble_val) then
            data.main_zone.Treble = string.format("%.1f", tonumber(treble_val) / 10)
        else
            data.main_zone.Treble = "N/A"
        end
        data.main_zone.YPAO_Volume   = extract_tag(main_block, "YPAO_Volume") or "N/A"
        data.main_zone.Adaptive_DRC  = extract_tag(main_block, "Adaptive_DRC") or "N/A"
        data.main_zone.Dialogue_Lvl  = extract_tag(main_block, "Dialogue_Lvl") or "N/A"
        data.main_zone.Dialogue_Lift = extract_tag(main_block, "Dialogue_Lift") or "N/A"
    end

    -- Zone 2
    local z2_block = extract_block(zone2_xml, "Basic_Status")
    if z2_block then
        data.zone2.Power        = extract_tag(z2_block, "Power") or "N/A"
        data.zone2.Input_Sel    = extract_tag(z2_block, "Input_Sel") or "N/A"
        local z2_title          = extract_tag(z2_block, "Title") or "N/A"
        data.zone2.Title        = (#z2_title > 22) and (z2_title:sub(1,22) .. "...") or z2_title
        local z2_vol_val        = extract_tag(z2_block, "Val")
        if z2_vol_val and tonumber(z2_vol_val) then
            data.zone2.Volume = string.format("%.1f", tonumber(z2_vol_val) / 10)
        else
            data.zone2.Volume = "N/A"
        end
        data.zone2.Mute         = extract_tag(z2_block, "Mute") or "N/A"
    end

    return data
end

local function format_line(label, value)
    return string.format("${template3}├ ${template1}%s${goto 125}${color2}${template2}%s", label, value or "N/A")
end

function conky_yamaha_display()
    local now = os.time()
    if now - last_update > update_interval or not yamaha_data.main_zone then
        yamaha_data = fetch_yamaha_data()
        last_update = now
    end

    if not yamaha_data.main_zone or not yamaha_data.zone2 then
        return "Loading receiver data..."
    end

    local out = {}

    -- Header
    table.insert(out, "${color4}${font Larabiefont-Regular:bold:size=11}Yamaha RX-A840 ${voffset -2}${color6}${hr 2}")

    -- Main Zone
    table.insert(out, format_line("Power",          yamaha_data.main_zone.Power))
    table.insert(out, format_line("Input",          yamaha_data.main_zone.Input_Sel .. " - " .. yamaha_data.main_zone.Title))
    table.insert(out, format_line("Volume",         yamaha_data.main_zone.Volume .. " dB"))
    table.insert(out, format_line("Mute",           yamaha_data.main_zone.Mute))
    table.insert(out, format_line("Program",        yamaha_data.main_zone.Sound_Program))
    table.insert(out, format_line("Pure Direct",    yamaha_data.main_zone.Straight))
    table.insert(out, format_line("Enhancer",       yamaha_data.main_zone.Enhancer))
    table.insert(out, format_line("HDMI Out 1",     yamaha_data.main_zone.OUT_1))
    table.insert(out, format_line("HDMI Out 2",     yamaha_data.main_zone.OUT_2))
    table.insert(out, format_line("Bass",           yamaha_data.main_zone.Bass .. " dB"))
    table.insert(out, format_line("Treble",         yamaha_data.main_zone.Treble .. " dB"))
    table.insert(out, format_line("YPAO Volume",    yamaha_data.main_zone.YPAO_Volume))
    table.insert(out, format_line("DRC",            yamaha_data.main_zone.Adaptive_DRC))
    table.insert(out, format_line("Dialog Level",   yamaha_data.main_zone.Dialogue_Lvl))
    table.insert(out, "${template3}└ ${template1}Dialog Lift${goto 125}${color2}${template2}" .. (yamaha_data.main_zone.Dialogue_Lift or "N/A"))

    -- Zone 2 header
    table.insert(out, "${color4}${font Larabiefont-Regular:bold:size=11}Zone 2 ${color6}${hr 2}")
    table.insert(out, format_line("Power",      yamaha_data.zone2.Power))
    table.insert(out, format_line("Input",      yamaha_data.zone2.Input_Sel))
    table.insert(out, format_line("Title",      yamaha_data.zone2.Title))
    table.insert(out, format_line("Volume",     yamaha_data.zone2.Volume .. " dB"))
    table.insert(out, "${template3}└ ${template1}Mute${goto 125}${color2}${template2}" .. (yamaha_data.zone2.Mute or "N/A"))

    return table.concat(out, "\n")
end
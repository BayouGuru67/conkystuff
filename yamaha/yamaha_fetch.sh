#!/bin/bash

# Fetch XML data from Yamaha receiver with a 5-second timeout
raw_xml_data=$(curl -s -m 5 "http://192.168.1.106/YamahaRemoteControl/ctrl" \
  -d '<YAMAHA_AV cmd="GET"><Main_Zone><Basic_Status>GetParam</Basic_Status></Main_Zone></YAMAHA_AV>')

# Check if curl command was successful and got any data
if [ -z "$raw_xml_data" ]; then
  # If curl failed, output N/A for all expected lines
  for ((i=1; i<=16; i++)); do echo "N/A"; done
  exit 0
fi

# Extract the content OF <Basic_Status> as all relevant tags are within it.
# This is the primary block of XML we will parse.
basic_status_content=$(echo "$raw_xml_data" | sed -n 's#.*<Basic_Status>\(.*\)</Basic_Status>.*#\1#p')

# If Basic_Status content is not found (e.g. malformed XML), output N/A for all lines.
if [ -z "$basic_status_content" ]; then
  for ((i=1; i<=16; i++)); do echo "N/A"; done
  exit 0
fi

# Function to extract content of a simple XML tag from a given xml string
# Usage: extract_simple_tag "$xml_string_to_search" "TagName"
extract_simple_tag() {
  local xml_input="$1"
  local tag_name="$2"
  local default_value="N/A"

  if [[ "$xml_input" == "N/A" || -z "$xml_input" ]]; then # Check if input XML itself is N/A or empty
      echo "$default_value"
      return
  fi
  # Using a unique delimiter for sed: #
  local value=$(echo "$xml_input" | sed -n "s#.*<$tag_name>\(.*\)</$tag_name>.*#\1#p")
  
  if [ -z "$value" ]; then
    echo "$default_value"
  else
    echo "$value"
  fi
}

# --- Specific getter functions based on your provided XML structure ---

get_power() {
    local power_control_xml=$(extract_simple_tag "$basic_status_content" "Power_Control")
    extract_simple_tag "$power_control_xml" "Power"
}
get_input_sel() {
    local input_xml=$(extract_simple_tag "$basic_status_content" "Input")
    extract_simple_tag "$input_xml" "Input_Sel"
}
get_input_title() {
    local input_xml=$(extract_simple_tag "$basic_status_content" "Input")
    local item_info_xml=$(extract_simple_tag "$input_xml" "Input_Sel_Item_Info")
    extract_simple_tag "$item_info_xml" "Title"
}
get_volume_val_raw() {
    local volume_xml=$(extract_simple_tag "$basic_status_content" "Volume")
    local lvl_xml=$(extract_simple_tag "$volume_xml" "Lvl")
    extract_simple_tag "$lvl_xml" "Val" # This gets -525 from your example
}
get_mute() {
    local volume_xml=$(extract_simple_tag "$basic_status_content" "Volume")
    extract_simple_tag "$volume_xml" "Mute"
}
get_sound_program() {
    local surround_xml=$(extract_simple_tag "$basic_status_content" "Surround")
    local prog_sel_xml=$(extract_simple_tag "$surround_xml" "Program_Sel")
    local current_xml=$(extract_simple_tag "$prog_sel_xml" "Current")
    extract_simple_tag "$current_xml" "Sound_Program"
}
get_straight() {
    local surround_xml=$(extract_simple_tag "$basic_status_content" "Surround")
    local prog_sel_xml=$(extract_simple_tag "$surround_xml" "Program_Sel")
    local current_xml=$(extract_simple_tag "$prog_sel_xml" "Current")
    extract_simple_tag "$current_xml" "Straight"
}
get_enhancer() {
    local surround_xml=$(extract_simple_tag "$basic_status_content" "Surround")
    local prog_sel_xml=$(extract_simple_tag "$surround_xml" "Program_Sel")
    local current_xml=$(extract_simple_tag "$prog_sel_xml" "Current")
    extract_simple_tag "$current_xml" "Enhancer"
}
get_hdmi_out_1() {
    local sound_video_xml=$(extract_simple_tag "$basic_status_content" "Sound_Video")
    local hdmi_xml=$(extract_simple_tag "$sound_video_xml" "HDMI")
    local output_xml=$(extract_simple_tag "$hdmi_xml" "Output")
    extract_simple_tag "$output_xml" "OUT_1"
}
get_hdmi_out_2() {
    local sound_video_xml=$(extract_simple_tag "$basic_status_content" "Sound_Video")
    local hdmi_xml=$(extract_simple_tag "$sound_video_xml" "HDMI")
    local output_xml=$(extract_simple_tag "$hdmi_xml" "Output")
    extract_simple_tag "$output_xml" "OUT_2"
}
get_bass_val_raw() {
    local sound_video_xml=$(extract_simple_tag "$basic_status_content" "Sound_Video")
    local tone_xml=$(extract_simple_tag "$sound_video_xml" "Tone")
    local bass_xml=$(extract_simple_tag "$tone_xml" "Bass")
    extract_simple_tag "$bass_xml" "Val" # Gets 0 from your example
}
get_treble_val_raw() {
    local sound_video_xml=$(extract_simple_tag "$basic_status_content" "Sound_Video")
    local tone_xml=$(extract_simple_tag "$sound_video_xml" "Tone")
    local treble_xml=$(extract_simple_tag "$tone_xml" "Treble")
    extract_simple_tag "$treble_xml" "Val" # Gets 0 from your example
}
get_ypao_volume() {
    local sound_video_xml=$(extract_simple_tag "$basic_status_content" "Sound_Video")
    extract_simple_tag "$sound_video_xml" "YPAO_Volume"
}
get_adaptive_drc() {
    local sound_video_xml=$(extract_simple_tag "$basic_status_content" "Sound_Video")
    extract_simple_tag "$sound_video_xml" "Adaptive_DRC"
}
get_dialog_lvl() {
    local sound_video_xml=$(extract_simple_tag "$basic_status_content" "Sound_Video")
    local dia_adj_xml=$(extract_simple_tag "$sound_video_xml" "Dialogue_Adjust")
    extract_simple_tag "$dia_adj_xml" "Dialogue_Lvl"
}
get_dialog_lift() {
    local sound_video_xml=$(extract_simple_tag "$basic_status_content" "Sound_Video")
    local dia_adj_xml=$(extract_simple_tag "$sound_video_xml" "Dialogue_Adjust")
    extract_simple_tag "$dia_adj_xml" "Dialogue_Lift"
}

# --- Output each value on a new line, applying processing ---

# Line 1: Power
echo "$(get_power)"

# Line 2: Input
current_input=$(get_input_sel)
echo "$current_input"

# Line 3: Title
input_title_raw=$(get_input_title)
max_title_length=22 
if [[ "$input_title_raw" != "N/A" && "${#input_title_raw}" -gt "$max_title_length" ]]; then
    input_title_processed="$(echo "$input_title_raw" | cut -c1-"$max_title_length")..."
else
    input_title_processed="$input_title_raw"
fi
echo "$input_title_processed"

# Line 4: Volume (e.g., -525 means -52.5 dB)
volume_raw_val=$(get_volume_val_raw)
if [[ "$volume_raw_val" != "N/A" && -n "$volume_raw_val" && "$volume_raw_val" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
  printf "%.1f\n" "$(bc -l <<< "$volume_raw_val / 10")"
else
  echo "N/A"
fi

# Line 5: Mute
echo "$(get_mute)"
# Line 6: Program
echo "$(get_sound_program)"
# Line 7: Straight
echo "$(get_straight)"
# Line 8: Enhancer
echo "$(get_enhancer)"
# Line 9: HDMI OUT 1
echo "$(get_hdmi_out_1)"
# Line 10: HDMI OUT 2
echo "$(get_hdmi_out_2)"

# Line 11: Bass (e.g., 0 means 0.0 dB)
bass_raw_val=$(get_bass_val_raw)
if [[ "$bass_raw_val" != "N/A" && -n "$bass_raw_val" && "$bass_raw_val" =~ ^-?[0-9]+$ ]]; then
  printf "%.1f\n" "$(bc -l <<< "$bass_raw_val / 10")"
else
  echo "N/A"
fi

# Line 12: Treble (e.g., 0 means 0.0 dB)
treble_raw_val=$(get_treble_val_raw)
if [[ "$treble_raw_val" != "N/A" && -n "$treble_raw_val" && "$treble_raw_val" =~ ^-?[0-9]+$ ]]; then
  printf "%.1f\n" "$(bc -l <<< "$treble_raw_val / 10")"
else
  echo "N/A"
fi

# Line 13: YPAO Volume
echo "$(get_ypao_volume)"
# Line 14: DRC
echo "$(get_adaptive_drc)"

# Line 15: Dialog Level
dialog_lvl_raw=$(get_dialog_lvl)
if [[ "$dialog_lvl_raw" != "N/A" && "$dialog_lvl_raw" =~ ^-?[0-9]+$ ]]; then
    echo "$dialog_lvl_raw"
else
    echo "N/A"
fi

# Line 16: Dialog Lift
dialog_lift_raw=$(get_dialog_lift)
if [[ "$dialog_lift_raw" != "N/A" && "$dialog_lift_raw" =~ ^-?[0-9]+$ ]]; then
    echo "$dialog_lift_raw"
else
    echo "N/A"
fi
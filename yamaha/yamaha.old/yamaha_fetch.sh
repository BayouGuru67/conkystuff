#!/bin/bash

# Fetch Main Zone XML data (single line)
raw_xml_data=$(curl -s -m 5 "http://192.168.1.106/YamahaRemoteControl/ctrl" \
  -d '<YAMAHA_AV cmd="GET"><Main_Zone><Basic_Status>GetParam</Basic_Status></Main_Zone></YAMAHA_AV>' | tr -d '\n')

# Fetch Zone 2 XML data (single line)
zone2_raw_xml_data=$(curl -s -m 5 "http://192.168.1.106/YamahaRemoteControl/ctrl" \
  -d '<YAMAHA_AV cmd="GET"><Zone_2><Basic_Status>GetParam</Basic_Status></Zone_2></YAMAHA_AV>' | tr -d '\n')

# Extract the content of <Basic_Status> for Main Zone and Zone 2
extract_block() {
  # $1: input XML, $2: tag name (without brackets)
  echo "$1" | sed -n "s/.*<$2>\(.*\)<\/$2>.*/\1/p"
}

basic_status_content=$(extract_block "$raw_xml_data" "Basic_Status")
zone2_basic_status_content=$(extract_block "$zone2_raw_xml_data" "Basic_Status")

# Robust function to extract just the value between <tag> and </tag>
extract_simple_tag() {
  # $1: XML string, $2: Tag name
  local result
  result=$(echo "$1" | sed -n "s/.*<$2>\(.*\)<\/$2>.*/\1/p" | head -n1)
  if [ -z "$result" ]; then
    echo "N/A"
  else
    echo "$result"
  fi
}

# Output N/A if either block is missing
if [ -z "$basic_status_content" ]; then
  for ((i=1;i<=16;i++)); do echo "N/A"; done
else
  # Main Zone
  echo "$(extract_simple_tag "$basic_status_content" "Power")"        # 1 Power
  echo "$(extract_simple_tag "$basic_status_content" "Input_Sel")"    # 2 Input

  input_title_raw=$(extract_simple_tag "$basic_status_content" "Title")
  max_title_length=22
  if [[ "$input_title_raw" != "N/A" && "${#input_title_raw}" -gt "$max_title_length" ]]; then
    input_title_processed="$(echo "$input_title_raw" | cut -c1-"$max_title_length")..."
  else
    input_title_processed="$input_title_raw"
  fi
  echo "$input_title_processed"                                       # 3 Title

# Extract just the <Volume> block from Basic_Status (first occurrence, non-greedy)
volume_block=$(echo "$basic_status_content" | grep -o '<Volume>.*</Volume>' | head -n1)
volume_raw_val=$(echo "$volume_block" | grep -o '<Val>[^<]*</Val>' | head -n1 | sed -e 's/<[^>]*>//g')

if [[ "$volume_raw_val" != "N/A" && -n "$volume_raw_val" && "$volume_raw_val" =~ ^-?[0-9]+$ ]]; then
  printf "%.1f\n" "$(bc -l <<< "$volume_raw_val / 10")"
else
  echo "N/A"
fi
  echo "$(extract_simple_tag "$basic_status_content" "Mute")"         # 5 Mute
  echo "$(extract_simple_tag "$basic_status_content" "Sound_Program")" # 6 Program
  echo "$(extract_simple_tag "$basic_status_content" "Straight")"     # 7 Straight
  echo "$(extract_simple_tag "$basic_status_content" "Enhancer")"     # 8 Enhancer
  echo "$(extract_simple_tag "$basic_status_content" "OUT_1")"        # 9 HDMI OUT 1
  echo "$(extract_simple_tag "$basic_status_content" "OUT_2")"        # 10 HDMI OUT 2

  bass_section=$(echo "$basic_status_content" | grep -o "<Bass>.*</Bass>")
  bass_val=$(echo "$bass_section" | sed -n "s/.*<Val>\(.*\)<\/Val>.*/\1/p")
  if [[ "$bass_val" != "" && "$bass_val" != "N/A" ]]; then
    printf "%.1f\n" "$(bc -l <<< "$bass_val / 10")"
  else
    echo "N/A"
  fi                                                                  # 11 Bass

  treble_section=$(echo "$basic_status_content" | grep -o "<Treble>.*</Treble>")
  treble_val=$(echo "$treble_section" | sed -n "s/.*<Val>\(.*\)<\/Val>.*/\1/p")
  if [[ "$treble_val" != "" && "$treble_val" != "N/A" ]]; then
    printf "%.1f\n" "$(bc -l <<< "$treble_val / 10")"
  else
    echo "N/A"
  fi                                                                  # 12 Treble

  echo "$(extract_simple_tag "$basic_status_content" "YPAO_Volume")"  # 13 YPAO Volume
  echo "$(extract_simple_tag "$basic_status_content" "Adaptive_DRC")" # 14 DRC
  echo "$(extract_simple_tag "$basic_status_content" "Dialogue_Lvl")" # 15 Dialog Level
  echo "$(extract_simple_tag "$basic_status_content" "Dialogue_Lift")" # 16 Dialog Lift
fi

if [ -z "$zone2_basic_status_content" ]; then
  for ((i=1;i<=5;i++)); do echo "N/A"; done
else
  echo "$(extract_simple_tag "$zone2_basic_status_content" "Power")"       # 17 Zone2 Power
  echo "$(extract_simple_tag "$zone2_basic_status_content" "Input_Sel")"   # 18 Zone2 Input

  z2_input_title_raw=$(extract_simple_tag "$zone2_basic_status_content" "Title")
  max_title_length=22
  if [[ "$z2_input_title_raw" != "N/A" && "${#z2_input_title_raw}" -gt "$max_title_length" ]]; then
    z2_input_title_processed="$(echo "$z2_input_title_raw" | cut -c1-"$max_title_length")..."
  else
    z2_input_title_processed="$z2_input_title_raw"
  fi
  echo "$z2_input_title_processed"                                         # 19 Zone2 Title

  z2_volume_raw_val=$(extract_simple_tag "$zone2_basic_status_content" "Val")
  if [[ "$z2_volume_raw_val" != "N/A" && -n "$z2_volume_raw_val" && "$z2_volume_raw_val" =~ ^-?[0-9]+$ ]]; then
    printf "%.1f\n" "$(bc -l <<< "$z2_volume_raw_val / 10")"
  else
    echo "N/A"
  fi                                                                      # 20 Zone2 Volume

  echo "$(extract_simple_tag "$zone2_basic_status_content" "Mute")"       # 21 Zone2 Mute
fi

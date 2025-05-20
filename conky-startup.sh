#!/bin/bash

CONKY=/usr/bin/conky

# Optional: Wait a moment after boot
sleep 2

# Function to start Conky and wait for its window to appear
start_conky_and_wait() {
    conf_file="$1"
    window_title="$2"

    $CONKY -dc "$conf_file" &

    # Wait for the window to appear (up to 10 seconds max)
    for i in {1..100}; do
        if xdotool search --name "$window_title" >/dev/null 2>&1; then
            break
        fi
        sleep 0.1
    done
}

# Start CPU Conky
start_conky_and_wait "/home/bayouguru/.conky/l-conky-cpu.conf" "CPU-Conky"

# Start Network Conky
start_conky_and_wait "/home/bayouguru/.conky/rightconky.conf" "Net-Conky"

# Start System Info Conky
start_conky_and_wait "/home/bayouguru/.conky/l-conky-sysinfo.conf" "SysInfo-Conky"

# Start Animated Fan Conky
start_conky_and_wait "/home/bayouguru/.conky/anifan.conf" "Fan-Conky"

# Wait for background processes to finish (not strictly needed)
wait

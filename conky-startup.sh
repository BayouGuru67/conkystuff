#!/bin/bash

CONKY=/usr/bin/conky
# Wait a bit for things to calm down at boot-up.
sleep 3
# Start the CPU Conky with a small delay
conky -dc "/home/bayouguru/.conky/l-conky-cpu.conf" &
sleep 1
# Start the Network Conky with a small delay
conky -dc "/home/bayouguru/.conky/rightconky.conf" &
sleep 10
# Start the System Info Conky last because it takes the longest
conky -dc "/home/bayouguru/.conky/l-conky-sysinfo.conf" &
# Wait for all scripts to complete
wait

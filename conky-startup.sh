#!/bin/bash

CONKY=/usr/bin/conky

# Wait a bit for things to calm down at boot-up.
sleep 5

# Start the CPU Conky with a small delay
/usr/bin/conky -dc "/home/bayouguru/.conky/l-conky-cpu.conf" &
sleep 5

# Start the Network Conky with a small delay
/usr/bin/conky -dc "/home/bayouguru/.conky/rightconky.conf" &
sleep 5

# Start the System Info Conky last because it takes 13 seconds!
/usr/bin/conky -dc "/home/bayouguru/.conky/l-conky-sysinfo.conf" &

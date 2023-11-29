#! /bin/bash
# Run the smartctl command and capture the output in a variable
smartctlb_output=$(/usr/sbin/smartctl -a /dev/sdb | grep "overall-health" | awk '{print "\""$NF"\""}')
# Check if the output is PASSED and display the appropriate image
if [ "$smartctlb_output" == "\"PASSED\"" ]; then
    echo "\${image /home/bayouguru/.conky/images/green.png  -p 4,710 -s 16x16}"
else
    echo "\${image /home/bayouguru/.conky/images/red.png  -p 4,710 -s 16x16}"
fi

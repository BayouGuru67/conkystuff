#! /bin/bash
# Run the smartctl command and capture the output in a variable
smartctla_output=$(/usr/sbin/smartctl -a /dev/sda | grep "overall-health" | awk '{print "\""$NF"\""}')
# Check if the output is PASSED and display the appropriate image
if [ "$smartctla_output" == "\"PASSED\"" ]; then
    echo "\${image /home/bayouguru/.conky/images/green.png -p 4,636 -s 16x16 } "
else
    echo "\${image /home/bayouguru/.conky/images/red.png -p 4,636 -s 16x16 } "
fi

#!/bin/bash
sleep 5
/usr/bin/conky -d -c "/home/bayouguru/.conky/l-conky-clock.conf" &
/usr/bin/conky -d -c "/home/bayouguru/.conky/l-conky-cpu.conf" &
/usr/bin/conky -d -c "/home/bayouguru/.conky/l-conky-sysinfo.conf" &
/usr/bin/conky -d -c "/home/bayouguru/.conky/rightconky.conf" &

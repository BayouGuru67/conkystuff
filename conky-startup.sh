#!/bin/sh

CONKY=/usr/bin/conky

for f in $HOME/.conky/*.conf;
do
  $CONKY -dc $f
  sleep 2s
done
#sleep 3
#/usr/bin/conky -dc "/home/bayouguru/.conky/l-conky-clock.conf" &&
#/usr/bin/conky -dc "/home/bayouguru/.conky/l-conky-cpu.conf" &&
#/usr/bin/conky -dc "/home/bayouguru/.conky/l-conky-sysinfo.conf" &&
#/usr/bin/conky -dc "/home/bayouguru/.conky/rightconky.conf"


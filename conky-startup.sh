#!/bin/sh

CONKY=/usr/bin/conky

  sleep 5s
/usr/bin/conky -dc "/home/bayouguru/.conky/l-conky-cpu.conf" &
/usr/bin/conky -dc "/home/bayouguru/.conky/rightconky.conf"&
  sleep 7s
/usr/bin/conky -dc "/home/bayouguru/.conky/l-conky-sysinfo.conf" &

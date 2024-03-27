#!/bin/sh

if [ "$DESKTOP_SESSION" = "plasma" ]; then 
   killall conky
   sleep 5s
   conky -d -c "/home/bayouguru/.conky/conky.conf" &
   conky -d -c "/home/bayouguru/.conky/rightconky.conf" &
   exit 0
fi

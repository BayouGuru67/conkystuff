#!/bin/sh

if [ "$DESKTOP_SESSION" = "plasma" ]; then 
   killall conky-x86_64.appImage
   sleep 5s
   cd "$HOME"/Applications || exit
   conky -d -c "/home/bayouguru/.conky/conky.conf" &
   conky -d -c "/home/bayouguru/.conky/rightconky.conf" &
   conky -d -c "/home/bayouguru/.conky/weatherconky.conf" &
   exit 0
fi

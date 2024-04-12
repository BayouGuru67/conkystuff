#!/bin/env bash
if [ "$DESKTOP_SESSION" = "plasma" ]; then 
sleep 3s
./conky -dc "/home/bayouguru/.conky/conky.conf" &
./conky -dc "/home/bayouguru/.conky/rightconky.conf" &
exit 0
fi

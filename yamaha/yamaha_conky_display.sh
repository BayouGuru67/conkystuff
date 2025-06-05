#!/bin/bash

# Fetch data from your Yamaha receiver
yamaha_data=($(~/.conky/yamaha/yamaha_fetch.sh))

# Output formatted Conky text
cat <<EOF
\${color4}\${font Larabiefont-Regular:bold:size=11}Yamaha RX-A840 \${voffset -2}\${color6}\${hr 2}
\${template3}├ \${template1}Power\${goto 125}\${color2}\${template2}${yamaha_data[0]}
\${template3}├ \${template1}Input\${goto 125}\${color2}\${template2}${yamaha_data[1]}
\${template3}├ \${template1}Title\${goto 125}\${color2}\${template2}${yamaha_data[2]}
\${template3}├ \${template1}Volume\${goto 125}\${color2}\${template2}${yamaha_data[3]} dB
\${template3}├ \${template1}Mute\${goto 125}\${color2}\${template2}${yamaha_data[4]}
\${template3}├ \${template1}Program\${goto 125}\${color2}\${template2}${yamaha_data[5]}
\${template3}├ \${template1}Straight\${goto 125}\${color2}\${template2}${yamaha_data[6]}
\${template3}├ \${template1}Enhancer\${goto 125}\${color2}\${template2}${yamaha_data[7]}
\${template3}├ \${template1}HDMI OUT 1\${goto 125}\${color2}\${template2}${yamaha_data[8]}
\${template3}├ \${template1}HDMI OUT 2\${goto 125}\${color2}\${template2}${yamaha_data[9]}
\${template3}├ \${template1}Bass\${goto 125}\${color2}\${template2}${yamaha_data[10]} dB
\${template3}├ \${template1}Treble\${goto 125}\${color2}\${template2}${yamaha_data[11]} dB
\${template3}├ \${template1}YPAO Volume\${goto 125}\${color2}\${template2}${yamaha_data[12]}
\${template3}├ \${template1}DRC\${goto 125}\${color2}\${template2}${yamaha_data[13]}
\${template3}├ \${template1}Dialog Level\${goto 125}\${color2}\${template2}${yamaha_data[14]}
\${template3}└ \${template1}Dialog Lift\${goto 125}\${color2}\${template2}${yamaha_data[15]}
\${color4}\${font Larabiefont-Regular:bold:size=11}Zone 2 \${color6}\${hr 2}
\${template3}├ \${template1}Power\${goto 125}\${color2}\${template2}${yamaha_data[16]}
\${template3}├ \${template1}Input\${goto 125}\${color2}\${template2}${yamaha_data[17]}
\${template3}├ \${template1}Title\${goto 125}\${color2}\${template2}${yamaha_data[18]}
\${template3}├ \${template1}Volume\${goto 125}\${color2}\${template2}${yamaha_data[19]} dB
\${template3}└ \${template1}Mute\${goto 125}\${color2}\${template2}${yamaha_data[20]}EOF

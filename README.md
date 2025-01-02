# conkystuff
BayouGuru's online conky repository

This repository contains all of the currently active conkys on BayouGuru's main system.  There are 4 conkys and 3 lua scripts, named as follows:

"l-conky-clock.conf" - The clock conky at the left-top of the screen. *DEVELOPMENT DISCONTINUED* I have a perfectly good clock in the tray.  Why duplicfate the effort?

"l-conky-cpu.conf" - The CPU section conky.

"l-conky-sysinfo.conf" - The System Informaton conky.

"conkycpubars.lua" - The Lua script which is responsible for rendering the cool looking segmented LED bars in the CPU conky.  You will need to edit this file as-needed for the particulars of your hardware setup.

"sysbars.lua" - The Lua script which is responsible for rendering the cool looking segmented LED bars in the Sytem Information conky.  You will need to edit this file as-needed for the particulars of your hardware setup.  This also draws the round "LED indictors", and the threshold data is located in the table at the end of the lua.

"updownbars.lua" - The Lua script which is responsible for rendering the cool looking segmented LED bars in the Network (right) conky.  You will need to edit this file as-needed for the particulars of your hardware setup.

  Credit for the Lua scripts goes to Reddit user u/DareBoy58 who shared his version of the script which ChatGPT and I edited heavily to suit our purposes and get it working on my installation.  Bear in mind that you MUST be running a conky-all or conky-lua build with the Lua extensions enabled in order to use this script! Credit for the lua scripts also goes to ChatGPT, which has been heavily-relied-upon to make this code as simple and efficient as possible.

"rightconky.conf" - The right-top/side conky, which displays the system's network information, the top 5 processes using CPU and RAM and up to 6 inbound and/or up to 18 outbound network connections (minus the number of inbound connections) are shown. It also features the lua LED upload and download bars to show bandwidth usage.  I think the only thing necessary to edit in this config if you are going to leech it is the network adapter name.  The search string to replace with your adapter's name is "enp6s0", which appears 6 times in the config.  The size and total number of connections can be expanded to suit higher resolution displays simply by extending the logical structure of the bottom section which contains the code that lists the connections.  By doing this, you could make it show more incoming and/or more outbound connections on monitors with more real estate to play with, such as 2k, 4k and 8k displays.  In pont of fact, if you don't mind taskbar occlusion, you could add 2 more connections to the 1080 display before running out of vertical space, but I wanted to keep it clear of the taskbar, even if the conky's background is going "full-screen" vertically.  The DE's taskbar displays over the bottom of the conky, not under, but it doesn't hurt anything.  I found it annoying/distracting to see the flicker of the redraw when resizing the conky for fewer connections, so setting the minimum height for 1076 pixelsseems to eliminate all those problems.

These conky configurations are posted here for you to modify and use as you please.  I make no warranty as to their functionality on any system other than my own, as it is a certainty that you WILL need to edit these configurations in order to tailor them to the particulars of your system.  This is especially true of the temerature data, which can change locations simply by connecting another device to your system.  These conkys are the result of months of very intense work refining and tweaking the configurations to fit my use-case.  If you find it useful, then I am glad.  If you have questions, please feel free to ask me!

NOTE:  As of March 2024, the weather conky/script has been discontinued due to the presence of better weather apps for my Kubuntu desktop and the seemingly constantly-changing nature of the interface/API's of the weather information providers.  The hard drive smart status scripts have been discontinued due to the hard drive light blinking every second being annoying at night and it would likely interfere with drive life and/or power savings.  The ipv6 script is no longer needed, as the command is now integrated into rightconky.conf.  This is how my scripts evolve, and they will continue to do so, though at a more leisurely pace, as I am pretty happy with them.  :)

# conkystuff
BayouGuru's online conky repository

This repository contains all of the currently active conkys on BayouGuru's main system.  There are two conkys and a lua script, named as follows:

"conky.conf" - The main conky, which displays the main system information such as the temperatures, disk space usage, cpu & ram usage and resides at the left-top of the screen, 

"conkybars.lua" - The Lua script which is responsible for rendering the cool looking segmented LED bars in the left conky.  You will need to edit this file as-needed for the particulars of your hardware setup.
I recommend only editing the lower section of the file where the bars are actually created.  Credit for this script goes to Reddit user u/DareBoy58 who shared his version of the script which ChatGPT and I edited heavily to suit our purposes and get it working on my installation.  Bear in mind that you MUST be running a conky-all or conky-lua build with the Lua extensions enabled in order to use this script! 

"rightconky.conf" - The right-top conky, which displays the system's  network information, the top 5 users of CPU and ram, up to 6 inbound and up to 12 outbound network connections, reszing as-needed.

"updownbars.lua" - The right conky uses lua to make the really cool looking segmented bars above and below the network icon showing the upload and download loads.  You will need to edit this script as-appropriate for your system, as it contains the information for my particular network setup and screen size (1080p).        

These conky configurations are posted here for you to modify and use as you please.  I make no warranty as to their functionality on any system other than my own, as it is a certainty that you WILL need to edit these configurations in order to tailor them to the particulars of your system.  This is especially true of the temerature data, which can change locations simply by connecting another device to your system.  These conkys are the result of months of very intense work refining and tweaking the configurations to fit my use-case.  If you find it useful, then I am glad.  If you have questions, please feel free to ask me!

NOTE:  As of March 2024, the weather conky/script has been discontinued due to the presence of better weather apps for my Kubuntu desktop and the seemingly constantly-changing nature of the interface/API's of the weather information providers.  The hard drive smart status scripts have been discontinued due to the hard drive light blinking every second being annoying at night and it would likely interfere with drive life and/or power savings.  The ipv6 script is no longer needed, as the command is now integrated into rightconky.conf.  This is how my scripts evolve, and they will continue to do so, though at a more leisurely pace, as I am pretty happy with them.  :)

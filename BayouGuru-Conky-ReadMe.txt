BayouGuru's Conky ReadMe!
Version 2025-5-20.1009

This ReadMe is for the conky collection created a bit at a time as inspiration 
or necessity struck for the machine known as "bg-l-box", property of 
BayouGuru, running at 1080p on a 55" LG television that's hung on the wall.
We sit about 12' away from it.  It's possible to run this TV at higher 
resolutions such as 2K and 4K, but it makes everything too small to see for us
and it would only be supported at 30fps instead of 60fps.

It's basically an HTPC setup, therefore, the font sizes are probably going to 
be a bit large for some of you.  I really do hope you enjoy the editing process
to make these scripts work on your system as much as I have enjoyed their 
creation process! These scripts all work with the latest version of conky as of
April, 2023.

This is the online archive/backup of the configurations as they exist and are
currently in-use on my machine.  That machine was built using a 6-Core AMD
CPU with an AMD RX580 GPU, all connected to an ASUS 990FX Mainboard with 24Gb
of 1600MHz SDRAM.  Please bear in mind that the sensor data will probably not
be correct for your system and you will need to research the appropriate sensor
information for your mainboard and components.  As a starter, I would suggest
searching for "<your mainboard make and model> sensor linux" and seeing what
information you can find that correlates to the output of "sensors" in your
terminal.  Bear in mind also that in order for sensors to work, you must first
install "lm-sensors" and run "sudo sensors-detect".  Even after that, you may
find additional sensor outputs like I did by searching your system for "hwmon" 
as that is how I found my case fan rpm, which doesn't show up in sensors for 
some unknown reason, neither before or after installing the mainboard sensor 
template that converts the raw sensors output to each sensors more human-
readable format. It also helped a lot to install "psensor" and "radeon-
profile", the latter being used to control the GPU fan speeds on my AMD RX580.

The average observed CPU usage to run these conkys on this system is now .5% to
.8% for all of the conkys!  

    All of the files are in the ~/.conky/ directory or
    subfolders therein, with the sole exception of the conky executable.
    BE SURE to replicate this directory structure, and edit the configuration
    files appropriately by replacing "bayouguru" with the appropriate value for
    your system.
        
        ~/.conky/l-conky-cpu.conf -
        The conky's configuration file displays the CPU and GPU
        info.

        ~/.conky/l-conky-sysinfo.conf - 
        This is the lower portion of the system information conky which displays
        the temperature, uptime, disk as well as the top memory and cpu users and
        much more.

        ~/.conky/anifan.conf - 
        This conky displays the animated fan over the system info conky next to 
        where it lists the current fan speeds.

        ~/.conky/rightconky.conf -
        The right conky's configuration file (rightconky.conf) has the network info
        and the list of up to 6 incoming and 25 outgoing connections, minus the 
        incoming connections, as it displays no more than 25 total connections due 
        to vertical space limitations.  If you want to use this config, search and
        replace all of the instances of my network adapter name of "enp6s0" with 
        the name of your network adapter.  This conky also features the lua upload 
        and download bars.  Designed to fit on a 1080p screen, this conky should be
        easily expandable to work equally well on higher-resolution displays,
        showing even more connections.  Just follow the logic and layout pattern 
        already established and have fun!
    
        The images/icons used are all in the ~/.conky/images/ subdirectory.  
        There are currently ~12 images & icons used between all of the conkys.
        
        ~/.conky/conkybars.lua - 
        The left conky uses lua to make the really cool looking segmented bars.
        You will need to edit this script as-appropriate for your system, as
        it contains the paths to my particular hard drives and swap setup.  The
        credit for this script goes to u/DareBoy58 on reddit, who supplied his
        original lua script, which I severely edited with some AI help to make 
        it work on my installation.  Bear in mind that this script will only 
        work on systems with conky-all or a conky installation like mine which 
        was compiled with lua extensions enabled.  This script is functioning 
        on/as of conky 1.19.8.
        
        ~/.conky/updownbars.lua - 
        The right conky uses lua to make the really cool looking segmented bars
        showing the upload and download loads.
        You will need to edit this script as-appropriate for your system, as
        it contains the information for my particular setup.

        ~/.conky/conky-startup.sh
        This is a bash script that loads my conkys at startup (or whenever).
        In order to start all of my conkys automatically at boot, I wrote this
        script and linked to it in Kubuntu's AutoRun.
            
My conkys use the following fonts:
    Arial                   - Used for the ANSI
    Larabiefont-Regular     - The main font used throughout
    Ubuntu Condensed        - Used in the right conky on those long hostnames 
                              in the connections list so they'll fit on one line.        
        
That's it! I do hope you find something useful in these conkys! 
They were/are in a constant state of evolution as I get better at working with
the conky config file syntax and incorporating the various external items.

These files have been shared online along with the associated screenshots 
as-is so that if you wish to edit this conky for your own use, you can and should 
feel free to do so.  Pay attention to the file modified dates on Google Drive
or Dropbox, as these conkys are still a work in progress as I continue to learn.

If you require some assistance or explanations, please feel free to find me on
reddit, discord or via email: bayouguru67<at>gmail.com.

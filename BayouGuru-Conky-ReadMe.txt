BayouGuru's Conky ReadMe!
Version 4-18-2023.0613

This ReadMe is for the conky collection created a bit at a time over the course
of more than 2 months for the machine known as "bg-l-box", property of 
BayouGuru, running at 1080p on a 55" LG television that's hung on the wall and
we sit about 12' away from it.  It's possible to run this TV at higher 
resolutions such as 2K and 4K, but it makes everything too small to see for us
and it would only be supported at 30fps instead of 60fps.

It's basically an HTPC setup, therefore, the font sizes are probably going to 
be a bit large for some of you.  I really do hope you enjoy the editing process
to make these scripts work on your system as much as I have enjoyed their 
creation process! These scripts all work with the latest version of conky as of
April, 2023.

This is the online archive/backup of the configurations as they exist and are
currently in-use on my machine.  That machine was built using a 6-Core AMD
CPU with an AMD RX580 GPU, all connected to an ASUS 990FX Mainboard with 8Gb
of 1600MHz SDRAM.  Please bear in mind that the sensor data will probably not
be correct for your system and you will need to research the appropriate sensor
information for your mainboard and components.  As a starter, I would suggest
searching for "<your mainboard make and model> sensor linux" and seeing what
information you can find that correlates to the output of "sensors" in the
terminal.  Bear in mind also that in order for sensors to work, you must first
install "lm-sensors" and run "sudo sensors-detect".  Even after that, you may
find additional sensor outputs like I did by searching your system for "hwmon" 
as that is how I found my case fan rpm, which doesn't show up in sensors for 
some unknown reason, either before or after installing the mainboard sensor 
template that converts the raw sensors output to each sensors more human-
readable format. It also helped a lot to install "psensor" and "radeon-
profile", the latter being used to control the GPU fan speeds on my AMD RX580.

The average observed CPU usage to run these conkys on this system is about 
1%-1.7% for the left conky (updating once per second) and .5% to 1% for the 
right conky (updating once every 2 seconds.) Less than .5% for the weather 
conky, which updates every 15 minutes.  The files are stored in the 
following directories:


    All of the files are in the /home/bayouguru/.conky/ directory or
    subfolders therein. BE SURE to replicate this directory structure, 
    and edit the configuration files appropriately by replacing "bayouguru"
    with the appropriate value for your system.
        
        /home/bayouguru/.conky/conky.conf -
        The left conky's configuration file (conky.conf) displays the CPU 
        info, system uptime, pending updates, load averages, temperature,
        fan, RAM and storage usage information.

        /home/bayouguru/.conky/rightconky.conf -
        The right conky's configuration file (rightconky.conf) has the active 
        processes, top 5 RAM and CPU processes, network info and the list of up
        to 4 incoming and 12 outgoing connections.
    
        /home/bayouguru/.conky/weatherconky.conf -
        This conky is the latest creation, living as it does on one line at the
        bottom-center of the screen.
    
        /home/bayouguru/.conky/accuweather/acc_RSS.sh -
        This is the shell script that pulls the RSS feed from AccuWeather and
        creates the other 2 data files in the accuweather directory that the 
        conky reads from.

        The images/icons used are all in the /home/bayouguru/.conky/images/ 
        subdirectory.  There are currently 7 images/icons used between the 2 
        conkys.
        
        There are 2 scripts in the /scripts/ subdirectory.
            
            hostname.sh is a bash shell script that retrieves the WAN 
                hostname.
            
            ipv6.sh is a bash shell script that retrieves the ip version 6 
                address.  NOTE:  This does not currently support or distinguish 
                between multiple ipv6 addresses, such as local and WAN ipv6 
                addresses like the ipv4 addresses do, though it should be 
                poossible to add it.  Bear in mind that adding another line of
                to display the remote ipv6 address can cause the connection 
                list to run off the bottom of the screen at 1080p or less 
                resolution when it fully-populates...unless you shorten it 
                somehow.

    
These conkys use the following fonts:
    Arial                   - Used for the ANSI
    Larabiefont-Regular     - The main font used throughout
    Ubuntu Condensed        - Used in the right conky on those long hostnames 
                              in the connections list so they'll fit on one line.
    ConkySymbols - Used in the Weather conky for the clouds/sun/wind/rain... icons.
        
        
That's it for this set of conkys! I do hope you find something useful in them! 
They were/are in a constant state of evolution as I get better at working with
the conky config file syntax and incorporating the various external items.

These files have been shared online along with the associated screenshots 
so that if you wish to edit this conky for your own use, you can and should 
feel free to do so.  Pay attention to the file modified dates on Google Drive
or Dropbox, as these conkys are still a work in progress as I continue to learn.

If you require some assistance or explanations, please feel free to find me on
IRC as BayouGuru or BayouGuru67 at https://libera.chat in the #conky channel.

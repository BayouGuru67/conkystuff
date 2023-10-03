#!/usr/bin/env bash

#put your accuweather rss address here
address="http://rss.accuweather.com/rss/liveweather_rss.asp?metric=0&locCode=80829"

wget -qO "$HOME"/.conky/accuweather/weather_raw "$address"

#function: test_image
test_image () {
    case $1 in
         01)
           echo a
         ;;
         02|03)
           echo b
         ;;
         04|05)
           echo c
         ;;
         06)
           echo d
         ;;
         07)
           echo e
         ;;
         08)
           echo f
         ;;
         11)
           echo 0
         ;;
         12)
           echo h
         ;;
         13|14)
           echo g
         ;;
         15)
           echo m
         ;;
         16|17)
           echo k
         ;;
         18)
           echo i
         ;;
         19)
           echo q
         ;;
         20|21|23)
           echo o
         ;;
         22)
           echo r
         ;;
         24|31)
           echo E
         ;;
         25)
           echo v
         ;;
         26)
           echo x
         ;;
         29)
           echo y
         ;;
         30)
           echo 5
         ;;
         32)
           echo 6
         ;;
         33)
           echo A
         ;;
         34|35)
           echo B
         ;;
         36|37)
           echo C
         ;;
         38)
           echo D
         ;;
         39|40)
           echo G
         ;;
         41|42)
           echo K
         ;;
         43|44)
           echo O
         ;;
         *)
	   echo -
         ;;
        esac
}

if [[ -s "$HOME"/.conky/accuweather/weather_raw ]]; then
	grep -E 'Currently|Forecast<\/title>|_31x31.gif' "$HOME"/.conky/accuweather/weather_raw > "$HOME"/.conky/accuweather/weather
	sed -i '/AccuWeather\|Currently in/d' "$HOME"/.conky/accuweather/weather
	sed -i -e 's/^[ \t]*//g' -e 's/<title>\|<\/title>\|<description>\|<\/description>//g' "$HOME"/.conky/accuweather/weather
	sed -i -e 's/&lt;img src="/\n/g' "$HOME"/.conky/accuweather/weather
	sed -i '/^$/d' "$HOME"/.conky/accuweather/weather
	sed -i -e 's/_31x31.*$//g' -e 's/^.*\/icons\///g' "$HOME"/.conky/accuweather/weather
	sed -i -e '1s/.$//' -e '3s/.$//' -e '6s/.$//' "$HOME"/.conky/accuweather/weather
	for (( i=2; i<=8; i+=3 ))
	    do
	        im=$(sed -n ${i}p "$HOME"/.conky/accuweather/weather)
	        sed -i $i"s/^.*$/$(test_image "$im")/" "$HOME"/.conky/accuweather/weather
	    done
fi

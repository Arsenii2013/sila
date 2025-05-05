#!/bin/sh

if [ -f $1 ]; then
    echo "remove $1"
    rm $1
fi       

progress=""
echo -n "waiting for log file $progress"
while [ ! -f $1 ] 
do                                              
    sleep 1 
    echo -n "."
done

gnome-terminal --tab -t "Implementation log filtered"  -- lnav -c ':reset-session' -c ':filter-in WNS' $1
gnome-terminal --tab -t "Implementation log"           -- lnav -c ':reset-session' -c ':goto 100%' $1




#! /bin/sh

echo

#cp /home/luno/rechner/server_scratch/ada/gui/$1.adb .
#[ $? -ne 0 ] && exit 1;
#echo compiling $1
#LIBRARY_TYPE=static
#export LIBRARY_TYPE

#gnatmake $HOME/cad/projects/m-1/src/ada/lib/handlers.ads $1.adb `$HOME/cad/lib/ada/gtkada-3.8.2/bin/gtkada-config`
gnatmake $1.adb `$HOME/cad/lib/ada/gtkada-2.18.0/bin/gtkada-config`
#gnatmake $1.adb
[ $? -ne 0 ] && exit 1;

#./gui

#echo "copying to /opt/m-1/bin"
#cp $1 /opt/m-1/bin
cp $1 ../../../bin
#echo done
#ls -l /opt/m-1/bin/$1
ls -l ../../../bin/$1


exit

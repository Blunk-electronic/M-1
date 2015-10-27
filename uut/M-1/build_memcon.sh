# cp /home/luno/rechner/server_scratch/mod1.opt .
# [ $? -ne 0 ] && exit 1;

#bsmcl chkpsn M-1.udb mod1.opt
#[ $? -ne 0 ] && exit 1;

bsmcl generate M-1.udb memconnect RAM_IC600 IC600 models/BS62LV4006.txt NDIP32
[ $? -ne 0 ] && exit 1;

bsmcl generate M-1.udb memconnect RAM_IC601 IC601 models/BS62LV4006.txt NDIP32
[ $? -ne 0 ] && exit 1;

rm setup/journal.txt

bsmcl compile M-1.udb RAM_IC600
[ $? -ne 0 ] && exit 1;

bsmcl compile M-1.udb RAM_IC601
[ $? -ne 0 ] && exit 1;


bsmcl load RAM_IC600
[ $? -ne 0 ] && exit 1;

bsmcl load RAM_IC601
[ $? -ne 0 ] && exit 1;

bsmcl run RAM_IC600
[ $? -ne 0 ] && exit 1;

bsmcl run RAM_IC601
[ $? -ne 0 ] && exit 1;
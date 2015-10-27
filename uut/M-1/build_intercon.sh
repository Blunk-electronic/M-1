cp /home/luno/rechner/server_scratch/mod1.opt .
[ $? -ne 0 ] && exit 1;

bsmcl chkpsn M-1.udb mod1.opt
[ $? -ne 0 ] && exit 1;

bsmcl generate M-1.udb interconnect intercon
[ $? -ne 0 ] && exit 1;

rm setup/journal.txt

bsmcl compile M-1.udb intercon
[ $? -ne 0 ] && exit 1;

bsmcl load intercon
[ $? -ne 0 ] && exit 1;

bsmcl run intercon
[ $? -ne 0 ] && exit 1;
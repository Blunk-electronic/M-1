#! /bin/sh

test_name=$1
loop_ct=$2

i=0
while [ $i -lt $loop_ct ] 
 do
  echo "continuous run:" $test_name
  echo "loop count    :" $loop_ct
  echo "loop current  :" $i 
  bsmcl run $test_name
  i=$[i+1]
 done
exit

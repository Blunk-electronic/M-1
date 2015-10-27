# 			while [ "$bit_ct" -lt "$size_required" ]
# 				do
# 					val_bin=1$val_bin
# 					bit_ct=$[bit_ct+1]
# 				done

loop=1
while [ "$loop" -lt "$2" ]
	do
		bsmcl run $1
		#[ $? -ne 0 ] && exit 1;
		echo $loop
		loop=$[loop+1]
	done
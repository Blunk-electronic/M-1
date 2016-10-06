#! /bin/bash

# This script uploads test to boundary scan controller.
# If option -run given, tests will also be executed.

# On error, exit from this script.
set -e 

bsmcl load infra
bsmcl load intercon
bsmcl load sram_ic202
bsmcl load sram_ic203
bsmcl load osc
bsmcl load LED_D401


if [ "$1" = "-run" ] 
	then
		bsmcl run infra
		bsmcl run intercon
		bsmcl run sram_ic202
		bsmcl run sram_ic203
		bsmcl run osc
		bsmcl run LED_D401
fi

echo "PASSED" > tmp/test_result.tmp

exit


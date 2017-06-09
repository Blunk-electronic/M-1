#! /bin/bash

# This script loads test into the boundary scan controller

# On error, exit from this script.
set -e 

bsmcl load infra
bsmcl load intercon
bsmcl load sram_ic202
bsmcl load sram_ic203
bsmcl load osc
bsmcl load LED_D401

echo "PASSED" > tmp/test_result.tmp

exit


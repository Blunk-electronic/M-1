#! /bin/bash

# This script auto-generates tests.
# If option -load given, tests will also be uploaded into the boundary scan controller.
# If option -run given, tests will also be executed.

# todo: option that skips test generation

# On error, exit from this script.
set -e 

# First, check primary/secondary dependencies and net classes. Build uut databases.
database_default=mmu_default.udb
database_sram_1=mmu_sram_ic202.udb
database_sram_2=mmu_sram_ic203.udb
cp $database_default $database_sram_1
cp $database_default $database_sram_2

bsmcl chkpsn $database_default
bsmcl chkpsn $database_sram_1
bsmcl chkpsn $database_sram_2
#bsmcl chkpsn mmu_osc.udb

# Clean up journal in order to save memory in boundary scan controller.
[ -e setup/journal.txt ] && rm setup/journal.txt

# infrastructure and interconnect tests
bsmcl generate mmu_default.udb infrastructure infra
bsmcl compile mmu_default.udb infra
# 
bsmcl generate mmu_default.udb interconnect intercon
bsmcl compile mmu_default.udb intercon


# memory interconnect tests
bsmcl generate $database_sram_1 memconnect sram_ic202 IC202 models/U62256_wo_ce_min_1000h.txt NDIP28
bsmcl compile $database_sram_1 sram_ic202
# 
bsmcl generate $database_sram_2 memconnect sram_ic203 IC203 models/U62256_wo_ce.txt NDIP28
bsmcl compile $database_sram_2 sram_ic203
# 
# oscillator test
bsmcl generate $database_default clock osc IC301 6 10 1 # sample ic301 pin 6 ten times once per second
bsmcl compile $database_default osc
# 
# LED tests
bsmcl generate $database_default toggle LED_D401 LED0 10 1 1 # toggles net LED0 ten times with one second low and high
bsmcl compile $database_default LED_D401

# load tests
if [ "$1" = "-load" ] 
	then
		bsmcl load infra
		bsmcl load intercon
		bsmcl load sram_ic202
		bsmcl load sram_ic203
		bsmcl load osc
		bsmcl load LED_D401
fi

if [ "$2" = "-run" ] 
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


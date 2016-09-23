#! /bin/bash

# This script auto-generates tests.
# If option -load given, tests will also be uploaded into the boundary scan controller.
# If option -run given, tests will also be executed.

# On error, exit from this script.
set -e 

# create tmp and bak directories if not existent
if [ ! -e tmp ] 
	then
		mkdir tmp
fi

if [ ! -e bak ] 
	then
		mkdir bak
fi


# First, check primary/secondary dependencies and net classes. Build uut databases.
bsmcl chkpsn mmu_default.udb
bsmcl chkpsn mmu_sram_ic202.udb
bsmcl chkpsn mmu_sram_ic203.udb
bsmcl chkpsn mmu_osc.udb

# Clean up journal in order to save memory in boundary scan controller.
[ -e setup/journal.txt ] && rm setup/journal.txt

# infrastructure and interconnect tests
bsmcl generate mmu_default.udb infrastructure infra
bsmcl compile mmu_default.udb infra

bsmcl generate mmu_default.udb interconnect intercon
bsmcl compile mmu_default.udb intercon


# memory interconnect tests
bsmcl generate mmu_sram_ic202.udb memconnect sram_ic202 IC202 models/U62256_wo_ce_min_1000h.txt NDIP28
bsmcl compile mmu_sram_ic202.udb sram_ic202

bsmcl generate mmu_sram_ic203.udb memconnect sram_ic203 IC203 models/U62256_wo_ce.txt NDIP28
bsmcl compile mmu_sram_ic203.udb sram_ic203

# oscillator test
bsmcl generate mmu_osc.udb clock osc IC301 6 10 1 1
bsmcl compile mmu_osc.udb osc

# LED tests
bsmcl generate mmu_default.udb toggle LED_D401 LED0 10 1 1
bsmcl compile mmu_default.udb LED_D401

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

exit


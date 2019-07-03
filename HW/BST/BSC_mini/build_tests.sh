#! /bin/bash

# This script auto-generates tests.

# On error, exit from this script.
set -e 

# First, check primary/secondary dependencies and net classes. Build uut databases.
database_default=BSC_mini.udb
database_ram_out_1=BSC_mini_ram_out_1.udb
database_ram_out_2=BSC_mini_ram_out_2.udb
database_ram_in=BSC_mini_ram_in.udb
database_clock_test=BSC_mini_clk.udb
database_vccio_3v3=BSC_mini_vccio_3v3.udb

bsmcl chkpsn $database_default
bsmcl chkpsn $database_ram_out_1
bsmcl chkpsn $database_ram_out_2
bsmcl chkpsn $database_ram_in
bsmcl chkpsn $database_clock_test
bsmcl chkpsn $database_vccio_3v3

# Clean up journal in order to save memory in boundary scan controller.
[ -e setup/journal.txt ] && rm setup/journal.txt


# infrastructure and interconnect tests
bsmcl generate $database_default infrastructure infra
bsmcl compile $database_default infra
 
bsmcl generate $database_default interconnect intercon
bsmcl compile $database_default intercon

bsmcl generate $database_ram_out_1 memconnect ram_out_1 IC602 models/AS6C4008.txt NDIP32
bsmcl compile $database_ram_out_1 ram_out_1

bsmcl generate $database_ram_out_2 memconnect ram_out_2 IC603 models/AS6C4008.txt NDIP32
bsmcl compile $database_ram_out_2 ram_out_2

bsmcl generate $database_ram_in memconnect ram_in IC601 models/AS6C4008.txt NDIP32
bsmcl compile $database_ram_in ram_in

# bsmcl generate $database_clock_test clock clk_slow IC801 154 10 1
#manually modified for intrusive mode
bsmcl compile $database_clock_test clk_slow

# bsmcl generate $database_clock_test clock clk_master IC801 181 10 0.1
# manually modified for intrusive mode
bsmcl compile $database_clock_test clk_master

#cluster tests
bsmcl compile $database_default cluster_digital
bsmcl compile $database_default cluster_analog

#vccio
bsmcl compile $database_default vccio

#LED - requires vccio set to 3V3 and a very low tck frequency
#bsmcl generate $database_vccio_3v3 interconnect intercon_slow
bsmcl compile $database_vccio_3v3 intercon_slow

bsmcl load infra
bsmcl load intercon
bsmcl load ram_out_1
bsmcl load ram_out_2
bsmcl load ram_in
bsmcl load cluster_digital
bsmcl load cluster_analog
bsmcl load clk_slow
bsmcl load clk_master
bsmcl load vccio
bsmcl load intercon_slow

bsmcl run infra
bsmcl run intercon
bsmcl run ram_out_1
bsmcl run ram_out_2
bsmcl run ram_in
bsmcl run cluster_digital
bsmcl run cluster_analog
bsmcl run clk_slow
bsmcl run clk_master
bsmcl run vccio
bsmcl run intercon_slow

exit


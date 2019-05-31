#! /bin/bash

set -e

database=BSC_mini.udb
database_ram_out_1=BSC_mini_ram_out_1.udb
database_ram_out_2=BSC_mini_ram_out_2.udb
database_ram_in=BSC_mini_ram_in.udb
database_clock_test=BSC_mini_clk.udb
database_vccio_3v3=BSC_mini_vccio_3v3.udb

# initialize databases
cp seed.txt $database

# import BSDL models
bsmcl import_bsdl $database

# import eagle netlist
bsmcl import_cad eagle cad/netlist.txt cad/partlist.txt main

# make boundary scan nets from skeleton.txt
bsmcl mknets $database
cp $database $database_ram_out_1
cp $database $database_ram_out_2
cp $database $database_ram_in
cp $database $database_vccio_3v3
cp $database $database_clock_test

#bsmcl mkoptions $database
#bsmcl mkoptions $database_clock_test
#bsmcl mkoptions $database_ram_out_1
#bsmcl mkoptions $database_ram_out_2
#bsmcl mkoptions $database_ram_in


exit

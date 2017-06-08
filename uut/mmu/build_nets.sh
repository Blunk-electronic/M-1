#! /bin/bash

set -e

database=mmu_default.udb

# initialize databases
cp mmu_seed.txt $database

# import BSDL models
echo "importing BSDL models..."
bsmcl import_bsdl $database

# import eagle netlist
echo "importing eagle netlist ..."
bsmcl import_cad eagle cad/mmu_v101r4_from_brd.net cad/mmu_v101r4_from_brd.part main

# make boundary scan nets from skeleton.txt
bsmcl mknets $database

#bsmcl mkoptions $database
#bsmcl chkpsn $database 
exit

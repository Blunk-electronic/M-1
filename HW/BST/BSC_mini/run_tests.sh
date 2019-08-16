#! /bin/bash

# This script runs all tests loaded by by script build_tests.sh or load_tests.sh

# On error, exit from this script.
set -e 

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


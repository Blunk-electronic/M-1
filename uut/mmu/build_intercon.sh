#! /bin/bash

# This script auto-generates tests.
# If option -load given, tests will also be uploaded into the boundary scan controller.
# If option -run given, tests will also be executed.

# todo: option that skips test generation

# On error, exit from this script.
set -e 

# First, check primary/secondary dependencies and net classes. Build uut databases.
database_default=mmu_intercon.udb

bsmcl chkpsn $database_default

# Clean up journal in order to save memory in boundary scan controller.
[ -e setup/journal.txt ] && rm setup/journal.txt


# infrastructure and interconnect tests
bsmcl generate $database_default infrastructure infra
bsmcl compile $database_default infra
bsmcl load infra
#
bsmcl generate $database_default interconnect intercon
bsmcl compile $database_default intercon
bsmcl load intercon

bsmcl run infra
bsmcl run intercon

exit


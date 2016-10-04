#! /bin/bash
ADA_PROJECT_PATH=/usr/local/lib/gnat:$ADA_PROJECT_PATH
export ADA_PROJECT_PATH
gnatclean -Pbsmgui.gpr
exit

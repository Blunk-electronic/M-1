Setup
-----

make sure the environment variable ADA_PROJECT_PATH is set so that
gtkada.gpr can be found. For example do this in /etc/profile.local via these
lines:

ADA_PROJECT_PATH=/usr/lib64/gcc/x86_64-suse-linux/8/lib/gnat/
export ADA_PROJECT_PATH


Compiling
---------

gprbuild -P bsmgui.gpr


Cleaning up
-----------

gprclean

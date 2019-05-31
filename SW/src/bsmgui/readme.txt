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


Installing
----------

-- The binary always goes into the bin directory of $HOME:
gprinstall -p --prefix=$HOME --mode=usage bsmgui.gpr


Cleaning up
-----------

gprclean


Uninstalling
------------

-- The binary is removed from $HOME/bin:
gprinstall --uninstall -p --prefix=$HOME --mode=usage bsmgui.gpr


Furhter Docs
------------
http://docs.adacore.com/gprbuild-docs/pdf/gprbuild_ug.pdf
https://www.adacore.com/gems/gem-159-gprinstall-part-2


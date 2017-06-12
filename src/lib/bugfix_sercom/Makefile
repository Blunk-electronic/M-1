# on a 32bit machine uncomment this line:
PREFIX = /usr/lib/gcc/i586-suse-linux/4.8

# on a 64bit machine uncomment this line:
#PREFIX = /usr/lib64/gcc/x86_64-suse-linux/4.8

#OPTS = -a -k -gnato -O2
OPTS = -a -gnato -O2	# means all options passed to gnat

# here live the source codes (*.ads/*.adb):
ADAINC = $(PREFIX)/adainclude

# here live the library information files (*.ali)
ADALIB = $(PREFIX)/adalib


# we compile only the sercom stuff
SOURCE = g-sercom.ad[sb]
UNITS = $(basename g-sercom.ads)

# if other source is to be compiled, use these lines:
#SOURCE = $(wildcard *.ad[sb])
#UNITS = $(basename $(wildcard *.ads))


ALIS = $(addsuffix .ali, $(UNITS))
# means all *.ali files

OBJS = $(addsuffix .o, $(UNITS))
# means all object files (*.o)

.PHONY: all install uninstall clean test

all:
	gnatmake $(OPTS) $(UNITS)

install:
# copy g-sercom.ali in directory adalib/
	cp $(ALIS) $(ADALIB)	

uninstall:
# remove g-sercom.ali from adalib/
	@for file in $(ALIS); do ${RM} $(ADALIB)/$$file; done	

clean:
# remove ali and o files from current working directory
	${RM} $(ALIS) $(OBJS)

test:
#	@echo "Source files: $(SOURCE)"
	@echo "Compilation units: $(UNITS)"
#	@for file in $(SOURCE); do ls $(ADAINC)/$$file; done
	@for file in $(ALIS); do ls $(ADALIB)/$$file; done
#	@for file in $(OBJS); do ls $(ADALIB)/$$file; done

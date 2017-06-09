#PREFIX = /usr/lib/gcc/i586-suse-linux/4.8
PREFIX = /usr/lib64/gcc/x86_64-suse-linux/4.8
#usr/local/ada-4.3/lib/gcc/powerpc-apple-darwin8/4.3.0
#OPTS = -a -k -gnato -O2
OPTS = -a -gnato -O2
ADAINC = $(PREFIX)/adainclude
ADALIB = $(PREFIX)/adalib
#SOURCE = $(wildcard *.ad[sb])
SOURCE = g-sercom.ad[sb]
#UNITS = $(basename $(wildcard *.ads))
UNITS = $(basename g-sercom.ads)
ALIS = $(addsuffix .ali, $(UNITS))
OBJS = $(addsuffix .o, $(UNITS))

.PHONY: all install uninstall clean test

all:
	gnatmake $(OPTS) $(UNITS)

install:
#	cp $(SOURCE) $(ADAINC)/
	cp *.ali $(ADALIB)/
	cp *.o $(ADALIB)/

uninstall:
#	@for file in $(SOURCE); do ${RM} $(ADAINC)/$$file; done
	@for file in $(ALIS); do ${RM} $(ADALIB)/$$file; done
	@for file in $(OBJS); do ${RM} $(ADALIB)/$$file; done

clean:
	${RM} *.ali *.o

test:
	@echo "Source files: $(SOURCE)"
	@echo "Compilation units: $(UNITS)"
	@for file in $(SOURCE); do ls $(ADAINC)/$$file; done
	@for file in $(ALIS); do ls $(ADALIB)/$$file; done
	@for file in $(OBJS); do ls $(ADALIB)/$$file; done

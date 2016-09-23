TARGET = bsmgui

# LIBRARY_TYPE=static
# export LIBRARY_TYPE
# gnatmake $HOME/cad/projects/m-1/src/ada/lib/handlers.ads $1.adb `$HOME/cad/lib/ada/gtkada-3.8.2/bin/gtkada-config`
# gnatmake $1.adb `$HOME/cad/lib/ada/gtkada-2.18.0/bin/gtkada-config`

VPATH = include
OBJS = $(TARGET).o m1_internal.o m1_firmware.o m1_numbers.o m1_files_and_directories.o m1.o
PREFIX = $(HOME)
BINDIR = $(PREFIX)/bin

# compile
.adb.o:
	gcc -c $< -I include
.SUFFIXES: .adb .o

# link
$(TARGET): $(OBJS)
	gnatbind -x $(TARGET).ali; gnatlink $(TARGET).ali

install:
#	install -D -s $(TARGET) $(BINDIR)/$(TARGET) 
# if debug symbols are required:
	install -D $(TARGET) $(BINDIR)/$(TARGET)

uninstall:
	-rm $(BINDIR)/$(TARGET)

clean:
	rm *.o *.ali $(TARGET)
	



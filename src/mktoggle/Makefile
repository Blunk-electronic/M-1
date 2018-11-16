TARGET = mktoggle

VPATH = include
OBJS = $(TARGET).o m1_base.o m1_string_processing.o m1_database.o m1_test_gen_and_exec.o m1_firmware.o m1_numbers.o m1_files_and_directories.o m1_serial_communications.o m1_import.o csv.o
PREFIX = $(HOME)
BINDIR = $(PREFIX)/bin

# compile
.adb.o:
	gcc -c -gnat2012 $< -I $(VPATH)
.SUFFIXES: .adb .o

# link
$(TARGET): $(OBJS)
	gnatbind -x $(TARGET).ali; gnatlink $(TARGET).ali

install:
#	install -D -s $(TARGET) $(BINDIR)/$(TARGET) 
# if debug symbols are required:
	install -D $(TARGET) $(BINDIR)/$(TARGET)

uninstall:
	-rm -f $(BINDIR)/$(TARGET)

clean:
	rm -f *.o *.ali $(TARGET)




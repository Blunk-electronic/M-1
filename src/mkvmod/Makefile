VPATH = include
OBJS = mkvmod.o m1.o m1_internal.o 

# compile
.adb.o:
	gcc -c $< -I include
.SUFFIXES: .adb .o

# link
mkvmod: $(OBJS)
	gnatbind -x mkvmod.ali; gnatlink mkvmod.ali

clean:
	rm *.o *.ali



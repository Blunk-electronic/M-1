VPATH = include
OBJS = mkmemcon.o m1.o m1_internal.o 

# compile
.adb.o:
	gcc -c $< -I include
.SUFFIXES: .adb .o

# link
mkmemcon: $(OBJS)
	gnatbind -x mkmemcon.ali; gnatlink mkmemcon.ali

clean:
	rm *.o *.ali



VPATH = include
OBJS = bsmcl.o m1.o m1_internal.o 

# compile
.adb.o:
	gcc -c $< -I include
.SUFFIXES: .adb .o

# link
bsmcl: $(OBJS)
	gnatbind -x bsmcl.ali; gnatlink bsmcl.ali

clean:
	rm *.o *.ali



VPATH = include
OBJS = mknets.o m1.o m1_internal.o 

# compile
.adb.o:
	gcc -c $< -I include
.SUFFIXES: .adb .o

# link
mknets: $(OBJS)
	gnatbind -x mknets.ali; gnatlink mknets.ali

clean:
	rm *.o *.ali



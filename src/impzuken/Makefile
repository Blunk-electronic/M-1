VPATH = include
OBJS = impzuken.o m1.o m1_internal.o 

# compile
.adb.o:
	gcc -c $< -I include
.SUFFIXES: .adb .o

# link
impzuken: $(OBJS)
	gnatbind -x impzuken.ali; gnatlink impzuken.ali

clean:
	rm *.o *.ali



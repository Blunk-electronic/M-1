VPATH = include
OBJS = impbsdl.o m1.o m1_internal.o 

# compile
.adb.o:
	gcc -c $< -I include
.SUFFIXES: .adb .o

# link
impbsdl: $(OBJS)
	gnatbind -x impbsdl.ali; gnatlink impbsdl.ali

clean:
	rm *.o *.ali



VPATH = include
OBJS = mkoptions.o m1.o m1_internal.o csv.o 

# compile
.adb.o:
	gcc -c $< -I include
.SUFFIXES: .adb .o

# link
mkoptions: $(OBJS)
	gnatbind -x mkoptions.ali; gnatlink mkoptions.ali

clean:
	rm *.o *.ali



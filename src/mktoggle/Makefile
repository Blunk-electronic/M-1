VPATH = include
OBJS = mktoggle.o m1.o m1_internal.o 

# compile
.adb.o:
	gcc -c $< -I include
.SUFFIXES: .adb .o

# link
mktoggle: $(OBJS)
	gnatbind -x mktoggle.ali; gnatlink mktoggle.ali

clean:
	rm *.o *.ali



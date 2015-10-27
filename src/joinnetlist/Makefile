VPATH = include
OBJS = joinnetlist.o m1.o m1_internal.o 

# compile
.adb.o:
	gcc -c $< -I include
.SUFFIXES: .adb .o

# link
joinnetlist: $(OBJS)
	gnatbind -x joinnetlist.ali; gnatlink joinnetlist.ali

clean:
	rm *.o *.ali



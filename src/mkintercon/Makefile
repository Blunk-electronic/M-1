VPATH = include
OBJS = mkintercon.o m1.o m1_internal.o 

# compile
.adb.o:
	gcc -c $< -I include
.SUFFIXES: .adb .o

# link
mkintercon: $(OBJS)
	gnatbind -x mkintercon.ali; gnatlink mkintercon.ali

clean:
	rm *.o *.ali



VPATH = include
OBJS = chkpsn.o m1.o m1_internal.o 

# compile
.adb.o:
	gcc -c $< -I include
.SUFFIXES: .adb .o

# link
chkpsn: $(OBJS)
	gnatbind -x chkpsn.ali; gnatlink chkpsn.ali

clean:
	rm *.o *.ali



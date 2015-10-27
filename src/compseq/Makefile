VPATH = include
OBJS = compseq.o m1.o m1_internal.o 

# compile
.adb.o:
	gcc -c $< -I include
.SUFFIXES: .adb .o

# link
compseq: $(OBJS)
	gnatbind -x compseq.ali; gnatlink compseq.ali

clean:
	rm *.o *.ali




CFLAGS=-Wall -g
LFLAGS=

all: joblex

joblex: joblex.l
	$(LEX) -t joblex.l > joblex.c
	$(CC) -o $@ joblex.c

clean:
	rm -f *.o joblex

.PHONY: all clean


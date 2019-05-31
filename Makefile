
CFLAGS=-Wall -g
LFLAGS=

all: joblex


joblex: joblex.l
	$(LEX) -t joblex.l > joblex.c
	$(CC) -o $@ joblex.c

test: joblex
	./test.sh

clean:
	rm -f *.o joblex.c joblex

.PHONY: all clean test


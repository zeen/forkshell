
build:
	gcc -shared -o lforkshell.so -fPIC -I/usr/include/lua5.2/ lforkshell.c

#ifndef STDLIB_H
#define STDLIB_H

#include <malloc.h>

#define RAND_MAX 0xffffffffU

int abs(int i);
unsigned int rand();
void srand(int);
void exit(int);

#endif


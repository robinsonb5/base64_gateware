#ifndef SETJMP_H
#define SETJMP_H

/* Enough space for the return address and non-scratch registers) */
typedef struct jmp_buf_s { int storage[12]; } jmp_buf[1];

int setjmp(__reg("a0") jmp_buf env);
int longjmp(__reg("a0") jmp_buf env, __reg("d0") int val);

#endif


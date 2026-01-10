#include "setjmp.h"


char *_args[]={"SoC",0};

int main(int argc,char**argv);

jmp_buf _exitjmpbuf;

void _premain()
{
	int rc;
	if(!(rc=setjmp(_exitjmpbuf)))
		main(1,_args);
}

void exit(int rc)
{
	longjmp(_exitjmpbuf,rc);
}


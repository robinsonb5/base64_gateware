#include <stdio.h>
#include "uart.h"

int main(int argc,char **argv)
{
	while(1) {
		int i;
		puts("Hi there, world! (puts)\n");
		printf("Hello, World! (printf) - %d!\n",42);
		for(i=0;i<1000;++i) {
			int c=getchar();
			if(c>=0)
				putchar(c&(~32));
		}
	}
	return(0);
}


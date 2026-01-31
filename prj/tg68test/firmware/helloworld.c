#include <stdio.h>
#include "uart.h"
#include "hw/spi.h"
#include "minfat.h"

int main(int argc,char **argv)
{
	DIRENTRY *dir=0;
	int i;
	puts("Hi there, world! (puts)\n");
	printf("Hello, World! (printf) - %d!\n",42);
	while(1) {
		int c=getchar()&(~32);
		switch(c) {
			case 'D' :
				printf("Scanning directory\n");
				dir=0;
				while((dir=NextDirEntry(dir==0,0,0)))
				{
					if (dir->Name[0] != SLOT_EMPTY && dir->Name[0] != SLOT_DELETED) // valid entry??
					{
						printf("%s (%s)\n",dir->Name,longfilename);
					}
				}
				break;

			case 'S' :
				printf("SD card size is %d\n",sd_get_size());
				break;

			default:
				putchar(c);
				break;
		}
	}
	return(0);
}


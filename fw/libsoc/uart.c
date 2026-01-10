#include "hw/uart.h"


__weak int putchar(int c)
{
	do {} while(!((HW_UART(REG_UART))&(1<<REG_UART_TXREADY)));

	HW_UART(REG_UART)=c;
	return(c);
}

__weak int getchar()
{
	int c=HW_UART(REG_UART);
	if(c&(1<<REG_UART_RXINT))
	{
		c&=0xff;
		return(c);
	}
	return(0);
}


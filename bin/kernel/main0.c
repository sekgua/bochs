#include "print.h"
#include "init.h"
void main(void) 
{	
	// put_char('k');
	// put_char('e');
	// put_char('r');
	// put_char('n');
	// put_char('e');
	// put_char('l');
	// put_char('\n');

	// put_char('H');
	// put_char('u');
	// put_char('H');
	// put_char('a');
	// put_char('o');
	// put_char(' ');

	// put_char('I');
	// put_char('n');
	// put_char(' ');
	
	// put_char('S');
	// put_char('M');
	// put_char('\b');
	// put_char('M');
	// put_char('I');
	// put_char('C');
	// while(1);
	// put_str("I am kernel\n");
	// put_int(0);
	// put_char('\n');
	// put_int(9);
	// put_char('\n');
	// put_int(0x00021a3f);
	// put_char('\n');
	// put_int(0x12345678);
	// put_char('\n');
	// put_int(0x00000000);
	put_str("I am kernel\n");
	init_all();
	asm volatile("sti");
	while(1);
}
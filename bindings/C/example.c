#include <stdio.h>
#include "fde64.h"

int main(void)
{
	const void *ptr = (const void *)&main;
	struct fde64s cmd;

	for (;;) {
		decode(ptr, &cmd);
		ptr = (const void *)((uintptr_t)ptr + cmd.len);
		printf("opcode: ");
		switch (cmd.opcode_len) {
		case 1:
			printf("%02X", cmd.opcode);
			break;
		case 2:
			printf("%02X %02X", cmd.opcode, cmd.opcode2);
			break;
		case 3:
			printf("%02X %02X %02X", cmd.opcode, cmd.opcode2, cmd.opcode3);
			break;
		}
		printf(" full instruction-length: %d\n", cmd.len);
		if (getchar() == 'q')
			break;
	}
	return 0;
}

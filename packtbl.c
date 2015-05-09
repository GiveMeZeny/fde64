#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>

#define SKIPSPACE(ptr)                                 \
	do {                                           \
		while (isspace((unsigned char)*(ptr))) \
			(ptr)++;                       \
	} while (0)

#define CUTLINEEND(ptr)                              \
	do {                                         \
		char *tmp = (ptr) + strlen(ptr) - 2; \
		if (*tmp == '\r')                    \
			*tmp = '\0';                 \
		else if (*++tmp == '\n')             \
			*tmp = '\0';                 \
	} while (0)

int replace(char *buf, const char *srch, const char *rpl)
{
	char *ptr = buf, *end = strchr(buf, '\0');
	size_t len = end - buf;
	size_t ls = strlen(srch);
	size_t lr = strlen(rpl);
	size_t diff = ls - lr;

	if (ls < lr)
		return -1;
	while ((ptr = strstr(ptr, srch))) {
		memcpy(ptr, rpl, lr);
		memmove(ptr + lr, ptr + ls, end - ptr - ls + 1);
		len -= diff;
	}
	return (int)len;
}

char *pack_table(const char *buf, const char *header, const char *name)
{
	struct {
		int len;
		char *buf[256];
		int cnt[256];
	} tbl = {.len = 0, .cnt = {0}};
	char flags[32], last[32];
	int i, j;

	while (buf && sscanf(buf, " db %32s", flags) == 1) {
		if (!tbl.len || strcmp(last, flags) ||
		    tbl.cnt[tbl.len - 1] == 7) {
			if (tbl.len++)
				tbl.buf[tbl.len - 2] = strdup(last);
			strcpy(last, flags);
		} else {
			tbl.cnt[tbl.len - 1]++;
		}
		buf = strstr(buf + 2, "\n") + 1;
	}
	tbl.buf[tbl.len - 1] = strdup(last);
	printf("%s (%d bytes)\n\n%s\n", header, tbl.len, name);
	for (i = 0, j = 0; i < tbl.len; i++) {
		replace(tbl.buf[i], "C_", "");
		replace(tbl.buf[i], "+", "_");
		printf("\tdb T_%-17s + %d shl 5", tbl.buf[i], tbl.cnt[i]);
		if (tbl.cnt[i]) {
			printf(" ; %02X-%02X\n", j, j + tbl.cnt[i]);
			j += tbl.cnt[i] + 1;
		} else {
			printf(" ; %02X\n", j++);
		}
	}
	return (char *)buf;
}

int main()
{
	char *buf, *offset, *ptr;
	long sz;
	FILE *fp;
	const char *next_opcode = "    .next_opcode:\n\tmov\tah,al\n";
	const char *opcode_table_header = "  ; opcode table obviously";
	const char *opcode_table = "opcode_table:\n";
	const char *opcode_table_0F_header = "  ; escaped opcode table";
	const char *opcode_table_0F = "opcode_table_0F:\n";

	fp = fopen("decode.asm", "rb");
	if (!fp)
		return 1;
	if (fseek(fp, 0, SEEK_END))
		return 1;
	sz = ftell(fp);
	if (sz == EOF)
		return 1;
	rewind(fp);
	buf = malloc(sz + 1);
	if (!buf)
		return 1;
	if (fread(buf, 1, sz, fp) != (size_t)sz)
		return 1;
	buf[sz] = '\0';
	replace(buf, "\r\n", "\n");
	ptr = strstr(buf, next_opcode);
	if (!ptr)
		return 1;
	offset = ptr + strlen(next_opcode);
	fwrite(buf, 1, offset - buf, stdout);
	printf("      .loop:\n"
	       "\tmov\tcl,[rbx]\n"
	       "\tmov\tch,[rbx]\n"
	       "\tshr\tcl,5\n"
	       "\tand\tch,1Fh\n"
	       "\tinc\tcl\n"
	       "\tinc\trbx\n"
	       "\tsub\tal,cl\n"
	       "\tjnc\t.loop\n"
	       "\tmov\tal,ch\n"
	       "\tlea\trbx,[flags_table]\n");
	ptr = strstr(offset, opcode_table_header);
	if (!ptr)
		return 1;
	fwrite(offset, 1, ptr - offset, stdout);
	printf("  ; flags table indices\n\n"
	       "  T_NONE\t      = 0\n"
	       "  T_MODRM\t      = 1\n"
	       "  T_MODRM_IMM8\t      = 2\n"
	       "  T_MODRM_IMM32\t      = 3\n"
	       "  T_IMM8\t      = 4\n"
	       "  T_IMM16\t      = 5\n"
	       "  T_IMM16_IMM8\t      = 6\n"
	       "  T_IMM32\t      = 7\n"
	       "  T_REL_IMM8\t      = 8\n"
	       "  T_REL_IMM32\t      = 9\n"
	       "  T_GROUP_MODRM\t      = 10\n"
	       "  T_GROUP_MODRM_IMM8  = 11\n"
	       "  T_GROUP_MODRM_IMM32 = 12\n"
	       "  T_ERROR_NONE\t      = 13\n"
	       "  T_ERROR_MODRM\t      = 14\n"
	       "  T_ERROR_IMM8\t      = 15\n"
	       "  T_ERROR_IMM32_IMM16 = 16\n"
	       "  T_MOFFS\t      = 17\n"
	       "  T_PREFIX\t      = 18\n"
	       "  T_0F\t\t      = 19\n"
	       "  T_3BYTE\t      = 20\n"
	       "  T_UNDEFINED\t      = 21\n\n"
	       "  ; flags table for grouping\n\n"
	       "flags_table:\n\n"
	       "\tdb\tC_NONE\n"
	       "\tdb\tC_MODRM\n"
	       "\tdb\tC_MODRM+C_IMM8\n"
	       "\tdb\tC_MODRM+C_IMM32\n"
	       "\tdb\tC_IMM8\n"
	       "\tdb\tC_IMM16\n"
	       "\tdb\tC_IMM16+C_IMM8\n"
	       "\tdb\tC_IMM32\n"
	       "\tdb\tC_REL+C_IMM8\n"
	       "\tdb\tC_REL+C_IMM32\n"
	       "\tdb\tC_GROUP+C_MODRM\n"
	       "\tdb\tC_GROUP+C_MODRM+C_IMM8\n"
	       "\tdb\tC_GROUP+C_MODRM+C_IMM32\n"
	       "\tdb\tC_ERROR+C_NONE\n"
	       "\tdb\tC_ERROR+C_MODRM\n"
	       "\tdb\tC_ERROR+C_IMM8\n"
	       "\tdb\tC_ERROR+C_IMM32+C_IMM16\n"
	       "\tdb\tC_MOFFS\n"
	       "\tdb\tC_PREFIX\n"
	       "\tdb\tC_0F\n"
	       "\tdb\tC_3BYTE\n"
	       "\tdb\tC_UNDEFINED\n\n");
	ptr = strstr(ptr, opcode_table);
	if (!ptr)
		return 1;
	ptr = pack_table(ptr + strlen(opcode_table), opcode_table_header,
			 opcode_table);
	printf("\n");
	ptr = strstr(offset, opcode_table_0F_header);
	if (!ptr)
		return 1;
	ptr = strstr(ptr, opcode_table_0F);
	if (!ptr)
		return 1;
	ptr = pack_table(ptr + strlen(opcode_table_0F), opcode_table_0F_header,
			 opcode_table_0F);
	printf("%s", ptr);
	free(buf);
	fclose(fp);
	return 0;
}

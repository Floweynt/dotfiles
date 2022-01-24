#include <stdlib.h>
#include <stddef.h>
#include "../util.h"

int buf_len = 0;
static int current = 0;
const char* set_pos(void) {
	current = buf_len;
	return "";
}

const char* pad_to(const char* str) {
	// target index
	int final = atoi(str) + current;

	if(final < buf_len)
		return "";
	return bprintf("%*s", final - buf_len, "");
}
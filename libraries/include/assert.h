/* assert.h */

#ifndef ASSERT_H
#define ASSERT_H

#include <stdio.h>

#ifndef NDEBUG
# define assert(cond) do { \
	if(!(cond)) { \
		dprintf("Assertion '%s' failed in file %s:%u, %s\r\n", #cond, __FILE__, __LINE__, __FUNCTION__); \
		exit(-1); \
	} \
} while(0)
#else
# define assert(cond) 0
#endif

#endif

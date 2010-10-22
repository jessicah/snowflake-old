/* where to get __WORDSIZE from? */

/* Minimum and maximum values a `signed long int' can hold.  */
/*
#  if __WORDSIZE == 64
#   define LONG_MAX	9223372036854775807L
#  else
#   define LONG_MAX	2147483647L
#  endif
*/

#define CHAR_BIT	8
#define INT_MAX		2147483647
#define INT_MIN		-2147483648
#define UINT_MAX	4294967295
#define LONG_MAX	2147483647L
#define ULONG_MAX	4294967295L
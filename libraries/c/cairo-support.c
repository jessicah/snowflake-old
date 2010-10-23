#include <stdio.h>
#include <math.h>
#include <stddef.h>
#include <stdlib.h>

void __assert_fail() {
	dprintf("cairo-support: assertion failed\n");
	exit(-1);
}

void __stack_chk_fail() {
	dprintf("cairo-support: stack check failed\n");
	exit(-1);
}

void __strdup() {
	dprintf("cairo-support: __strdup not implemented\n");
	exit(-1);
} /* not used by cairo -- a font thing */

/* FIXME: use rdtsc or similar */
unsigned long rand() {
	static unsigned long r = 0;
	return ++r;
}

void qsort(void *base, unsigned long nel, unsigned long width,
              int (*comp)(const void *, const void *)) {
	unsigned long wgap, i, j, k;
	char tmp;

	if ((nel > 1) && (width > 0)) {
		//assert( nel <= ((size_t)(-1)) / width ); /* check for overflow */
		wgap = 0;
		do {
			wgap = 3 * wgap + 1;
		} while (wgap < (nel-1)/3);
		/* From the above, we know that either wgap == 1 < nel or */
		/* ((wgap-1)/3 < (int) ((nel-1)/3) <= (nel-1)/3 ==> wgap <  nel. */
		wgap *= width;			/* So this can not overflow if wnel doesn't. */
		nel *= width;			/* Convert nel to 'wnel' */
		do {
			i = wgap;
			do {
				j = i;
				do {
					register char *a;
					register char *b;

					j -= wgap;
					a = j + ((char *)base);
					b = a + wgap;
					if ( (*comp)(a, b) <= 0 ) {
						break;
					}
					k = width;
					do {
						tmp = *a;
						*a++ = *b;
						*b++ = tmp;
					} while ( --k );
				} while (j >= wgap);
				i += width;
			} while (i < nel);
			wgap = (wgap - width)/3;
		} while (wgap);
	}
}

#include <stdarg.h>

extern int vdprintf(const char *fmt, va_list args);

int fprintf(int fd, const char *fmt, ...)
{
	va_list args;
	int rv;

	va_start(args, fmt);
	rv = vdprintf(fmt, args);
	va_end(args);
	return rv;
}

extern int finite(double);

int __finite(double x) {
	return finite(x);
}

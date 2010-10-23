#include <stddef.h>
#include <stdarg.h>
#include <math.h>

void *malloc(size_t n);
int dprintf(const char *fmt, ...);
size_t strlen(const char *str);

int abs(int x)
{
	return x < 0 ? -x : x;
}

/* <ctype.h> */

int isprint(int c) {
	return 1;
}

int isdigit(int c) {
	return (c >= '0' && c <= '9');
}

/* <stdlib.h> */

void exit(int status) {
	dprintf("exit (%d)\n", status);
	while (1) {
		asm volatile("cli");
		asm volatile("hlt");
	}
}

/* <stdio.h> */
int stderr;
extern int do_printf(const char *fmt, va_list args, int (*fn)(unsigned c, void **helper), void *ptr);

static int vsprintf_help(unsigned c, void **ptr)
{
	char *dst;

	dst = *ptr;
	*dst++ = (char)c;
	*ptr = dst;
	return 0 ;
}

int vsprintf(char *buf, const char *fmt, va_list args)
{
	int rv;

	rv = do_printf(fmt, args, vsprintf_help, (void *)buf);
	buf[rv] = '\0';
	return rv;
}

int sprintf(char *buf, const char *fmt, ...)
{
	va_list args;
	int rv;

	va_start(args, fmt);
	rv = vsprintf(buf, fmt, args);
	va_end(args);
	return rv;
}

#include <asm.h>

int vdprintf_help(unsigned c, void **ptr)
{
	out8(0x3f8, c);
	return 0 ;
}

int vdprintf(const char *fmt, va_list args)
{
	return do_printf(fmt, args, vdprintf_help, NULL);
}

int dprintf(const char *fmt, ...)
{
	va_list args;
	int rv;

	va_start(args, fmt);
	rv = vdprintf(fmt, args);
	va_end(args);
	return rv;
}

int printf(const char *fmt, ...)
{
	va_list args;
	int rv;

	va_start(args, fmt);
	rv = vdprintf(fmt, args);
	va_end(args);
	return rv;
}

/* <string.h> */

void *memcpy(void *d, const void *s, size_t n) {
  void *d0 = d;
  if (s != d)
	for (; 0 != n; --n)
	  *(char*)d++ = *(char*)s++;
  return d0;
}

void *memmove(void* d, const void* s, size_t n)
{
  unsigned char *dest = (unsigned char *)d;
  unsigned char *src = (unsigned char *)s;
  
  if (src < dest)
	for (src += n, dest += n; 0 != n; --n)
	  *--dest = *--src;
  else if (src != dest)
	for (; 0 != n; --n)
	  *dest++ = *src++;
  return d;
}

void *memset(void *d, int c, size_t n) {
  void *d0 = d;
  unsigned char b = (unsigned char)c;
  for (; n > 0; --n)
	*(unsigned char*)d++ = b;
  return d0;
}

int memcmp(const void *s1, const void *s2, size_t n) {
  int i = 0;
  const unsigned char *c1 = s1, *c2 = s2;
  int result = 0;

  /* Invariant: result == memcmp(s1, s2, i). */
  for (; i < n && result == 0; ++i)
	result = c1[i] - c2[i];
  return result;
}

int strcmp(const unsigned char *s1, const unsigned char *s2) {
  for (; (*s1 != '\0') && (*s2 != '\0') && (*s1 == *s2); ++s1, ++s2)
	;
  return (*s1 - *s2);
}

char *strcpy(char *dest, const char *src)
{
  char * tmp = dest;
  for (; (*dest = *src) != 0; ++dest, ++src);
  return tmp;
}

size_t strlen(const char *str) {
  size_t len = 0;

  if ( str == 0 ) return 0;

  while (*str++) ++len;

  return len;
}

char *strcat(char *s1, const char *s2) {
	int len1 = strlen(s1), len2 = strlen(s2);
	char *tmp = (char *)malloc(len1 + len2 + 1);
  strcpy(tmp, s1);
	strcpy(tmp + len1, s2);
	tmp[len1+len2] = '\0';
  return tmp;
}

char *strerror(int errnum) {
	return "unknown error";
}

char *strdup(const char *s) {
	int len = strlen(s);
	char *d = (char *)malloc(len + 1);
	strcpy(d,s);
	d[len] = '\0';
	return d;
}

int strncmp(const char *cs, const char *ct, size_t count)
{
	signed char __res = 0;

	while (count) {
		if ((__res = *cs - *ct++) != 0 || !*cs++)
			break;
		count--;
	}
	return __res;
}

/* strtod */

static unsigned char isspace(char c)
{
	return (c == ' ' || c == '\t' || c == '\r' || c == '\n');
}

static char tolower(char c)
{
	if (c >= 'A' || c <= 'Z')
	{
		return c + 'A' - 'a';
	}
	else
	{
		return c;
	}
}

static unsigned char valid_float_char(char c)
{
	return (c == '-' || c == '+' || c == '.' || c == 'x' || c == 'X' || isdigit(c) || c == 'e' || c == 'E');
}

/* isnan & isinf */

#define abs(x) (x < 0 ? -x : x)

double expd(unsigned char base, int pos)
{
	double result = 1.0;
	int i;
	
	for (i = 0; i < abs(pos); i++) {
		if (pos > 0) {
			result *= base;
		} else {
			result /= base;
		}
	}
	
	return result;
}

double strtod(const char *nptr, char **endptr)
{
#define INITIAL 0
#define SUBJECT 1
	int state = INITIAL;
	char subject[1024];
	int i = 0;
	int j = 0;
	int k = 0;
	unsigned char sign = 0;
	unsigned char base = 10;
	int exponent = 0;
	int unitpos = 0;
	int exppos = 0;
	unsigned char expsign = 0;
	double val;
	
	for (i = 0; i < strlen(nptr); i++, k++)
	{
		if (state == INITIAL)
		{
			if (!isspace(nptr[i]))
			{
				state = SUBJECT;
				/*
				if (isnan(&nptr[i]))
				{
					*val = NAN;
					strcpy(subject, "");
					break;
				} else if (isinf(&nptr[i])) {
					*val = INFINITY;
					strcpy(subject, "");
					break;
				}
				*/
			}
		}
		if (state == SUBJECT)
		{
			if (!valid_float_char(nptr[i]))
			{
				subject[j] = '\0';
				j++;
				/*if (endptr)
				{
					for (k = i; i < strlen(nptr) + 1; i++)
					{
						*endptr[i-k] = nptr[i];
					}
				}*/
				break;
			}
			if (tolower(nptr[i]) == 'e')
			{
				exppos = j;
			}
			else if (isdigit(nptr[i]))
			{
				subject[j] = nptr[i];
				j++;
			}
			else if (nptr[i] == '-')
			{
				if (j == 0)
				{
					sign = 1;
				}
				else
				{
					expsign = 1;
				}
			}
			else if (tolower(nptr[i]) == 'x')
			{
				base = 16;
			}
			else if (nptr[i] == '.')
			{
				unitpos = j - 1;
			}
		}
	}
	if (!exppos)
	{
		exppos = j - 1;
	}
	val = 0.0;
	if (strcmp(subject, ""))
	{
		for (i = 0; i < exppos; i++)
		{
			val += expd(base, unitpos - i) * (subject[i] - '0');
		}
		if (exponent)
		{
			if (!expsign)
			{
				val *= expd(base, exponent);
			}
			else
			{
				val *= expd(base, -exponent);
			}
		}
	}
	else
	{
		if (endptr)
		{
			/*strcpy(*endptr, nptr);*/
		}
	}
	
	if (sign)
	{
		val = -val;
	}
	
	*endptr = (char *)nptr + k;
		
	return val;
}

/* <signal.h> */

#include <signal.h>

void sigemptyset(sigset_t *set) {
	*set = 0;
}

void sigaddset(sigset_t *set, int signum) {
	*set |= (1 << signum);
	if (signum >= 8) {
		*set |= (1 << 2);
	}
}

void sigdelset(sigset_t *set, int signum) {
	*set &= ~(1 << signum);
	if (signum >= 8) {
		*set &= ~(1 << 2);
	}
}

extern unsigned int signal_mask;

extern void update_mask();

void sigprocmask(mask_t mask, sigset_t *set, sigset_t *oldset) {
	if (oldset) *oldset = signal_mask;
	switch (mask) {
		case SIG_BLOCK:
			signal_mask |= *set;
			break;
		case SIG_UNBLOCK:
			signal_mask &= ~(*set);
			break;
		case SIG_SETMASK:
			signal_mask = *set;
			break;
	}
	update_mask();
}

extern void set_signal_handler(int, struct sigaction *, struct sigaction *);

int sigaction(int signum, struct sigaction *sa, struct sigaction *oldsa) {
	set_signal_handler(signum, sa, oldsa);
	/* should the mask be updated? */
	sigset_t set;
	sigemptyset(&set);
	sigaddset(&set, signum);
	sigprocmask(SIG_UNBLOCK, &set, NULL);
	return 0;
}

void printk(const char *fmt, ...)
{
}

/* from freebsd 7 */
char *strstr(const char *s, const char *find)
{
	char c, sc;
	size_t len;

	if ((c = *find++) != 0) {
		len = strlen(find);
		do {
			do {
				if ((sc = *s++) == 0)
					return (NULL);
			} while (sc != c);
		} while (strncmp(s, find, len) != 0);
		s--;
	}
	return ((char *)s);
}

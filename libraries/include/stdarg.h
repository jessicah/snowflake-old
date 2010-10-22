#ifndef _STDARG_H
#define _STDARG_H

#if (__GNUC__ > 2) || ((__GNUC__ == 2) && (__GNUC_MINOR__ >= 96))

typedef __builtin_va_list va_list;
#if (__GNUC__ > 4) || ((__GNUC__ == 4) && (__GNUC_MINOR__ >= 4))
#define va_start(v,l)	__builtin_va_start((v),l)
#else
#define va_start(v,l)	__builtin_stdarg_start((v),l)
#endif
#define va_end		__builtin_va_end
#define va_arg		__builtin_va_arg
#define __va_copy(d,s)	__builtin_va_copy((d),(s))

#else
#error stdarg.h requires GCC >= 2.96
#endif

#endif

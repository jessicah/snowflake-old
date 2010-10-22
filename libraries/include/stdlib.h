#include <stddef.h>

#ifdef __GNUC__
  /* Works only in GCC 2.5 and later */
  #define Noreturn __attribute__ ((noreturn))
#else
  #define Noreturn
#endif

void free(void *ptr);
void *realloc(void *ptr, size_t size);
void *malloc(size_t size);
void *calloc(size_t elements, size_t size);
void *memalign(size_t boundary, size_t size);
int atoi(const char *nptr);
double strtod(const char *nptr, char **endptr);
void exit(int status) Noreturn;

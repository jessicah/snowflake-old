#include <stddef.h>

int strcmp(const char *s1, const char *s2);
void *memcpy(void *dest, const void *src, size_t n);
char *strcpy(char *dest, const char *src);
size_t strlen(const char *s);
void *memmove(void *dest, const void *src, size_t n);
char *strerror(int errnum);
void *memset(void *s, int c, size_t n);
char *strcat(char *dest, const char *src);
int memcmp(const void *s1, const void *s2, size_t n);
char *strdup(const char *);
int strncmp(const char *s1, const char *s2, size_t count);

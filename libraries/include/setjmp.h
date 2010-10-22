/* need a jmp_buf type */
/* setjmp(jmp_buf) */
/* longjmp(jmp_buf,int) */

#ifndef __SNOWFLAKE_SETJMP_H
#define __SNOWFLAKE_SETJMP_H

typedef int __jmp_buf[6]; /* hope this is right */

typedef struct __jmp_buf_tag
  {
    __jmp_buf __jmpbuf;		/* Calling environment.  */
  } jmp_buf[1];

int setjmp(jmp_buf env);
void longjmp(jmp_buf env, int val);

#endif

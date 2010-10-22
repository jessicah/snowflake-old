#ifndef _SIGNAL_H
#define _SIGNAL_H

#define SIG_DFL (sighandler_t)0
#define SIG_IGN (sighandler_t)1

#define NSIG 64

/* an unsigned int is 32 bits, plenty for us :) */

typedef enum { SIG_BLOCK, SIG_UNBLOCK, SIG_SETMASK } mask_t;

typedef unsigned int sigset_t;

typedef void (*sighandler_t)(int);

struct sigaction {
	sighandler_t sa_handler;
	int sa_flags;
	sigset_t sa_mask;
};

extern void sigemptyset(sigset_t *);
extern void sigaddset(sigset_t *, int);
extern void sigdelset(sigset_t *, int);
extern void sigprocmask(mask_t, sigset_t *, sigset_t *);
extern int sigaction(int, struct sigaction *, struct sigaction *);

#endif

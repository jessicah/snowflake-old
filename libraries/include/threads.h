#ifndef _THREADS_H
#define _THREADS_H

#include <list.h>

#define RUNNABLE 0
#define BLOCKED 1
#define KILLED 2
#define EXITED 4

typedef struct thread {
	unsigned long *stack;
	unsigned long *esp;
	void *slot;
	unsigned long id;
	unsigned long status;
	
	/* Doubly-linked list of threads in the system */
	link_t global_link;
	/* Doubly-linked list of ready to run threads */
	link_t run_link;
} real_thread_t;

/* Pointer to emulate unique thread ID semantics of pthread_t */
typedef real_thread_t *thread_t;

typedef struct waitqueue_node {
	thread_t thread;
	link_t link;
} waitqueue_node_t;

typedef struct mutex {
	link_t waitqueue_head;
	thread_t owner;
	unsigned long id;
} mutex_t;

typedef struct cond {
	link_t waitqueue_head;
	unsigned long id;
} cond_t;

typedef void *(*thread_func)(void *);

extern void thread_init();
extern void thread_yield();
extern void thread_exit(void *);
extern void thread_create(thread_t *, void *(*)(void *), void *);
extern thread_t thread_self();
extern void thread_setspecific(void *);
extern void *thread_getspecific();
extern void thread_sleep();
extern void thread_wake(thread_t);

//extern mutex_t *mutex_create();
extern void mutex_init(mutex_t *);
extern void mutex_destroy(mutex_t *);
extern void mutex_lock(mutex_t *);
extern void mutex_unlock(mutex_t *);
extern int mutex_trylock(mutex_t *);
extern void mutex_unsafe_lock(mutex_t *);
extern void mutex_unsafe_unlock(mutex_t *);

//extern cond_t *cond_create();
extern void cond_init(cond_t *);
extern void cond_destroy(cond_t *);
extern void cond_wait(cond_t *, mutex_t *);
extern void cond_signal(cond_t *);
extern void cond_broadcast(cond_t *);

static inline long interrupts_disable(void)
{
	long eflags;
	asm volatile("pushf;cli;pop %0":"=rm"(eflags));
	return eflags & 0x200;
}

static inline void interrupts_enable(void)
{
	asm volatile("sti;nop");
}

/* Restore from disabled interrupts to state */
static inline void interrupts_restore(long state)
{
	if(state) {
		interrupts_enable();
	}
}

#endif

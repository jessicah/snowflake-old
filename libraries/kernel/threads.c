
#include <asm.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include "threads.h"

extern void _thread_switch_stacks(unsigned long *new_esp, unsigned long **old_esp);

static void *do_idle(void *);
static void *do_reaper(void *);

static unsigned long next_id = 0;

static LIST_INITIALIZE(all_threads);
static LIST_INITIALIZE(run_queue);
static LIST_INITIALIZE(zombie_list);
static real_thread_t *current;

static real_thread_t kernel_thread;
static thread_t idle_thread;
/* Reaper: Slayer of dead threads */
static thread_t reaper_thread;

void thread_init() {
	/* Kernel thread is special, it already has a stack and is currently running */
	kernel_thread.id = next_id++;
	kernel_thread.status = RUNNABLE;
	link_initialize(&kernel_thread.run_link);
	link_initialize(&kernel_thread.global_link);
	list_insert_prev(&kernel_thread.global_link, &all_threads);
	kernel_thread.slot = NULL;
	current = &kernel_thread;
	
	thread_create(&idle_thread, do_idle, NULL);
	thread_create(&reaper_thread, do_reaper, NULL);
}

static void schedule(void)
{
	/* Save the current state of IF and disable interrupts */
	long intr_state = interrupts_disable();
	real_thread_t *previous = current;
	
	/* Possibly put the thread back on the run queue
	 * The idle thread is special, it never goes on the run queue */
	if(current != idle_thread) {
		switch(current->status) {
		case RUNNABLE:
			/* Place on the end of the run queue */
			list_append(&current->run_link, &run_queue);
			break;
		case BLOCKED:
			/* Nothing */
			break;
		case KILLED:
		case EXITED:
			/* The thread is dead but cannot be freed here because 
			 * we're currently running on it's stack
			 * Prepare it for deletion and wake Reaper */
			list_append(&current->run_link, &zombie_list);
			if(reaper_thread->status == BLOCKED) {
				reaper_thread->status = RUNNABLE;
				list_append(&reaper_thread->run_link, &run_queue);
			}
			break;
		default:
			dprintf("schedule: Aiee! invalid thread state %u in %u/%x\r\n", current->status, current->id, (long)current);
			assert(0);
		}
	}
	
	/* Pick a new thread to run */
	if(list_empty(&run_queue)) {
		/* Nothing to run, schedule the idle thread */
		#ifdef DEBUG_SCHEDULER
		dprintf("thread = idle\r\n");
		#endif
		current = idle_thread;
	} else {
		/* Pull it from the front of the run queue */
		current = list_get_instance(run_queue.next, real_thread_t, run_link);
		list_remove(&current->run_link);
		#ifdef DEBUG_SCHEDULER
		dprintf("thread = other\r\n");
		#endif
	}
	
	if(previous == current) {
		/* Nothing to do, early return now to avoid the stack switch code */
		#ifdef DEBUG_SCHEDULER
		dprintf("return to self\r\n");
		#endif
		interrupts_restore(intr_state);
		return;
	}
	
	#ifdef DEBUG_SCHEDULER
	dprintf("return to selected\r\n");
	#endif
	/* MAGIC! */
	_thread_switch_stacks(current->esp, &previous->esp);
	/* Now we're running on current's stack, so local variable have changed
	 * intr_state now holds the IF state for this thread, not the previous thread */
	interrupts_restore(intr_state);
}

void thread_yield(void) {
	schedule();
}

void thread_exit(void *retval) {
#ifdef DEBUG_THREADS
	dprintf("t %d:%x exited\r\n", current->id, current->stack);
#endif
	/* Signal schedule that this thread has exited */
	current->status = EXITED;
	schedule();
	/* Can't reach here */
	assert(0);
}

#define STACK_SIZE 16384

static void thread_entry_trampoline(void *(*closure)(void *), void *arg)
{
	interrupts_enable();
	thread_exit(closure(arg));
}

void thread_create(thread_t *thread, void *(*closure)(void *), void *arg) {
	*thread = malloc(sizeof(real_thread_t));
	(*thread)->id = next_id++;
	(*thread)->status = RUNNABLE;
	(*thread)->slot = NULL;
	(*thread)->stack = (unsigned long *)malloc(STACK_SIZE * sizeof(unsigned long));
	(*thread)->esp = (*thread)->stack + STACK_SIZE;
	
	memset((*thread)->stack, 0, STACK_SIZE * sizeof(unsigned long));
	
	link_initialize(&(*thread)->run_link);
	link_initialize(&(*thread)->global_link);
	
	/* Set up the stack for _thread_switch_stacks */
	*--(*thread)->esp = (unsigned long)arg;                      /* Argument 2 for the trampoline */
	*--(*thread)->esp = (unsigned long)closure;                  /* Argument 1 for the trampoline */
	*--(*thread)->esp = 0;                                       /* Return address */
	*--(*thread)->esp = (unsigned long)thread_entry_trampoline;  /* EIP/_stack_switch return address */
	*--(*thread)->esp = 0;                                       /* EBP */
	*--(*thread)->esp = 0;                                       /* EBX */
	*--(*thread)->esp = 0;                                       /* ESI */
	*--(*thread)->esp = 0;                                       /* EDI */
	
	long istate = interrupts_disable();
	list_append(&(*thread)->global_link, &all_threads);
	list_append(&(*thread)->run_link, &run_queue);
	interrupts_restore(istate);
#ifdef DEBUG_THREADS
	dprintf("t %d:%x:%x created\r\n", (*thread)->id, (*thread)->stack, thread);
#endif
}

thread_t thread_self() {
	return current;
}

void thread_setspecific(void *data) {
	current->slot = data;
}

void *thread_getspecific() {
	return current->slot;
}

void thread_sleep()
{
	dprintf("thread %d sleeping\r\n", current->id);
	current->status = BLOCKED;
	schedule();
}

void thread_wake(thread_t t)
{
	dprintf("thread %d being woken up by %d\r\n", t->id, current->id);
	t->status = RUNNABLE;
	list_append(&t->run_link, &run_queue);
}

static void *do_idle(void *a)
{
	while(1) {
		thread_yield();
		asm volatile("hlt");
	}
}

static void *do_reaper(void *a)
{
	thread_t thread;
	
	interrupts_disable();
	
	while(1) {
		while(!list_empty(&zombie_list)) {
			/* kill each thread off */
			thread = list_get_instance(zombie_list.next, real_thread_t, run_link);
			list_remove(&thread->run_link);
			list_remove(&thread->global_link);
			free(thread->stack);
			free(thread);
		}
		/* Now sleep */
		current->status = BLOCKED;
		schedule();
	}
}

/* thread synchronisation primitives */

static void wait_on(link_t *head)
{
	waitqueue_node_t volatile node;
	
	/* Create new node */
	link_initialize((link_t *)&node.link);
	node.thread = current;
	
	/* Add to waiting threads list */
	list_append((link_t *)&node.link, head);
	
	/* Sleep */
	current->status = BLOCKED;
	schedule();
}

static void wake_first(link_t *head)
{
	waitqueue_node_t *node;
	
	if(list_empty(head)) {
		return;
	}
	
	/* Take the first node off the list */
	node = list_get_instance(head->next, waitqueue_node_t, link);
	list_remove(&node->link);
	
	/* And wake up that thread */
	assert(node->thread->status == BLOCKED);
	node->thread->status = RUNNABLE;
	list_append(&node->thread->run_link, &run_queue);
#ifdef DEBUG_THREADS	
	dprintf("w %x woke thread %d\r\n", (long)head, node->thread->id);
#endif
}

static void wake_all(link_t *head)
{
	waitqueue_node_t *node;
	
	/* Iterate over and remove every node */
	while(!list_empty(head)) {
		/* Take the first node off the list */
		node = list_get_instance(head->next, waitqueue_node_t, link);
		list_remove(&node->link);
		
		/* And wake up that thread */
		assert(node->thread->status == BLOCKED);
		node->thread->status = RUNNABLE;
		list_append(&node->thread->run_link, &run_queue);
	}
}

void mutex_init(mutex_t *mutex) {
	list_initialize(&mutex->waitqueue_head);
	mutex->owner = NULL;
	mutex->id = next_id++;
#ifdef DEBUG_THREADS
	dprintf("m %d:%d %x init\r\n", mutex->id, current->id, (long)mutex);
#endif
}

void mutex_destroy(mutex_t *mutex) {
#ifdef DEBUG_THREADS
	dprintf("m %d:%d %x destroyed\r\n", mutex->id, current->id, (long)mutex);
#endif
	/* Should not be anything waiting */
	assert(list_empty(&mutex->waitqueue_head));
}

void mutex_lock(mutex_t *mutex) {
	long istate = interrupts_disable();
#ifdef DEBUG_THREADS
	dprintf("m %d:%d %x locking\r\n", mutex->id, current->id, (long)mutex);
#endif
	
	/* Check for recursive locking */
	assert(mutex->owner != current);
	
	while(mutex->owner) {
		/* Locked by something else */
#ifdef DEBUG_THREADS
		dprintf("m %d:%d %x locked by %d\r\n", mutex->id, current->id, mutex->owner->id, (long)mutex);
#endif
		wait_on(&mutex->waitqueue_head);
	}
	
	mutex->owner = current;
#ifdef DEBUG_THREADS
	dprintf("m %d:%d %x locked\r\n", mutex->id, current->id, (long)mutex);
#endif
	interrupts_restore(istate);
}

void mutex_unsafe_lock(mutex_t *mutex) {
	long istate = interrupts_disable();
	while (mutex->owner) {
		wait_on(&mutex->waitqueue_head);
	}
	mutex->owner = current;
	interrupts_restore(istate);
}

void mutex_unlock(mutex_t *mutex) {
	long istate = interrupts_disable();
	
	/* Ensure the mutex is locked by us */
	assert(mutex->owner == current);
	
	/* Wake the first thread */
	wake_first(&mutex->waitqueue_head);
#ifdef DEBUG_THREADS
	dprintf("m %d:%d %x unlocked\r\n", mutex->id, current->id, (long)mutex);
#endif
	mutex->owner = NULL;
	interrupts_restore(istate);
}

void mutex_unsafe_unlock(mutex_t *mutex) {
	long istate = interrupts_disable();
	wake_first(&mutex->waitqueue_head);
	mutex->owner = NULL;
	interrupts_restore(istate);
}

int mutex_trylock(mutex_t *mutex) {
	long istate = interrupts_disable();
	int retcode = -1;
	if(mutex->owner == NULL) {
		mutex->owner = current;
		retcode = 0;
	}
#ifdef DEBUG_THREADS
	dprintf("m %d:%d %x try lock = %d\r\n", mutex->id, current->id, (long)mutex, retcode);
#endif
	interrupts_restore(istate);
	return retcode;
}

void cond_init(cond_t *cond) {
	list_initialize(&cond->waitqueue_head);
	cond->id = next_id++;
#ifdef DEBUG_THREADS
	dprintf("c %d:%d init\r\n", cond->id, current->id);
#endif
}

void cond_destroy(cond_t *cond) {
#ifdef DEBUG_THREADS
	dprintf("c %d:%d destroyed\r\n", cond->id, current->id);
#endif
	/* Should not be anything waiting */
	assert(list_empty(&cond->waitqueue_head));
}

/* cvar wait:
 * atomicly /drop mutex
 *          \start waiting
 *   <woken up>
 *   retake mutex */
void cond_wait(cond_t *cond, mutex_t *mutex) {
	/* Go atomic */
	long istate = interrupts_disable();
#ifdef DEBUG_THREADS
	dprintf("c %d:%d waiting\r\n", cond->id, current->id);
#endif
	mutex_unlock(mutex);
	wait_on(&cond->waitqueue_head);
	mutex_lock(mutex);
#ifdef DEBUG_THREADS
	dprintf("c %d:%d resumed\r\n", cond->id, current->id);
#endif
	interrupts_restore(istate);
}

void cond_signal(cond_t *cond) {
	long istate = interrupts_disable();
#ifdef DEBUG_THREADS
	dprintf("c %d:%d signalled\r\n", cond->id, current->id);
#endif
	wake_first(&cond->waitqueue_head);
	interrupts_restore(istate);
}

void cond_broadcast(cond_t *cond) {
	long istate = interrupts_disable();
#ifdef DEBUG_THREADS
	dprintf("c %d:%d broadcasted\r\n", cond->id, current->id);
#endif
	wake_all(&cond->waitqueue_head);
	interrupts_restore(istate);
}

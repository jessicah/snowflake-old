
#include "idt.h"

#include <asm.h>
#include <stdio.h>
#include <signal.h>

/* interrupts use interrupt gates */
/* exceptions use trap gates */

/* interrupt gate:

   0-15: offset (low)
	 16-31: segment selector
	 32-36: reserved (zero)
	 37-39: zero
	 40-44: 01110
	 45-46: DPL (0x00, ring 0)
	 47: 1 (present)
	 48-63: offset (high)

	 task gate:
	 
	 same as interrupt gate, with bit 40 set to 1
*/

unsigned short signal_mask = 0xFFFF;

void update_mask() {
	//dprintf("updating signal mask: %4x\n", signal_mask);
	
	out8(PICMI, signal_mask & 0xFF);
	out8(PICSI, signal_mask >> 8);
}

void unmask_irq(unsigned char irq) {
	signal_mask &= ~(1 << irq);
	if (irq >= 8) {
		signal_mask &= ~(1 << 2);
	}
}

void mask_irq(unsigned char irq) {
	signal_mask |= (1 << irq);
}

struct gate {
	unsigned short offset_lo;
	unsigned short selector;
	unsigned short flags;
	unsigned short offset_hi;
} __attribute__ ((packed));

static struct gate descriptors[256];
	
void set_vector(unsigned char vector, interrupt_handler handler, gate_type type) {
	/* interrupt gate is 0x8E00, trap gate is 0x8E00 | 0x100 */
	struct address {
		unsigned short offset_lo;
		unsigned short offset_hi;
	};
	union {
		interrupt_handler handler;
		struct address address;
	} entry;
	
	entry.handler = handler;
	
	descriptors[vector].offset_lo = entry.address.offset_lo;
	descriptors[vector].selector = 0x08;
	descriptors[vector].flags = type == interrupt ? 0x8E00 : 0x8F00;
	descriptors[vector].offset_hi = entry.address.offset_hi;
}

void set_irq(unsigned char irq, interrupt_handler handler) {
	if (irq >= 8) {
		set_vector(irq + SLAVE - 8, handler, interrupt);
	} else {
		set_vector(irq + MASTER, handler, interrupt);
	}
	signal_mask &= ~(1 << irq);
	update_mask();
}

#define MK_E(n, msg)			\
void exception##n() {			\
	dprintf(msg);						\
	stacktrace();			\
	while (1) {							\
		asm volatile("cli");	\
		asm volatile("hlt");	\
	}												\
}

#define E(n) set_vector(n, exception##n, trap)

static void stacktrace(void)
{
	struct frame {
		struct frame *next;
		void *return_addr;
	};
	struct frame *frame;
	int depth = 0;
	
	__asm__ volatile("movl	%%ebp, %0" : "=rm"(frame));
	
	while(frame && depth++ < 50) {
		dprintf("%08x [%08p]\r\n", frame->return_addr, frame);
		frame = frame->next;
		if((unsigned int)frame < 0x1000 || (unsigned int)frame >= 0xFFFFF000) {
			break;
		}
	}
}

MK_E(0, "Divide by zero")
MK_E(1, "Debug exception")
MK_E(2, "Reserved exception")
MK_E(3, "Unexpected breakpoint")
MK_E(4, "Overflow error")
MK_E(5, "Bounds check error")
MK_E(6, "Invalid opcode")
MK_E(7, "Coprocessor not available")
MK_E(8, "Double fault")
MK_E(9, "Coprocessor segment overflow")
MK_E(10, "Invalid TSS")
MK_E(11, "Segment not present")
MK_E(12, "Stack exception")
void exception13(unsigned int eip, unsigned short cs, unsigned int eflags) {
	dprintf("General protection fault\r\n");
	dprintf("EFLAGS: %08X\r\n", eflags);
	dprintf("CS: %02X\r\n", cs);
	dprintf("EIP: %08X\r\n", eip);
	stacktrace();
	while (1) {
		asm volatile("cli");
		asm volatile("hlt");
	}
}
void exception14(unsigned int eip, unsigned short cs, unsigned int eflags) {
	unsigned int cr2;
	asm volatile("mov %%cr2, %0" : "=r"(cr2));
	dprintf("Page fault\r\n");
	dprintf("EFLAGS: %08X\r\n", eflags);
	dprintf("CS: %02X\r\n", cs);
	dprintf("EIP: %08X\r\n", eip);
	dprintf("CR2: %08X\r\n", cr2);
	stacktrace();
	while (1) {
		asm volatile("cli");
		asm volatile("hlt");
	}
}
MK_E(15, "Unknown exception")
MK_E(16, "Coprocessor error")

void default_handler(int n) {
	if (n < 16) {
		out8(0x20, 0x20);
		if (n > 7) {
			out8(0x20, 0xA0);
		}
	}
}

static void ignore_handler(int n) {
	/* do nothing */
}

sighandler_t signal_handlers[16] = {
		default_handler, default_handler, default_handler, default_handler,
		default_handler, default_handler, default_handler, default_handler,
		default_handler, default_handler, default_handler, default_handler,
		default_handler, default_handler, default_handler, default_handler,
	};


void set_signal_handler(int signum, struct sigaction *sa, struct sigaction *oldsa) {
	if (oldsa) {
		if (signal_handlers[signum] == default_handler) {
			oldsa->sa_handler = SIG_DFL;
		} else if (signal_handlers[signum] == ignore_handler) {
			oldsa->sa_handler = SIG_IGN;
		} else {
			oldsa->sa_handler = signal_handlers[signum];
		}
	}
	if (sa) {
		if (sa->sa_handler == SIG_DFL) {
			#ifdef DEBUG_THREADS
			dprintf("setting to default handler\r\n");
			#endif
			signal_handlers[signum] = default_handler;
		} else if (sa->sa_handler == SIG_IGN) {
			#ifdef DEBUG_THREADS
			dprintf("setting to ignore\r\n");
			#endif
			signal_handlers[signum] = ignore_handler;
		} else {
			#ifdef DEBUG_THREADS
			dprintf("installing a signal handler for irq %d\r\n", signum);
			#endif
			signal_handlers[signum] = sa->sa_handler;
		}
	} else {
		signal_handlers[signum] = default_handler;
	}
	#ifdef DEBUG_THREADS
	dprintf("set_signal_handler\r\n");
	#endif
}

#define EI(n) extern irq##n();
#define I(n) set_irq(n, (interrupt_handler)irq##n);

EI(0);
EI(1);
EI(2);
EI(3);
EI(4);
EI(5);
EI(6);
EI(7);
EI(8);
EI(9);
EI(10);
EI(11);
EI(12);
EI(13);
EI(14);
EI(15);

void idt_init() {
	int i;
	
	out8(PICM, ICW1);
	out8(PICS, ICW1);
	out8(PICMI, MASTER);
	out8(PICSI, SLAVE);
	out8(PICMI, 4);
	out8(PICSI, 2);
	out8(PICMI, ICW4);
	out8(PICSI, ICW4);
	out8(PICMI, 0xFB);
	out8(PICSI, 0xFF);
	
	/* set the exception handlers */
	E(0);
	E(1);
	E(2);
	E(3);
	E(4);
	E(5);
	E(6);
	E(7);
	E(8);
	E(9);
	E(10);
	E(11);
	E(12);
	set_vector(13, (interrupt_handler)exception13, trap);
	set_vector(14, (interrupt_handler)exception14, trap);
	E(15);
	E(16);
	
	for (i = 17; i < 32; ++i) {
		E(15);
	}
	
	/* set the interrupt handlers */
	
	for (i = 32; i < 256; ++i) {
		set_vector(i, default_handler, interrupt);
	}
	
	I(0);
	I(1);
	I(2);
	I(3);
	I(4);
	I(5);
	I(6);
	I(7);
	I(8);
	I(9);
	I(10);
	I(11);
	I(12);
	I(13);
	I(14);
	I(15);
	
	signal_mask = 0xFFFF;
	
	struct {
		unsigned short size  __attribute__ ((packed));
		unsigned long offset __attribute__ ((packed));
	} descriptor;
	
	descriptor.size = 256 * 8 - 1;
	descriptor.offset = (unsigned long)descriptors;
	
	asm volatile("lidt %0" :: "m" (descriptor));
}

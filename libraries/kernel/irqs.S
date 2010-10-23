
.global irq0
.global irq1
.global irq2
.global irq3
.global irq4
.global irq5
.global irq6
.global irq7
.global irq8
.global irq9
.global irq10
.global irq11
.global irq12
.global irq13
.global irq14
.global irq15

.extern signal_handlers

#define IRQ(a,b) 							\
irq##a:												\
	pusha;												\
	movl $signal_handlers, %eax;	\
	push $##a;										\
	call *##b##(%eax);						\
	addl $4, %esp;								\
	popa;												\
	iret

irq0:
	pusha
	movl $signal_handlers, %eax
	push $0
	call *0(%eax)
	addl $4, %esp
	popa
	iret

IRQ(1,4)
IRQ(2,8)
IRQ(3,12)
IRQ(4,16)
IRQ(5,20)
IRQ(6,24)
IRQ(7,28)
IRQ(8,32)
IRQ(9,36)
IRQ(10,40)
IRQ(11,44)
IRQ(12,48)
IRQ(13,52)
IRQ(14,56)
IRQ(15,60)

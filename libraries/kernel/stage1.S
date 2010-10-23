
.global __entrypoint

.set ALIGN,				1 << 0
.set MEMINFO,			1 << 1
.set FLAGS,				ALIGN | MEMINFO
.set MAGIC,				0x1BADB002
.set PADDING,			0
.set CHECKSUM,		-(MAGIC + FLAGS)

.section .mb_header
.align 4
.long MAGIC
.long FLAGS
.long CHECKSUM
.long PADDING

.section .text
.set STACKSIZE, 0x40000
.comm stack, STACKSIZE, 32

__entrypoint:
	mov $(stack + STACKSIZE), %esp
	push %eax
	push %ebx
	
	lgdt (gdt_ptr)
	ljmp $0x08, $new_gdt
new_gdt:
	mov $0x10, %ax
	mov %eax, %ds
	mov %eax, %ss
	mov %eax, %es
	mov %eax, %fs
	mov %eax, %gs
	
	xor %ebp, %ebp
	
	movl $33, %eax
	movl %eax, %cr0
	fninit
	call __startup

5:
	hlt
	jmp 5b

.section .data

gdt:
	# null descriptor
	.word 0
	.word 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	# ring 0 kernel code segment descriptor (0x08)
	.word 0xFFFF
	.word 0
	.byte 0
	.byte 0x9A
	.byte 0xCF
	.byte 0
	# ring 0 kernel data segment descriptor (0x10)
	.word 0xFFFF
	.word 0
	.byte 0
	.byte 0x92
	.byte 0xCF
	.byte 0
gdt_end:

gdt_ptr:
	.word gdt_end - gdt - 1
	.long gdt

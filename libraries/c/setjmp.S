#include "i386mach.S"

.global _setjmp
.global setjmp
.global longjmp

_setjmp:
setjmp:
    movl	4(esp),eax
	movl	0(esp),edx
	movl	edx, 0(eax)		/* rta */
	movl	ebx, 4(eax)
	movl	esp, 8(eax)
	movl	ebp,12(eax)
	movl	esi,16(eax)
	movl	edi,20(eax)
	xorl	eax,eax
	ret

longjmp:
    movl	4(esp),edx
	movl	8(esp),eax
	movl	0(edx),ecx
	movl	4(edx),ebx
	movl	8(edx),esp
	movl	12(edx),ebp
	movl	16(edx),esi
	movl	20(edx),edi
	testl	eax,eax
	jnz	1f
	incl	eax
1:	movl	ecx,0(esp)
	ret


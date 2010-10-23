
#include <x86emu.h>
#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <asm.h>
#include <string.h>
#include <stdio.h>

static u8 x86emu_inb(X86EMU_pioAddr addr)
{ return in8(addr); }
static u16 x86emu_inw(X86EMU_pioAddr addr)
{ return in16(addr); }
static u32 x86emu_inl(X86EMU_pioAddr addr)
{ return in32(addr); }
static void x86emu_outb(X86EMU_pioAddr addr, u8 val)
{ out8(addr, val); }
static void x86emu_outw(X86EMU_pioAddr addr, u16 val)
{ out16(addr, val); }
static void x86emu_outl(X86EMU_pioAddr addr, u32 val)
{ out32(addr, val); }

static u8 x86emu_rdb(u32 addr)
{ return *(u8 *)(addr); }
static u16 x86emu_rdw(u32 addr)
{ return *(u16 *)(addr); }
static u32 x86emu_rdl(u32 addr)
{ return *(u32 *)(addr); }
static void x86emu_wrb(u32 addr, u8 val)
{ *(u8 *)(addr) = val; }
static void x86emu_wrw(u32 addr, u16 val)
{ *(u16 *)(addr) = val; }
static void x86emu_wrl(u32 addr, u32 val)
{ *(u32 *)(addr) = val; }

static X86EMU_pioFuncs x86emu_piofuncs = { x86emu_inb, x86emu_inw, x86emu_inl, x86emu_outb, x86emu_outw, x86emu_outl };
static X86EMU_memFuncs x86emu_memfuncs = { x86emu_rdb, x86emu_rdw, x86emu_rdl, x86emu_wrb, x86emu_wrw, x86emu_wrl };

static int x86emu_setup = 0;

static void bios_interrupt(unsigned char num, X86EMU_regs *regs)
{
	if (!x86emu_setup) {
		X86EMU_setupPioFuncs(&x86emu_piofuncs);
		X86EMU_setupMemFuncs(&x86emu_memfuncs);
		x86emu_setup = 1;
	}
	
	memset(&M, 0, sizeof M);
	M.x86 = *regs;
	/* Mmmm, fixed addresses */
	M.x86.R_SS = 0x0;
	M.x86.R_ESP = 0x2000;
	M.x86.R_CS = 0x0;
	M.x86.R_EIP = 0x2001;
	*(u8 *)0x2001 = 0xf4; /* HLT, so the emulator knows where to stop */
	
	X86EMU_prepareForInt(num);
	X86EMU_exec();
	
	*regs = M.x86;
}

static unsigned long frame_buffer = 0;

static void vbe_switch(unsigned short mode)
{
	X86EMU_regs regs;
	
	/* detect presence of vbe2+ */
	char *buffer = (char *)0x3000;
	memset(&regs, 0, sizeof regs);
	regs.R_EAX = 0x4f00;
	buffer[0] = 'V';
	buffer[1] = 'B';
	buffer[2] = 'E';
	buffer[3] = '2';
	regs.R_ES = 0;
	regs.R_EDI = 0x3000;
	
	dprintf("Detecting presence of VBE2...\n");
	
	bios_interrupt(0x10, &regs);
	
	dprintf("Result: %04x\n", regs.R_EAX);
	
	if ((regs.R_EAX & 0x00ff) != 0x4f) {
		dprintf("VBE not supported\n");
	}
	
	if ((regs.R_EAX & 0xff00) != 0) {
		dprintf("VBE call failed: %04x\n", regs.R_EAX & 0xffff);
	}
	
	/* get mode info */
	memset(&regs, 0, sizeof regs);
	regs.R_EAX = 0x4f01;
	regs.R_ES = 0;
	regs.R_EDI = 0x3000;
	regs.R_ECX = mode;
	
	bios_interrupt(0x10, &regs);
	
	frame_buffer = *((unsigned long *)(buffer+0x28));
	unsigned short width = *((unsigned short *)(buffer+0x12));
	unsigned short height = *((unsigned short *)(buffer+0x14));
	
	dprintf("Framebuffer at 0x%08x, width: %d, height: %d\n", frame_buffer, width, height);
	
	/* set the mode */
	memset(&regs, 0, sizeof regs);
	regs.R_EAX = 0x4f02;
	if(mode) {
		/* Use linear framebuffer model */
		regs.R_EBX = mode | (1<<14);
	} else {
		regs.R_EBX = 3;
	}
	
	bios_interrupt(0x10, &regs);
	
	dprintf("Switch: %04x\n", regs.R_EAX);
	
	
	/*cairo_surface_t *surface =
		cairo_image_surface_create_for_data(
			(unsigned char *)frame_buffer,
			CAIRO_FORMAT_RGB24,
			width,
			height,
			width * 4);

	cairo_t *cr = cairo_create(surface);

	cairo_set_source_rgba(cr, 1.0, 1.0, 1.0, 1.0);
	cairo_rectangle(cr, 25, 25, 25, 25);
	cairo_fill(cr);*/

}

CAMLprim value snowflake_vbe_switch(value mode)
{
	vbe_switch((unsigned short)(Int_val(mode)));
	return caml_copy_int32(frame_buffer);
}

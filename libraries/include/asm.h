#ifndef __DST_PORTS_H__
#define __DST_PORTS_H__

static inline void out8(int port, int byte) {
	asm volatile(
	"outb %0, %1"
	:
	: "a" ((char)byte), "Nd" ((short)port)
	);
}

static inline void out16(int port, int word) {
	asm volatile(
	"outw %0, %1"
	:
	: "a" ((short)word), "Nd" ((short)port)
	);
}

static inline void out32(int port, int dword) {
	asm volatile(
	"outl %0, %1"
	:
	: "a" (dword), "Nd" ((short)port)
	);
}

static inline unsigned char in8(int port) {
	register unsigned char byte;
	asm volatile(
	"inb %1, %0"
	: "=a" (byte)
	: "Nd" ((short)port)
	);
	return byte;
}

static inline unsigned short in16(int port) {
	register unsigned short word;
	asm volatile(
	"inw %1, %0"
	: "=a" (word)
	: "Nd" ((short)port)
	);
	return word;
}

static inline unsigned int in32(int port) {
	register unsigned int dword;
	asm volatile(
	"inl %1, %0"
	: "=a" (dword)
	: "Nd" ((short)port)
	);
	return dword;
}

static inline unsigned char in8_p(int port) {
  register unsigned char byte;
  
  asm volatile
  (
      "inb  %1, %0   \n"
      "outb %%al, $0x80"
    : "=a" (byte)
    : "Nd" ((short)port)
  );
  
  return byte;
}

static inline void out8_p(int port, int byte) {
  asm volatile
  (
      "outb %0, %1   \n"
      "outb %%al, $0x80"
    :
    : "a" ((char)byte), "Nd" ((short)port)
  );
}

static inline void ins16(int port, int count, unsigned short *buf) {
	asm volatile (
	  "rep ; insw"
	: "=D" (buf), "=c" (count)
	: "d" ((short)port), "0" (buf), "1" (count)
	);
	return;
}

static inline void outs16(int port, int count, unsigned short *addr) {
	asm volatile (
	  "rep ; outsw"
	: "=S" (addr), "=c" (count)
	: "d" ((short)port), "0" (addr), "1" (count)
	);
	return;
}

#endif

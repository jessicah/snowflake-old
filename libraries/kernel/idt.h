
#ifndef IDT_HEADER
#define IDT_HEADER

#define MASTER		32
#define SLAVE			40

#define PICM          0x20
#define PICMI         0x21
#define PICS          0xA0
#define PICSI         0xA1

#define ICW1          0x11
#define ICW4          0x01

typedef void (*interrupt_handler)();

typedef enum { interrupt, trap } gate_type;

extern void idt_init();

extern void set_vector(unsigned char vector, interrupt_handler handler, gate_type type);

extern void set_irq(unsigned char irq, interrupt_handler handler);

extern void mask_irq(unsigned char irq);
extern void unmask_irq(unsigned char irq);

extern void update_mask();

#endif

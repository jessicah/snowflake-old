
#include <caml/mlvalues.h>
//#include <caml/signals.h>
#include <stdio.h>
#include <asm.h>
#include <multiboot.h>

extern void caml_startup(char **args);

extern void idt_init();

static unsigned int __attribute__((section(".bss.pagealigned"),used)) page_dir[1024];
static unsigned int __attribute__((section(".bss.pagealigned"))) first_page_table[1024];
static unsigned int __attribute__((section(".bss.pagealigned"))) last_page_table[1024];

static void paging_init(void)
{
	int i;
	// build a simple pagedir
	// very first and last pages are unmapped
	// everything else has a 1:1 mapping with physical memory using 4MB pages
	for(i = 1; i < 1024; i++) {
		first_page_table[i] = (i * 0x1000) | 0x103;
	}
	first_page_table[0] = 0;
	for(i = 1; i < 1024; i++) {
		last_page_table[i] = 0xFFC00000 + (i * 0x1000) | 0x103;
	}
	last_page_table[1023] = 0;
	for(i = 1; i < 1023; i++) {
		page_dir[i] = (i * 0x400000) | 0x183;
	}
	page_dir[0] = (unsigned int)first_page_table | 0x103;
	page_dir[1023] = (unsigned int)last_page_table | 0x103;
	__asm__ volatile(
		"movl	$page_dir, %%eax\n\t"
		"mov	%%eax, %%cr3\n\t"
		
		"movl	%%cr4, %%eax\n\t"
		"bts	$4, %%eax\n\t"
		"movl	%%eax, %%cr4\n\t"
		
		"mov	%%cr0, %%eax\n\t"
		"bts	$31, %%eax\n\t"
		"mov	%%eax, %%cr0\n\t" ::: "eax");
}

static unsigned long mem_start;

void __startup(multiboot_info_t *multiboot, int magic)
{
	extern char end;
	char * argv[1] = { 0 };
	
	//dprintf("Welcome to Snowflake Serial Debugging!\r\n");
	
	mem_start = (unsigned long)&end;
	
	// set up exception and irq handlers
	idt_init();
	//paging_init();
	
	unmask_irq(0);
	update_mask();
	
	caml_startup(argv);
	
	// caml_startup has finished initialising the OS
	//dprintf("INFO: Startup completed. Exiting startup thread...\r\n");
}

// simplistic handing out of memory to malloc()
extern char *sbrk(int);

char *sbrk(int incr){
  static char *heap_end;
  char *prev_heap_end;

  if ( heap_end == 0 ) {
	heap_end = (char *)mem_start;
  }
  prev_heap_end = heap_end;

  heap_end += incr;
  // FIXME: require check to see if physical memory is exhausted
  return prev_heap_end;
}

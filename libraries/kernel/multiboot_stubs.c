
/* multiboot_stubs.c */

#include <caml/mlvalues.h>
#include <caml/callback.h>
#include <caml/memory.h>
#include <caml/fail.h>
#include <caml/bigarray.h>
#include <caml/alloc.h>

#include <multiboot.h>
#include <string.h>
#include <stdio.h>

static value to_bigarray(char *data, mlsize_t size) {
	intnat array[] = { size };
	return caml_ba_alloc(CAML_BA_UINT8 | CAML_BA_C_LAYOUT, 1, data, array);
}

extern mlsize_t my_module_length;
extern char *my_module;

CAMLprim value caml_multiboot_module(value unit) {
	CAMLparam0();
	CAMLlocal1(arr);
    
	if (my_module == NULL) {
		caml_raise_not_found();
	}
	
    arr = to_bigarray(my_module, my_module_length);
    
	CAMLreturn(arr);
}

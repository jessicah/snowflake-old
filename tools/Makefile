
OCAML = ocaml-3.12.0
OCAMLFILE = $(OCAML).touch
PWD = $(shell pwd)

all: ocamlopt.opt

ocamlopt.opt: $(OCAMLFILE)
	cp -f configure-ocaml $(OCAML)/configure
	cd $(OCAML) && patch -Np0 -i ../ocaml.dev.patch
	cd $(OCAML) && ./configure -host i386-unknown-linux-gnu -partialld "ld -melf_i386 -r" -cc "gcc -m32" -as "as --32" -aspp "gcc -m32 -c" -prefix $(PWD)/custom -no-curses -no-pthread -no-tk
	$(MAKE) -C $(OCAML) opt.opt
	$(MAKE) -C $(OCAML) install
	cp custom/bin/ocamlopt.opt ./ocamlopt.opt

$(OCAMLFILE):
	tar xjf $(OCAML).tar.bz2
	touch $(OCAMLFILE)

clean:
	rm -rf custom $(OCAML) $(OCAMLFILE)

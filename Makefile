
BUILDDIR = _build

OCB = tools/custom/bin/ocamlbuild 

OCAMLBUILD = $(OCB) $(OCBFLAGS)

KERNEL = kernel/snowflake.native

ISO = snowflake.iso

all: myocamlbuild_config.ml
	$(MAKE) -C tools all
	#$(OCAMLBUILD) libraries/stdlib/stdlib.cmxa
	#$(OCAMLBUILD) libraries/bigarray/bigarray.cmxa
	#$(OCAMLBUILD) libraries/extlib/extlib.cmxa
	$(OCAMLBUILD) libraries/asmrun/libasmrun.a
	$(OCAMLBUILD) $(KERNEL)
	rm -rf tools/cdrom/iso_prep
	mkdir -p tools/cdrom/iso_prep/boot/grub/
	cp tools/cdrom/stage2_eltorito tools/cdrom/iso_prep/boot/grub/
	cp $(BUILDDIR)/$(KERNEL) tools/cdrom/iso_prep/boot/snowflake.elf
	cp tools/cdrom/menu.lst tools/cdrom/iso_prep/boot/grub/
	mkisofs -R -b boot/grub/stage2_eltorito -no-emul-boot \
		-boot-load-size 4 -boot-info-table \
		-quiet -o $(ISO) tools/cdrom/iso_prep/

myocamlbuild_config.ml: myocamlbuild_config.ml.in
	sed -e 's/@TOOLSPREFIX@/$(subst /,\/,$(TOOLSPREFIX))/' $< > $@

qemu:
	qemu -serial stdio -boot d -hda fake_hd.tar -cdrom snowflake.iso -soundhw all -net nic,model=rtl8139,macaddr=00:15:60:9E:28:0A -net user -m 512

clean:
	$(OCAMLBUILD) -clean || true
	rm -f $(ISO)
	rm -rf tools/cdrom/iso_prep
	rm -f myocamlbuild_config.ml

distclean: clean
	$(MAKE) -C tools clean

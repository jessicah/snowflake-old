
open Ocamlbuild_plugin;;
open Command;;
open Format;;
open Outcome;;

module M = Myocamlbuild_config;;

Options.ocamlopt := P"./ocamlopt.opt";;
Options.ocamlc := P"./ocamlopt.opt";;

flag ["ocaml"; "compile"; "snowflake"] & S[A"-nostdlib"; A"-freestanding"; A"-g"];;
flag ["ocaml"; "link"; "snowflake"] & S[A"-nostdlib"; A"-freestanding"];;

flag ["c"; "compile"; "snowflake"] & S[A"-m32"; A"-g"; A"-fno-stack-protector"];;
flag ["S"; "compile"; "snowflake"] & S[A"-m32"; A"-g"];;

dep ["ocaml"; "compile"; "snowflake"] ["ocamlopt.opt"];;

flag ["ocamldep"] (A"-native");;

let snowflake_lib name =
    ocaml_lib ~extern:true ~byte:false ~native:true ~dir:("libraries/"^name) ~tag_name:("snowflake_"^name) ("libraries/"^name^"/"^name);;

let link_C_library stlib a env build =
	let stlib = env stlib and a = env a in
	let objs = string_list_of_file stlib in
	let include_dirs = Pathname.include_dirs_of (Pathname.dirname a) in
	let results = build (List.map (fun o -> List.map (fun dir -> dir/o) include_dirs) objs) in
	let objs = List.map begin function
		| Good o -> o
		| Bad exn -> raise exn
	end results in
	Cmd(S[A(M._ar);A"-rc"; Px a; T(tags_of_pathname a++"c"++"staticlib"); atomize objs]);;

rule "C static library (short)"
	~prod:"lib%(libname).a"
	~dep:"lib%(libname).clib"
    ~insert:`top
	(link_C_library "lib%(libname).clib" "lib%(libname).a");;

rule "C static library"
	~prod:"%(path)/lib%(libname).a"
	~dep:"%(path)/lib%(libname).clib"
    ~insert:`top
	(link_C_library "%(path)/lib%(libname).clib" "%(path)/lib%(libname).a");;

rule "S -> o"
	~prod:"%.o"
	~dep:"%.S"
	begin fun env _ ->
		let s = env "%.S" and o = env "%.o" in
		let tags = tags_of_pathname s ++ "S" ++ "compile" in
		Cmd(S[A(M._gcc); T(tags); A"-c"; P s; A"-o"; Px o])
	end;;

rule "c -> o"
    ~deps:[ "%.c" ] ~prods:[ "%.o" ]
	begin fun env _ ->
		let c = env "%.c" and o = env "%.o" in
		let tags = tags_of_pathname c ++ "c" ++ "compile" in
        Cmd(S [A(M._gcc); T(tags); A"-c"; P c; A"-o"; Px o])
	end;;

let copy_rule' ?insert src dst =
        copy_rule (sprintf "%s -> %s" src dst) ?insert src dst;;

(*** stdlib.cmxa ***)

    snowflake_lib "stdlib";;

(*** bigarray.cmxa ***)

    (* just don't bother; seems to have some strange bugs for this particular library *)
    (* let build system pull in bigarray.cmx instead... *)
	
	snowflake_lib "bigarray";;

(*(*** threads.cmxa ***)

	snowflake_lib "threads";;

(*** cairo.cmxa ***)

	snowflake_lib "cairo";;
	
	(*Pathname.define_context "libraries/cairo" ["libraries/cairo"; "libraries/bigarray"];;*)

(*** freetype.cmxa ***)
	
	snowflake_lib "freetype";;*)

(*** extlib.cmxa ***)

    snowflake_lib "extlib";;
    
    (* dep on internal stdlib module *)
    dep ["file:libraries/extlib/IO.ml"] ["libraries/stdlib/camlinternalOO.cmx"];;

(*(*** bitstring.cmxa, bitstring_persistent.cmxa, pa_bitstring.cmo ***)

	snowflake_lib "bitstring";;
	
	flag ["ocaml"; "pp"; "use_bitstring"] (S [
		Sh"LD_LIBRARY_PATH=../tools/custom/lib/ocaml/stublibs";
		A"../tools/custom/bin/camlp4o";
		A"-I";
		A"../tools/custom/lib/ocaml/bitstring";
		A"bitstring.cma";
		A"bitstring_persistent.cma";
		A"pa_bitstring.cmo";
	]);;*)

(*** static libraries ***)

type stlib = {
	name : string;
	path : string;
	context : string list;
	c_options : string list;
	s_options : string list;
	includes : string list;
	headers : string list;
};;

let expand_path prefix paths =
	List.map (fun s -> if s = "~" then prefix else String.subst "~" prefix s) paths

let mk_includes includes =
	if includes = []
		then N
		else atomize (List.fold_right (fun dir acc -> "-I" :: dir :: acc) includes []);;

let mk_stlib ?(copy = true) stlib =
	let includes = expand_path stlib.path stlib.includes in
	let headers = expand_path stlib.path stlib.headers in
	Pathname.define_context stlib.path (stlib.path :: expand_path stlib.path stlib.context);
	flag ["c"; "compile"; stlib.name] (atomize stlib.c_options);
	flag ["S"; "compile"; stlib.name] (atomize stlib.s_options);
	flag ["c"; "compile"; stlib.name] (mk_includes includes);
	flag ["S"; "compile"; stlib.name] (mk_includes includes);
	dep ["c"; "compile"; stlib.name] headers;
	dep ["S"; "compile"; stlib.name] headers;
	if copy then copy_rule'
		(stlib.path / stlib.name -.- !Options.ext_lib)
		(stlib.name -.- !Options.ext_lib);;

let caml_headers = [
		"libraries/include/caml/alloc.h";
		"libraries/include/caml/callback.h";
		"libraries/include/caml/compact.h";
		"libraries/include/caml/config.h";
		"libraries/include/caml/custom.h";
		"libraries/include/caml/fail.h";
		"libraries/include/caml/finalise.h";
		"libraries/include/caml/freelist.h";
		"libraries/include/caml/gc.h";
		"libraries/include/caml/gc_ctrl.h";
		"libraries/include/caml/globroots.h";
		"libraries/include/caml/int64_native.h";
		"libraries/include/caml/intext.h";
		"libraries/include/caml/m.h";
		"libraries/include/caml/major_gc.h";
		"libraries/include/caml/md5.h";
		"libraries/include/caml/memory.h";
		"libraries/include/caml/minor_gc.h";
		"libraries/include/caml/misc.h";
		"libraries/include/caml/mlvalues.h";
		"libraries/include/caml/natdynlink.h";
		"libraries/include/caml/osdeps.h";
		"libraries/include/caml/prims.h";
		"libraries/include/caml/printexc.h";
		"libraries/include/caml/reverse.h";
		"libraries/include/caml/roots.h";
		"libraries/include/caml/s.h";
		"libraries/include/caml/signals.h";
		"libraries/include/caml/signals_machdep.h";
		"libraries/include/caml/signals_osdep.h";
		"libraries/include/caml/stack.h";
		"libraries/include/caml/stacks.h";
		"libraries/include/caml/startup.h";
		"libraries/include/caml/sys.h";
		"libraries/include/caml/weak.h";
	];;

(*** libm.a ***)

    mk_stlib {
        name = "libm";
        path = "libraries/m";
        context = ["~/src"; "~/i387"; "~/i387/sys"; "~/i387/machine"];
        c_options = [
                "-D_IEEE_LIBM"; "-fomit-frame-pointer";
                "-fno-builtin"; "-O2"; "-nostdinc";
            ];
        s_options = ["-D_IEEE_LIBM"];
        includes = ["~/src"; "~/i387"; "libraries/include"];
        headers = [
                "~/src/math_private.h"; "~/src/lrint.c";
                "~/src/lrintf.c"; "~/src/lround.c";
                "~/src/lroundf.c"; "~/i387/abi.h";
                "~/i387/sys/cdefs.h"; "~/i387/sys/ieee754.h";
                "~/i387/sys/types.h"; "~/i387/machine/asm.h";
                "~/i387/machine/endian.h"; "~/i387/machine/ieee.h";
                "~/i387/machine/limits.h"; "libraries/include/math.h";
            ]
        };;

(*** libc.a ***)

    mk_stlib {
        name = "libc";
        path = "libraries/c";
        context = [];
        c_options = [
                "-O3"; "-DINIT_MEM"; "-fno-builtin"; "-nostdlib";
                "-nostartfiles"; "-nodefaultlibs"; "-fomit-frame-pointer";
                "-DSTANDALONE";
            ];
        s_options = ["-DINIT_MEM"];
        includes = ["~"; "libraries/include"];
        headers = [
                "~/i386mach.S";
                "libraries/include/stddef.h";
                "libraries/include/assert.h";
                "libraries/include/stdarg.h";
                "libraries/include/string.h";
                "libraries/include/asm.h";
                "libraries/include/signal.h";
            ]
        };;

(*** libasmrun.a ***)

    mk_stlib ~copy:false {
        name = "libasmrun";
        path = "libraries/asmrun";
        context = [];
        c_options = [
                "-DNATIVE_CODE"; "-DCAML_NAME_SPACE"; "-DSYS_linux_elf";
                "-Wall"; "-Werror"; "-DTARGET_i386";
            ];
        s_options = ["-DSYS_linux_elf";"-DTARGET_i386"];
        includes = ["libraries/include"; "libraries/include/caml"];
        headers = [
                "libraries/include/setjmp.h";
                "libraries/include/stddef.h";
                "libraries/include/stdlib.h";
                "libraries/include/string.h";
                "libraries/include/signal.h";
                "libraries/include/math.h";
                "libraries/include/stdio.h";
                "libraries/include/limits.h";
                "libraries/include/ctype.h";
                "libraries/include/asm.h";
                "libraries/include/threads.h";
							] @ caml_headers;
        };;

(*** libbigarray.a ***)

    mk_stlib {
        name = "libbigarray";
        path = "libraries/bigarray";
        context = [];
        c_options = [
                "-DCAML_NAME_SPACE"; "-DSYS_linux_elf"; "-DTARGET_i386"; "-nostdinc"; "-DNATIVE_CODE"
            ];
        s_options = [];
        includes = ["~"; "libraries/include"; "libraries/include/caml"];
        headers = [
                "libraries/include/setjmp.h";
                "libraries/include/stddef.h";
                "libraries/include/stdarg.h";
                "libraries/include/stdlib.h";
                "libraries/include/string.h";
                "libraries/include/signal.h";
                "libraries/include/math.h";
                "libraries/include/stdio.h";
                "libraries/include/limits.h";
                "libraries/include/ctype.h";
                "libraries/include/asm.h";
                "libraries/include/threads.h";
                "libraries/include/caml/bigarray.h";
							] @ caml_headers;
        };;

(*(*** libbitstring.a ***)

    mk_stlib {
        name = "libbitstring";
        path = "libraries/bitstring";
        context = [];
        c_options = [
                "-DCAML_NAME_SPACE"; "-DSYS_linux_elf"; "-DTARGET_i386"; "-nostdinc"; "-DNATIVE_CODE"
            ];
        s_options = [];
        includes = ["~"; "libraries/include"; "libraries/include/caml"];
        headers = [
				"~/byteswap.h";
				"~/config.h";
                "libraries/include/setjmp.h";
                "libraries/include/stddef.h";
                "libraries/include/stdarg.h";
                "libraries/include/stdlib.h";
                "libraries/include/string.h";
                "libraries/include/signal.h";
                "libraries/include/math.h";
                "libraries/include/stdio.h";
                "libraries/include/limits.h";
                "libraries/include/ctype.h";
                "libraries/include/asm.h";
                "libraries/include/threads.h";
                "libraries/include/caml/bigarray.h";
							] @ caml_headers;
        };;*)

(*(*** libthreads.a ***)

    mk_stlib {
        name = "libthreads";
        path = "libraries/threads";
        context = [];
        c_options = [
                "-DCAML_NAME_SPACE"; "-DSYS_linux_elf"; "-DTARGET_i386"; "-nostdinc"; "-DNATIVE_CODE"
            ];
        s_options = [];
        includes = ["~"; "libraries/include"; "libraries/include/caml"];
        headers = [
                "libraries/include/setjmp.h";
                "libraries/include/stddef.h";
                "libraries/include/stdarg.h";
                "libraries/include/stdlib.h";
                "libraries/include/string.h";
                "libraries/include/signal.h";
                "libraries/include/math.h";
                "libraries/include/stdio.h";
                "libraries/include/limits.h";
                "libraries/include/ctype.h";
                "libraries/include/asm.h";
                "libraries/include/threads.h";
                "libraries/include/caml/bigarray.h";
							] @ caml_headers;
        };;*)

(*** libgcc.a ***)

    rule "libgcc (internal library)"
        ~prod:"libgcc.a"
        ~deps:[]
        begin fun _ _ ->
            let cmd = "cp `" ^ M._gcc ^ " -m32 -print-file-name=libgcc.a` libgcc.a" in
            Cmd (Sh cmd)
        end;;

(*** libkernel.a ***)

    rule "libkernel.a"
        ~insert:`top
        ~prod:"libraries/kernel/libkernel.a"
        ~deps:["libraries/kernel/libkernel.stlib"; "libraries/asmrun/libasmrun.a"]
        begin fun env build ->
            let stlib = env "libraries/kernel/libkernel.stlib"
            and kernel = env "libraries/kernel/libkernel.a"
            and asmrun = env "libraries/asmrun/libasmrun.a" in
            let objs = string_list_of_file stlib in
            let include_dirs = Pathname.include_dirs_of (Pathname.dirname kernel) in
            let results = build (List.map (fun o -> List.map (fun dir -> dir/o) include_dirs) objs) in
            let objs = List.map begin function
                | Good o -> o
                | Bad exn -> raise exn
            end results in
            Seq [
                (* copy libasmrun.a to libkernel.a... *)
                cp asmrun kernel;
                (* add compiled objects to libkernel.a... *)
                Cmd(S[A(M._ar);A"-rb"; A"startup.o"; Px kernel; T(tags_of_pathname kernel++"c"++"staticlib"); atomize objs]);
                Cmd(S[A(M._ranlib);Px kernel]);
            ]
        end;;

    flag ["compile"; "c"; "libkernel"] (S[A"-I"; A"libraries/include"; A"-I"; A"libraries/x86emu"; A"-I"; A"../tools/custom/include/cairo"; A"-nostdinc"; A"-DCAML_NAME_SPACE"; A"-DSYS_linux_elf"; A"-DTARGET_i386"; A"-DNATIVE_CODE"; A"-O2"]);;
	
	let deps = [
		"libraries/include/multiboot.h";
		"libraries/include/caml/bigarray.h";
		"libraries/kernel/idt.h";
		"libraries/include/list.h";
		"libraries/include/assert.h";
		(*"libraries/x86emu/x86emu.h";
		"libraries/x86emu/x86emu/types.h";
		"libraries/x86emu/x86emu/regs.h";*)
	] in dep ["compile"; "c"; "libkernel"] deps;;

    copy_rule' "libraries/kernel/libkernel.a" "libkernel.a";;

(*** snowflake.native ***)

    flag ["ocaml"; "native"; "program"; "snowflake"] (S[
            A"-use-runtime"; P"libkernel.a";
            A"-ccopt"; A"-static";
            A"-cc"; A(M._ld);
            A"-ccopt"; A"-L .";
			A"-ccopt"; A"-L ../tools/custom/lib";
            A"-ccopt"; A"-T ../kernel/kernel.ldscript";
			A"-clibrary"; A"-lgcc";
            A"-clibrary"; A"-lc";
            A"-clibrary"; A"-lm";
			A"-clibrary"; A"-lbigarray";
			(*A"-clibrary"; A"-lthreads";*)
        ]);;
	
	dep ["file:kernel/snowflake.native"] ["libkernel.a"; "libm.a"; "libc.a"; "libgcc.a"; "libbigarray.a"; (*"libthreads.a"; "libbitstring.a"; "libx86emu.a"; "libmlcairo.a"; "libmlfreetype.a"*)];;

(*** ocamlopt.opt ***)
		
		rule "ocamlopt.opt"
			~prod:"ocamlopt.opt"
			begin fun _ _ ->
				Cmd(S[Sh "cp ../tools/ocamlopt.opt"; Px "ocamlopt.opt"; Sh "; chmod a+x ocamlopt.opt"])
			end;;

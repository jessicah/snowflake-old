
(* convert a file into an ocaml array *)

open Printf

let infile = open_in_bin Sys.argv.(1)
let outfile = open_out Sys.argv.(2)
let buffer = String.create 64

let header () =
	fprintf outfile "\nlet data = \""

let trailer () =
	fprintf outfile "\"\n\n"

let line () =
	let chars = input infile buffer 0 64 in
	if chars = 0 then raise End_of_file;
	for i = 0 to chars - 1 do
		fprintf outfile "\\x%02X" (Char.code buffer.[i]);
	done

let () =
	header ();
	begin try
		while true do line () done
	with e -> eprintf "%s\n" (Printexc.to_string e) end;
	trailer ();
	close_in infile;
	close_out outfile

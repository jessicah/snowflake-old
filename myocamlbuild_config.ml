
let prefix_C_tools = ""

let _gcc, _as, _ar, _ranlib, _ld = match List.map begin fun cmd ->
			if String.length prefix_C_tools = 0 then cmd
			else prefix_C_tools ^ "/i386-elf-" ^ cmd
		end ["gcc"; "as"; "ar"; "ranlib"; "ld"] with
	| [gcc'; as'; ar'; ranlib'; ld'] -> gcc', as', ar', ranlib', ld'
	| _ -> assert false

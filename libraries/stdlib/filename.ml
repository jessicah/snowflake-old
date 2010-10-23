(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*          Xavier Leroy and Damien Doligez, INRIA Rocquencourt        *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the GNU Library General Public License, with    *)
(*  the special exception on linking described in file ../LICENSE.     *)
(*                                                                     *)
(***********************************************************************)

(* $Id: filename.ml 9540 2010-01-20 16:26:46Z doligez $ *)

let generic_quote quotequote s =
  let l = String.length s in
  let b = Buffer.create (l + 20) in
  Buffer.add_char b '\'';
  for i = 0 to l - 1 do
    if s.[i] = '\''
    then Buffer.add_string b quotequote
    else Buffer.add_char b  s.[i]
  done;
  Buffer.add_char b '\'';
  Buffer.contents b

let generic_basename rindex_dir_sep current_dir_name name =
  let raw_name =
    try
      let p = rindex_dir_sep name + 1 in
      String.sub name p (String.length name - p)
    with Not_found ->
      name
  in
  if raw_name = "" then current_dir_name else raw_name

let generic_dirname rindex_dir_sep current_dir_name dir_sep name =
  try
    match rindex_dir_sep name with
      0 -> dir_sep
    | n -> String.sub name 0 n
  with Not_found ->
    current_dir_name

module Unix = struct
  let current_dir_name = "."
  let parent_dir_name = ".."
  let dir_sep = "/"
  let is_dir_sep s i = s.[i] = '/'
  let rindex_dir_sep s = String.rindex s '/'
  let is_relative n = String.length n < 1 || n.[0] <> '/';;
  let is_implicit n =
    is_relative n
    && (String.length n < 2 || String.sub n 0 2 <> "./")
    && (String.length n < 3 || String.sub n 0 3 <> "../")
  let check_suffix name suff =
    String.length name >= String.length suff &&
    String.sub name (String.length name - String.length suff)
                    (String.length suff) = suff
  let temp_dir_name = "/tmp"
  let quote = generic_quote "'\\''"
  let basename = generic_basename rindex_dir_sep current_dir_name
  let dirname = generic_dirname rindex_dir_sep current_dir_name dir_sep
end

let (current_dir_name, parent_dir_name, dir_sep, is_dir_sep, rindex_dir_sep,
     is_relative, is_implicit, check_suffix, temp_dir_name, quote, basename,
     dirname) =
  match Sys.os_type with
    "Unix" ->
      (Unix.current_dir_name, Unix.parent_dir_name, Unix.dir_sep,
       Unix.is_dir_sep, Unix.rindex_dir_sep,
       Unix.is_relative, Unix.is_implicit, Unix.check_suffix,
       Unix.temp_dir_name, Unix.quote, Unix.basename, Unix.dirname)
  | _ -> assert false

let concat dirname filename =
  let l = String.length dirname in
  if l = 0 || is_dir_sep dirname (l-1)
  then dirname ^ filename
  else dirname ^ dir_sep ^ filename

let chop_suffix name suff =
  let n = String.length name - String.length suff in
  if n < 0 then invalid_arg "Filename.chop_suffix" else String.sub name 0 n

let chop_extension name =
  let rec search_dot i =
    if i < 0 || is_dir_sep name i then invalid_arg "Filename.chop_extension"
    else if name.[i] = '.' then String.sub name 0 i
    else search_dot (i - 1) in
  search_dot (String.length name - 1)

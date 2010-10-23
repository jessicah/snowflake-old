(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the GNU Library General Public License, with    *)
(*  the special exception on linking described in file ../LICENSE.     *)
(*                                                                     *)
(***********************************************************************)

(* $Id: digest.ml 6044 2003-12-31 14:20:40Z doligez $ *)

(* Message digest (MD5) *)

type t = string

external unsafe_string: string -> int -> int -> t = "caml_md5_string"

let string str =
  unsafe_string str 0 (String.length str)

let substring str ofs len =
  if ofs < 0 || len < 0 || ofs > String.length str - len
  then invalid_arg "Digest.substring"
  else unsafe_string str ofs len

let to_hex d =
  let result = String.create 32 in
  for i = 0 to 15 do
    String.blit (Printf.sprintf "%02x" (int_of_char d.[i])) 0 result (2*i) 2;
  done;
  result
;;

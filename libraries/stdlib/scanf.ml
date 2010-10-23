(***********************************************************************)
(*                                                                     *)
(*                           Objective Caml                            *)
(*                                                                     *)
(*            Pierre Weis, projet Cristal, INRIA Rocquencourt          *)
(*                                                                     *)
(*  Copyright 2002 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the GNU Library General Public License, with    *)
(*  the special exception on linking described in file ../LICENSE.     *)
(*                                                                     *)
(***********************************************************************)

(* $Id: scanf.ml 10377 2010-05-05 17:49:19Z weis $ *)

(* The run-time library for scanners. *)

(* Scanning buffers. *)
module type SCANNING = sig

  type in_channel;;

  type scanbuf = in_channel;;

  val next_char : scanbuf -> char;;
  (* [Scanning.next_char ib] advance the scanning buffer for
      one character.
      If no more character can be read, sets a end of file condition and
      returns '\000'. *)

  val invalidate_current_char : scanbuf -> unit;;
  (* [Scanning.invalidate_current_char ib] mark the current_char as already
      scanned. *)

  val peek_char : scanbuf -> char;;
  (* [Scanning.peek_char ib] returns the current char available in
      the buffer or reads one if necessary (when the current character is
      already scanned).
      If no character can be read, sets an end of file condition and
      returns '\000'. *)

  val checked_peek_char : scanbuf -> char;;
  (* Same as above but always returns a valid char or fails:
      instead of returning a null char when the reading method of the
      input buffer has reached an end of file, the function raises exception
      [End_of_file]. *)

  val store_char : int -> scanbuf -> char -> int;;
  (* [Scanning.store_char lim ib c] adds [c] to the token buffer
      of the scanning buffer. It also advances the scanning buffer for one
      character and returns [lim - 1], indicating the new limit
      for the length of the current token. *)

  val skip_char : int -> scanbuf -> int;;
  (* [Scanning.skip_char lim ib] ignores the current character. *)

  val ignore_char : int -> scanbuf -> int;;
  (* [Scanning.ignore_char ib lim] ignores the current character and
     decrements the limit. *)

  val token : scanbuf -> string;;
  (* [Scanning.token ib] returns the string stored into the token
      buffer of the scanning buffer: it returns the token matched by the
      format. *)

  val reset_token : scanbuf -> unit;;
  (* [Scanning.reset_token ib] resets the token buffer of
      the given scanning buffer. *)

  val char_count : scanbuf -> int;;
  (* [Scanning.char_count ib] returns the number of characters
      read so far from the given buffer. *)

  val line_count : scanbuf -> int;;
  (* [Scanning.line_count ib] returns the number of new line
      characters read so far from the given buffer. *)

  val token_count : scanbuf -> int;;
  (* [Scanning.token_count ib] returns the number of tokens read
      so far from [ib]. *)

  val eof : scanbuf -> bool;;
  (* [Scanning.eof ib] returns the end of input condition
      of the given buffer. *)

  val end_of_input : scanbuf -> bool;;
  (* [Scanning.end_of_input ib] tests the end of input condition
      of the given buffer (if no char has ever been read, an attempt to
      read one is performed). *)

  val beginning_of_input : scanbuf -> bool;;
  (* [Scanning.beginning_of_input ib] tests the beginning of input
      condition of the given buffer. *)

  val name_of_input : scanbuf -> string;;
  (* [Scanning.name_of_input ib] returns the name of the character
      source for input buffer [ib]. *)

  val from_string : string -> scanbuf;;
  val from_function : (unit -> char) -> scanbuf;;

  val close_in : scanbuf -> unit;;

end
;;

module Scanning : SCANNING = struct

  (* The run-time library for scanf. *)
  type in_channel_name =
    | From_string
    | From_function
  ;;

  type in_channel = {
    mutable eof : bool;
    mutable current_char : char;
    mutable current_char_is_valid : bool;
    mutable char_count : int;
    mutable line_count : int;
    mutable token_count : int;
    mutable get_next_char : unit -> char;
    tokbuf : Buffer.t;
    input_name : in_channel_name;
  }
  ;;

  type scanbuf = in_channel;;

  let null_char = '\000';;

  (* Reads a new character from input buffer.  Next_char never fails,
     even in case of end of input: it then simply sets the end of file
     condition. *)
  let next_char ib =
    try
      let c = ib.get_next_char () in
      ib.current_char <- c;
      ib.current_char_is_valid <- true;
      ib.char_count <- succ ib.char_count;
      if c = '\n' then ib.line_count <- succ ib.line_count;
      c with
    | End_of_file ->
      let c = null_char in
      ib.current_char <- c;
      ib.current_char_is_valid <- false;
      ib.eof <- true;
      c
  ;;

  let peek_char ib =
    if ib.current_char_is_valid then ib.current_char else next_char ib;;

  (* Returns a valid current char for the input buffer. In particular
     no irrelevant null character (as set by [next_char] in case of end
     of input) is returned, since [End_of_file] is raised when
     [next_char] sets the end of file condition while trying to read a
     new character. *)
  let checked_peek_char ib =
    let c = peek_char ib in
    if ib.eof then raise End_of_file;
    c
  ;;

  let end_of_input ib =
    ignore (peek_char ib);
    ib.eof
  ;;

  let eof ib = ib.eof;;

  let beginning_of_input ib = ib.char_count = 0;;
  let name_of_input ib =
    match ib.input_name with
    | From_string -> "unnamed character string"
    | From_function -> "unnamed function"
  ;;

  let char_count ib =
    if ib.current_char_is_valid then ib.char_count - 1 else ib.char_count
  ;;
  let line_count ib = ib.line_count;;
  let reset_token ib = Buffer.reset ib.tokbuf;;
  let invalidate_current_char ib = ib.current_char_is_valid <- false;;

  let token ib =
    let tokbuf = ib.tokbuf in
    let tok = Buffer.contents tokbuf in
    Buffer.clear tokbuf;
    ib.token_count <- succ ib.token_count;
    tok
  ;;

  let token_count ib = ib.token_count;;

  let skip_char max ib =
    invalidate_current_char ib;
    max
  ;;

  let ignore_char max ib = skip_char (max - 1) ib;;

  let store_char max ib c =
    Buffer.add_char ib.tokbuf c;
    ignore_char max ib
  ;;

  let default_token_buffer_size = 1024;;

  let create iname next = {
    eof = false;
    current_char = null_char;
    current_char_is_valid = false;
    char_count = 0;
    line_count = 0;
    token_count = 0;
    get_next_char = next;
    tokbuf = Buffer.create default_token_buffer_size;
    input_name = iname;
  }
  ;;

  let from_string s =
    let i = ref 0 in
    let len = String.length s in
    let next () =
      if !i >= len then raise End_of_file else
      let c = s.[!i] in
      incr i;
      c in
    create From_string next
  ;;

  let from_function = create From_function;;

  let close_in ib =
    match ib.input_name with
    | From_string | From_function -> ()
  ;;

end
;;

(* Formatted input functions. *)

type ('a, 'b, 'c, 'd) scanner =
     ('a, Scanning.in_channel, 'b, 'c, 'a -> 'd, 'd) format6 -> 'c
;;

external string_to_format :
 string -> ('a, 'b, 'c, 'd, 'e, 'f) format6 = "%identity"
;;

(* Reporting errors. *)
exception Scan_failure of string;;

let bad_input s = raise (Scan_failure s);;

let bad_input_escape c =
  bad_input (Printf.sprintf "illegal escape character %C" c)
;;

let bad_token_length message =
  bad_input
    (Printf.sprintf
       "scanning of %s failed: \
        the specified length was too short for token" message)
;;

let bad_end_of_input message =
  bad_input
    (Printf.sprintf
       "scanning of %s failed: \
        premature end of file occurred before end of token" message)
;;

let int_max = function
  | None -> max_int
  | Some max -> max
;;

let int_min = function
  | None -> 0
  | Some max -> max
;;

let float_min = function
  | None -> max_int
  | Some min -> min
;;

module Sformat = Printf.CamlinternalPr.Sformat;;
module Tformat = Printf.CamlinternalPr.Tformat;;

let bad_conversion fmt i c =
  invalid_arg
    (Printf.sprintf
       "scanf: bad conversion %%%C, at char number %i \
        in format string ``%s''" c i (Sformat.to_string fmt))
;;

let incomplete_format fmt =
  invalid_arg
    (Printf.sprintf "scanf: premature end of format string ``%s''"
       (Sformat.to_string fmt))
;;

let bad_float () =
  bad_input "no dot or exponent part found in float token"
;;

let character_mismatch_err c ci =
  Printf.sprintf "looking for %C, found %C" c ci
;;

let character_mismatch c ci =
  bad_input (character_mismatch_err c ci)
;;

let format_mismatch_err fmt1 fmt2 =
  Printf.sprintf
    "format read ``%s'' does not match specification ``%s''" fmt1 fmt2
;;

let format_mismatch fmt1 fmt2 = bad_input (format_mismatch_err fmt1 fmt2);;

(* Checking that 2 format strings are type compatible. *)
let compatible_format_type fmt1 fmt2 =
  Tformat.summarize_format_type (string_to_format fmt1) =
  Tformat.summarize_format_type (string_to_format fmt2);;

(* Checking that [c] is indeed in the input, then skips it.
   In this case, the character c has been explicitely specified in the
   format as being mandatory in the input; hence we should fail with
   End_of_file in case of end_of_input. (Remember that Scan_failure is raised
   only when (we can prove by evidence) that the input does not match the
   format string given. We must thus differentiate End_of_file as an error
   due to lack of input, and Scan_failure which is due to provably wrong
   input. I am not sure this is worth to burden: it is complex and somehow
   subliminal; should be clearer to fail with Scan_failure "Not enough input
   to complete scanning"!)

   That's why, waiting for a better solution, we use checked_peek_char here.
   We are also careful to treat "\r\n" in the input as a end of line marker: it
   always matches a '\n' specification in the input format string. *)
let rec check_char ib c =
  let ci = Scanning.checked_peek_char ib in
  if ci = c then Scanning.invalidate_current_char ib else begin
    match ci with
    | '\r' when c = '\n' ->
      Scanning.invalidate_current_char ib; check_char ib '\n'
    | _ -> character_mismatch c ci
  end
;;

(* Checks that the current char is indeed one of the stopper characters,
   then skips it.
   Be careful that if ib has no more character this procedure should
   just do nothing (since %s@c defaults to the entire rest of the
   buffer, when no character c can be found in the input). *)
let ignore_stoppers stps ib =
  if stps <> [] && not (Scanning.eof ib) then
  let ci = Scanning.peek_char ib in
  if List.memq ci stps then Scanning.invalidate_current_char ib else
  let sr = String.concat "" (List.map (String.make 1) stps) in
  bad_input
    (Printf.sprintf "looking for one of range %S, found %C" sr ci)
;;

(* Extracting tokens from the output token buffer. *)

let token_char ib = (Scanning.token ib).[0];;

let token_string = Scanning.token;;

let token_bool ib =
  match Scanning.token ib with
  | "true" -> true
  | "false" -> false
  | s -> bad_input (Printf.sprintf "invalid boolean %S" s)
;;

(* Extract an integer literal token.
   Since the functions Pervasives.*int*_of_string do not accept a leading +,
   we skip it if necessary. *)
let token_int_literal conv ib =
  let tok =
    match conv with
    | 'd' | 'i' | 'u' -> Scanning.token ib
    | 'o' -> "0o" ^ Scanning.token ib
    | 'x' | 'X' -> "0x" ^ Scanning.token ib
    | 'b' -> "0b" ^ Scanning.token ib
    | _ -> assert false in
  let l = String.length tok in
  if l = 0 || tok.[0] <> '+' then tok else String.sub tok 1 (l - 1)
;;

(* All the functions that convert a string to a number raise the exception
   Failure when the conversion is not possible.
   This exception is then trapped in [kscanf]. *)
let token_int conv ib = int_of_string (token_int_literal conv ib);;

let token_float ib = float_of_string (Scanning.token ib);;

(* To scan native ints, int32 and int64 integers.
   We cannot access to conversions to/from strings for those types,
   Nativeint.of_string, Int32.of_string, and Int64.of_string,
   since those modules are not available to [Scanf].
   However, we can bind and use the corresponding primitives that are
   available in the runtime. *)
external nativeint_of_string : string -> nativeint
  = "caml_nativeint_of_string"
;;
external int32_of_string : string -> int32
  = "caml_int32_of_string"
;;
external int64_of_string : string -> int64
  = "caml_int64_of_string"
;;

let token_nativeint conv ib = nativeint_of_string (token_int_literal conv ib);;
let token_int32 conv ib = int32_of_string (token_int_literal conv ib);;
let token_int64 conv ib = int64_of_string (token_int_literal conv ib);;

(* Scanning numbers. *)

(* Digits scanning functions suppose that one character has been checked and
   is available, since they return at end of file with the currently found
   token selected.

   Put it in another way, the digits scanning functions scan for a possibly
   empty sequence of digits, (hence, a successful scanning from one of those
   functions does not imply that the token is a well-formed number: to get a
   true number, it is mandatory to check that at least one valid digit is
   available before calling one of the digit scanning functions). *)

(* The decimal case is treated especially for optimization purposes. *)
let rec scan_decimal_digits max ib =
  if max = 0 then max else
  let c = Scanning.peek_char ib in
  if Scanning.eof ib then max else
  match c with
  | '0' .. '9' as c ->
    let max = Scanning.store_char max ib c in
    scan_decimal_digits max ib
  | '_' ->
    let max = Scanning.ignore_char max ib in
    scan_decimal_digits max ib
  | _ -> max
;;

let scan_decimal_digits_plus max ib =
  if max = 0 then bad_token_length "decimal digits" else
  let c = Scanning.checked_peek_char ib in
  match c with
  | '0' .. '9' ->
    let max = Scanning.store_char max ib c in
    scan_decimal_digits max ib
  | c ->
    bad_input (Printf.sprintf "character %C is not a decimal digit" c)
;;

let scan_digits_plus digitp max ib =
  (* To scan numbers from other bases, we use a predicate argument to
     scan_digits. *)
  let rec scan_digits max =
    if max = 0 then max else
    let c = Scanning.peek_char ib in
    if Scanning.eof ib then max else
    match c with
    | c when digitp c ->
      let max = Scanning.store_char max ib c in
      scan_digits max
    | '_' ->
      let max = Scanning.ignore_char max ib in
      scan_digits max
    | _ -> max in

  (* Ensure we have got enough width left,
     and read at list one digit. *)
  if max = 0 then bad_token_length "digits" else
  let c = Scanning.checked_peek_char ib in

  if digitp c then
    let max = Scanning.store_char max ib c in
    scan_digits max
  else
    bad_input (Printf.sprintf "character %C is not a digit" c)
;;

let is_binary_digit = function
  | '0' .. '1' -> true
  | _ -> false
;;

let scan_binary_int = scan_digits_plus is_binary_digit;;

let is_octal_digit = function
  | '0' .. '7' -> true
  | _ -> false
;;

let scan_octal_int = scan_digits_plus is_octal_digit;;

let is_hexa_digit = function
  | '0' .. '9' | 'a' .. 'f' | 'A' .. 'F' -> true
  | _ -> false
;;

let scan_hexadecimal_int = scan_digits_plus is_hexa_digit;;

(* Scan a decimal integer. *)
let scan_unsigned_decimal_int = scan_decimal_digits_plus;;

let scan_sign max ib =
  let c = Scanning.checked_peek_char ib in
  match c with
  | '+' -> Scanning.store_char max ib c
  | '-' -> Scanning.store_char max ib c
  | c -> max
;;

let scan_optionally_signed_decimal_int max ib =
  let max = scan_sign max ib in
  scan_unsigned_decimal_int max ib
;;

(* Scan an unsigned integer that could be given in any (common) basis.
   If digits are prefixed by one of 0x, 0X, 0o, or 0b, the number is
   assumed to be written respectively in hexadecimal, hexadecimal,
   octal, or binary. *)
let scan_unsigned_int max ib =
  match Scanning.checked_peek_char ib with
  | '0' as c ->
    let max = Scanning.store_char max ib c in
    if max = 0 then max else
    let c = Scanning.peek_char ib in
    if Scanning.eof ib then max else
    begin match c with
    | 'x' | 'X' -> scan_hexadecimal_int (Scanning.store_char max ib c) ib
    | 'o' -> scan_octal_int (Scanning.store_char max ib c) ib
    | 'b' -> scan_binary_int (Scanning.store_char max ib c) ib
    | c -> scan_decimal_digits max ib end
  | c -> scan_unsigned_decimal_int max ib
;;

let scan_optionally_signed_int max ib =
  let max = scan_sign max ib in
  scan_unsigned_int max ib
;;

let scan_int_conv conv max _min ib =
  match conv with
  | 'b' -> scan_binary_int max ib
  | 'd' -> scan_optionally_signed_decimal_int max ib
  | 'i' -> scan_optionally_signed_int max ib
  | 'o' -> scan_octal_int max ib
  | 'u' -> scan_unsigned_decimal_int max ib
  | 'x' | 'X' -> scan_hexadecimal_int max ib
  | c -> assert false
;;

(* Scanning floating point numbers. *)
(* Fractional part is optional and can be reduced to 0 digits. *)
let scan_frac_part max ib =
  if max = 0 then max else
  let c = Scanning.peek_char ib in
  if Scanning.eof ib then max else
  match c with
  | '0' .. '9' as c ->
    scan_decimal_digits (Scanning.store_char max ib c) ib
  | _ -> max
;;

(* Exp part is optional and can be reduced to 0 digits. *)
let scan_exp_part max ib =
  if max = 0 then max else
  let c = Scanning.peek_char ib in
  if Scanning.eof ib then max else
  match c with
  | 'e' | 'E' as c ->
    scan_optionally_signed_decimal_int (Scanning.store_char max ib c) ib
  | _ -> max
;;

(* Scan the integer part of a floating point number, (not using the
   Caml lexical convention since the integer part can be empty):
   an optional sign, followed by a possibly empty sequence of decimal
   digits (e.g. -.1). *)
let scan_int_part max ib =
  let max = scan_sign max ib in
  scan_decimal_digits max ib
;;

(*
    For the time being we have (as found in scanf.mli):
    The field width is composed of an optional integer literal
    indicating the maximal width of the token to read.
    Unfortunately, the type-checker let the user write an optional precision,
    since this is valid for printf format strings.

   Thus, the next step for Scanf is to support a full width indication, more
   or less similar to the one for printf, possibly extended to the
   specification of a [max, min] range for the width of the token read for
   strings. Something like the following spec for scanf.mli:

   The optional [width] is an integer indicating the maximal
   width of the token read. For instance, [%6d] reads an integer,
   having at most 6 characters.

   The optional [precision] is a dot [.] followed by an integer:
   - in the floating point number conversions ([%f], [%e], [%g], [%F], [%E], and
   [%F] conversions, the [precision] indicates the maximum number of digits
   that may follow the decimal point. For instance, [%.4f] reads a [float]
   with at most 4 fractional digits,
   - in the string conversions ([%s], [%S], [%\[ range \]]), and in the
   integer number conversions ([%i], [%d], [%u], [%x], [%o], and their
   [int32], [int64], and [native_int] correspondent), the
   [precision] indicates the required minimum width of the token read,
   - on all other conversions, the width and precision are meaningless and
   ignored (FIXME: lead to a runtime error ? type checking error ?).

*)
let scan_float max max_frac_part ib =
  let max = scan_int_part max ib in
  if max = 0 then max, max_frac_part else
  let c = Scanning.peek_char ib in
  if Scanning.eof ib then max, max_frac_part else
  match c with
  | '.' ->
    let max = Scanning.store_char max ib c in
    let max_precision = min max max_frac_part in
    let max = max - (max_precision - scan_frac_part max_precision ib) in
    scan_exp_part max ib, max_frac_part
  | c ->
    scan_exp_part max ib, max_frac_part
;;

let scan_Float max max_frac_part ib =
  let max = scan_optionally_signed_decimal_int max ib in
  if max = 0 then bad_float () else
  let c = Scanning.peek_char ib in
  if Scanning.eof ib then bad_float () else
  match c with
  | '.' ->
    let max = Scanning.store_char max ib c in
    let max_precision = min max max_frac_part in
    let max = max - (max_precision - scan_frac_part max_precision ib) in
    let max = scan_frac_part max ib in
    scan_exp_part max ib
  | 'e' | 'E' ->
    scan_exp_part max ib
  | c -> bad_float ()
;;

(* Scan a regular string:
   stops when encountering a space, if no scanning indication has been given;
   otherwise, stops when encountering one of the characters in the scanning
   indication list [stp].
   It also stops at end of file or when the maximum number of characters has
   been read.*)
let scan_string stp max ib =
  let rec loop max =
    if max = 0 then max else
    let c = Scanning.peek_char ib in
    if Scanning.eof ib then max else
    if stp = [] then
      match c with
      | ' ' | '\t' | '\n' | '\r' -> max
      | c -> loop (Scanning.store_char max ib c) else
    if List.memq c stp then Scanning.skip_char max ib else
    loop (Scanning.store_char max ib c) in
  loop max
;;

(* Scan a char: peek strictly one character in the input, whatsoever. *)
let scan_char max ib =
  (* The case max = 0 could not happen here, since it is tested before
     calling scan_char, in the main scanning function.
    if max = 0 then bad_token_length "a character" else *)
  Scanning.store_char max ib (Scanning.checked_peek_char ib)
;;

let char_for_backslash = function
  | 'n' -> '\010'
  | 'r' -> '\013'
  | 'b' -> '\008'
  | 't' -> '\009'
  | c -> c
;;

(* The integer value corresponding to the facial value of a valid
   decimal digit character. *)
let decimal_value_of_char c = int_of_char c - int_of_char '0';;

let char_for_decimal_code c0 c1 c2 =
  let c =
    100 * decimal_value_of_char c0 +
     10 * decimal_value_of_char c1 +
          decimal_value_of_char c2 in
  if c < 0 || c > 255 then
    bad_input
      (Printf.sprintf
         "bad character decimal encoding \\%c%c%c" c0 c1 c2) else
  char_of_int c
;;

(* The integer value corresponding to the facial value of a valid
   hexadecimal digit character. *)
let hexadecimal_value_of_char c =
  let d = int_of_char c in
  (* Could also be:
    if d <= int_of_char '9' then d - int_of_char '0' else
    if d <= int_of_char 'F' then 10 + d - int_of_char 'A' else
    if d <= int_of_char 'f' then 10 + d - int_of_char 'a' else assert false
  *)
  if d >= int_of_char 'a' then
    d - 87 (* 10 + int_of_char c - int_of_char 'a' *) else
  if d >= int_of_char 'A' then
    d - 55  (* 10 + int_of_char c - int_of_char 'A' *) else
    d - int_of_char '0'
;;

let char_for_hexadecimal_code c1 c2 =
  let c =
    16 * hexadecimal_value_of_char c1 +
         hexadecimal_value_of_char c2 in
  if c < 0 || c > 255 then
    bad_input
      (Printf.sprintf "bad character hexadecimal encoding \\%c%c" c1 c2) else
  char_of_int c
;;

(* Called in particular when encountering '\\' as starter of a char.
   Stops before the corresponding '\''. *)
let check_next_char message max ib =
  if max = 0 then bad_token_length message else
  let c = Scanning.peek_char ib in
  if Scanning.eof ib then bad_end_of_input message else
  c
;;

let check_next_char_for_char = check_next_char "a Char";;
let check_next_char_for_string = check_next_char "a String";;

let scan_backslash_char max ib =
  match check_next_char_for_char max ib with
  | '\\' | '\'' | '\"' | 'n' | 't' | 'b' | 'r' as c ->
    Scanning.store_char max ib (char_for_backslash c)
  | '0' .. '9' as c ->
    let get_digit () =
      let c = Scanning.next_char ib in
      match c with
      | '0' .. '9' as c -> c
      | c -> bad_input_escape c in
    let c0 = c in
    let c1 = get_digit () in
    let c2 = get_digit () in
    Scanning.store_char (max - 2) ib (char_for_decimal_code c0 c1 c2)
  | 'x' ->
    let get_digit () =
      let c = Scanning.next_char ib in
      match c with
      | '0' .. '9' | 'A' .. 'F' | 'a' .. 'f' as c -> c
      | c -> bad_input_escape c in
    let c1 = get_digit () in
    let c2 = get_digit () in
    Scanning.store_char (max - 2) ib (char_for_hexadecimal_code c1 c2)
  | c ->
    bad_input_escape c
;;

(* Scan a character (a Caml token). *)
let scan_Char max ib =

  let rec find_start max =
    match Scanning.checked_peek_char ib with
    | '\'' -> find_char (Scanning.ignore_char max ib)
    | c -> character_mismatch '\'' c

  and find_char max =
    match check_next_char_for_char max ib with
    | '\\' -> find_stop (scan_backslash_char (Scanning.ignore_char max ib) ib)
    | c -> find_stop (Scanning.store_char max ib c)

  and find_stop max =
    match check_next_char_for_char max ib with
    | '\'' -> Scanning.ignore_char max ib
    | c -> character_mismatch '\'' c in

  find_start max
;;

(* Scan a delimited string (a Caml token). *)
let scan_String max ib =

  let rec find_start max =
    match Scanning.checked_peek_char ib with
    | '\"' -> find_stop (Scanning.ignore_char max ib)
    | c -> character_mismatch '\"' c

  and find_stop max =
    match check_next_char_for_string max ib with
    | '\"' -> Scanning.ignore_char max ib
    | '\\' -> scan_backslash (Scanning.ignore_char max ib)
    | c -> find_stop (Scanning.store_char max ib c)

  and scan_backslash max =
    match check_next_char_for_string max ib with
    | '\r' -> skip_newline (Scanning.ignore_char max ib)
    | '\n' -> skip_spaces (Scanning.ignore_char max ib)
    | c -> find_stop (scan_backslash_char max ib)

  and skip_newline max =
    match check_next_char_for_string max ib with
    | '\n' -> skip_spaces (Scanning.ignore_char max ib)
    | _ -> find_stop (Scanning.store_char max ib '\r')

  and skip_spaces max =
    match check_next_char_for_string max ib with
    | ' ' -> skip_spaces (Scanning.ignore_char max ib)
    | _ -> find_stop max in

  find_start max
;;

(* Scan a boolean (a Caml token). *)
let scan_bool max ib =
  if max < 4 then bad_token_length "a boolean" else
  let c = Scanning.checked_peek_char ib in
  let m =
    match c with
    | 't' -> 4
    | 'f' -> 5
    | c ->
      bad_input
        (Printf.sprintf "the character %C cannot start a boolean" c) in
  scan_string [] (min max m) ib
;;

(* Reading char sets in %[...] conversions. *)
type char_set =
   | Pos_set of string (* Positive (regular) set. *)
   | Neg_set of string (* Negative (complementary) set. *)
;;

(* Char sets are read as sub-strings in the format string. *)
let read_char_set fmt i =
  let lim = Sformat.length fmt - 1 in

  let rec find_in_set j =
    if j > lim then incomplete_format fmt else
    match Sformat.get fmt j with
    | ']' -> j
    | c -> find_in_set (succ j)

  and find_set i =
    if i > lim then incomplete_format fmt else
    match Sformat.get fmt i with
    | ']' -> find_in_set (succ i)
    | c -> find_in_set i in

  if i > lim then incomplete_format fmt else
  match Sformat.get fmt i with
  | '^' ->
    let i = succ i in
    let j = find_set i in
    j, Neg_set (Sformat.sub fmt (Sformat.index_of_int i) (j - i))
  | _ ->
    let j = find_set i in
    j, Pos_set (Sformat.sub fmt (Sformat.index_of_int i) (j - i))
;;

(* Char sets are now represented as bit vectors that are represented as
   byte strings. *)

(* Bit manipulations into bytes. *)
let set_bit_of_byte byte idx b =
  (b lsl idx) lor (byte land (* mask idx *) (lnot (1 lsl idx)))
;;

let get_bit_of_byte byte idx = (byte lsr idx) land 1;;

(* Bit manipulations in vectors of bytes represented as strings. *)
let set_bit_of_range r c b =
  let idx = c land 0x7 in
  let ydx = c lsr 3 in
  let byte = r.[ydx] in
  r.[ydx] <- char_of_int (set_bit_of_byte (int_of_char byte) idx b)
;;

let get_bit_of_range r c =
  let idx = c land 0x7 in
  let ydx = c lsr 3 in
  let byte = r.[ydx] in
  get_bit_of_byte (int_of_char byte) idx
;;

(* Char sets represented as bit vectors represented as fixed length byte
   strings. *)
(* Create a full or empty set of chars. *)
let make_range bit =
  let c = char_of_int (if bit = 0 then 0 else 0xFF) in
  String.make 32 c
;;

(* Test if a char belongs to a set of chars. *)
let get_char_in_range r c = get_bit_of_range r (int_of_char c);;

let bit_not b = (lnot b) land 1;;

(* Build the bit vector corresponding to the set of characters
   that belongs to the string argument [set].
   (In the [Scanf] module [set] is always a sub-string of the format.) *)
let make_char_bit_vect bit set =
  let r = make_range (bit_not bit) in
  let lim = String.length set - 1 in
  let rec loop bit rp i =
    if i <= lim then
    match set.[i] with
    | '-' when rp ->
      (* if i = 0 then rp is false (since the initial call is
         loop bit false 0). Hence i >= 1 and the following is safe. *)
      let c1 = set.[i - 1] in
      let i = succ i in
      if i > lim then loop bit false (i - 1) else
      let c2 = set.[i] in
      for j = int_of_char c1 to int_of_char c2 do
        set_bit_of_range r j bit done;
      loop bit false (succ i)
    | c ->
      set_bit_of_range r (int_of_char set.[i]) bit;
      loop bit true (succ i) in
  loop bit false 0;
  r
;;

(* Compute the predicate on chars corresponding to a char set. *)
let make_pred bit set stp =
  let r = make_char_bit_vect bit set in
  List.iter
    (fun c -> set_bit_of_range r (int_of_char c) (bit_not bit)) stp;
  (fun c -> get_char_in_range r c)
;;

let make_setp stp char_set =
  match char_set with
  | Pos_set set ->
    begin match String.length set with
    | 0 -> (fun c -> 0)
    | 1 ->
      let p = set.[0] in
      (fun c -> if c == p then 1 else 0)
    | 2 ->
      let p1 = set.[0] and p2 = set.[1] in
      (fun c -> if c == p1 || c == p2 then 1 else 0)
    | 3 ->
      let p1 = set.[0] and p2 = set.[1] and p3 = set.[2] in
      if p2 = '-' then make_pred 1 set stp else
      (fun c -> if c == p1 || c == p2 || c == p3 then 1 else 0)
    | n -> make_pred 1 set stp
    end
  | Neg_set set ->
    begin match String.length set with
    | 0 -> (fun c -> 1)
    | 1 ->
      let p = set.[0] in
      (fun c -> if c != p then 1 else 0)
    | 2 ->
      let p1 = set.[0] and p2 = set.[1] in
      (fun c -> if c != p1 && c != p2 then 1 else 0)
    | 3 ->
      let p1 = set.[0] and p2 = set.[1] and p3 = set.[2] in
      if p2 = '-' then make_pred 0 set stp else
      (fun c -> if c != p1 && c != p2 && c != p3 then 1 else 0)
    | n -> make_pred 0 set stp
    end
;;

let setp_table = Hashtbl.create 7;;

let add_setp stp char_set setp =
  let char_set_tbl =
    try Hashtbl.find setp_table char_set with
    | Not_found ->
      let char_set_tbl = Hashtbl.create 3 in
      Hashtbl.add setp_table char_set char_set_tbl;
      char_set_tbl in
  Hashtbl.add char_set_tbl stp setp
;;

let find_setp stp char_set =
  try Hashtbl.find (Hashtbl.find setp_table char_set) stp with
  | Not_found ->
    let setp = make_setp stp char_set in
    add_setp stp char_set setp;
    setp
;;

let scan_chars_in_char_set stp char_set max ib =
  let rec loop_pos1 cp1 max =
    if max = 0 then max else
    let c = Scanning.peek_char ib in
    if Scanning.eof ib then max else
    if c == cp1
    then loop_pos1 cp1 (Scanning.store_char max ib c)
    else max
  and loop_pos2 cp1 cp2 max =
    if max = 0 then max else
    let c = Scanning.peek_char ib in
    if Scanning.eof ib then max else
    if c == cp1 || c == cp2
    then loop_pos2 cp1 cp2 (Scanning.store_char max ib c)
    else max
  and loop_pos3 cp1 cp2 cp3 max =
    if max = 0 then max else
    let c = Scanning.peek_char ib in
    if Scanning.eof ib then max else
    if c == cp1 || c == cp2 || c == cp3
    then loop_pos3 cp1 cp2 cp3 (Scanning.store_char max ib c)
    else max
  and loop_neg1 cp1 max =
    if max = 0 then max else
    let c = Scanning.peek_char ib in
    if Scanning.eof ib then max else
    if c != cp1
    then loop_neg1 cp1 (Scanning.store_char max ib c)
    else max
  and loop_neg2 cp1 cp2 max =
    if max = 0 then max else
    let c = Scanning.peek_char ib in
    if Scanning.eof ib then max else
    if c != cp1 && c != cp2
    then loop_neg2 cp1 cp2 (Scanning.store_char max ib c)
    else max
  and loop_neg3 cp1 cp2 cp3 max =
    if max = 0 then max else
    let c = Scanning.peek_char ib in
    if Scanning.eof ib then max else
    if c != cp1 && c != cp2 && c != cp3
    then loop_neg3 cp1 cp2 cp3 (Scanning.store_char max ib c)
    else max
  and loop setp max =
    if max = 0 then max else
    let c = Scanning.peek_char ib in
    if Scanning.eof ib then max else
    if setp c == 1
    then loop setp (Scanning.store_char max ib c)
    else max in

  let max =
    match char_set with
    | Pos_set set ->
      begin match String.length set with
      | 0 -> loop (fun c -> 0) max
      | 1 -> loop_pos1 set.[0] max
      | 2 -> loop_pos2 set.[0] set.[1] max
      | 3 when set.[1] != '-' -> loop_pos3 set.[0] set.[1] set.[2] max
      | n -> loop (find_setp stp char_set) max end
    | Neg_set set ->
      begin match String.length set with
      | 0 -> loop (fun c -> 1) max
      | 1 -> loop_neg1 set.[0] max
      | 2 -> loop_neg2 set.[0] set.[1] max
      | 3 when set.[1] != '-' -> loop_neg3 set.[0] set.[1] set.[2] max
      | n -> loop (find_setp stp char_set) max end in
  ignore_stoppers stp ib;
  max
;;

let get_count t ib =
  match t with
  | 'l' -> Scanning.line_count ib
  | 'n' -> Scanning.char_count ib
  | _ -> Scanning.token_count ib
;;

let rec skip_whites ib =
  let c = Scanning.peek_char ib in
  if not (Scanning.eof ib) then begin
    match c with
    | ' ' | '\t' | '\n' | '\r' ->
      Scanning.invalidate_current_char ib; skip_whites ib
    | _ -> ()
  end
;;

(* The global error report function for [Scanf]. *)
let scanf_bad_input ib = function
  | Scan_failure s | Failure s ->
    let i = Scanning.char_count ib in
    bad_input (Printf.sprintf "scanf: bad input at char number %i: ``%s''" i s)
  | x -> raise x
;;

let list_iter_i f l =
  let rec loop i = function
  | [] -> ()
  | [x] -> f i x (* Tail calling [f] *)
  | x :: xs -> f i x; loop (succ i) xs in
  loop 0 l
;;

let ascanf sc fmt =
  let ac = Tformat.ac_of_format fmt in
  match ac.Tformat.ac_rdrs with
  | 0 ->
    Obj.magic (fun f -> sc fmt [||] f)
  | 1 ->
    Obj.magic (fun x f -> sc fmt [| Obj.repr x |] f)
  | 2 ->
    Obj.magic (fun x y f -> sc fmt [| Obj.repr x; Obj.repr y; |] f)
  | 3 ->
    Obj.magic
      (fun x y z f -> sc fmt [| Obj.repr x; Obj.repr y; Obj.repr z; |] f)
  | nargs ->
    let rec loop i args =
      if i >= nargs then
        let a = Array.make nargs (Obj.repr 0) in
        list_iter_i (fun i arg -> a.(nargs - i - 1) <- arg) args;
        Obj.magic (fun f -> sc fmt a f)
      else Obj.magic (fun x -> loop (succ i) (x :: args)) in
    loop 0 []
;;

(* The [scan_format] main scanning function.
   It takes as arguments:
     - an input buffer [ib] from which to read characters,
     - an error handling function [ef],
     - a format [fmt] that specifies what to read in the input,
     - a vector of user's defined readers [rv],
     - and a function [f] to pass the tokens read to.

   Then [scan_format] scans the format and the input buffer in parallel to
   find out tokens as specified by the format; when it finds one token, it
   converts it as specified, remembers the converted value as a future
   argument to the function [f], and continues scanning.

   If the entire scanning succeeds (i.e. the format string has been
   exhausted and the buffer has provided tokens according to the
   format string), [f] is applied to the tokens read.

   If the scanning or some conversion fails, the main scanning function
   aborts and applies the scanning buffer and a string that explains
   the error to the error handling function [ef] (the error continuation). *)

let scan_format ib ef fmt rv f =

  let limr = Array.length rv - 1 in

  let return v = Obj.magic v () in
  let delay f x () = f x in
  let stack f = delay (return f) in
  let no_stack f x = f in

  let rec scan fmt =

    let lim = Sformat.length fmt - 1 in

    let rec scan_fmt ir f i =
      if i > lim then ir, f else
      match Sformat.get fmt i with
      | ' ' -> skip_whites ib; scan_fmt ir f (succ i)
      | '%' -> scan_skip ir f (succ i)
      | '@' ->
        let i = succ i in
        if i > lim then incomplete_format fmt else begin
        check_char ib (Sformat.get fmt i);
        scan_fmt ir f (succ i) end
      | c -> check_char ib c; scan_fmt ir f (succ i)

    and scan_skip ir f i =
      if i > lim then ir, f else
      match Sformat.get fmt i with
      | '_' -> scan_limits true ir f (succ i)
      | _ -> scan_limits false ir f i

    and scan_limits skip ir f i =
      if i > lim then ir, f else
      let max_opt, min_opt, i =
        match Sformat.get fmt i with
        | '0' .. '9' as conv ->
          let rec read_width accu i =
            if i > lim then accu, i else
            match Sformat.get fmt i with
            | '0' .. '9' as c ->
              let accu = 10 * accu + decimal_value_of_char c in
              read_width accu (succ i)
            | _ -> accu, i in

          let max, i = read_width (decimal_value_of_char conv) (succ i) in

          if i > lim then incomplete_format fmt else
          begin
            match Sformat.get fmt i with
            | '.' ->
              let min, i = read_width 0 (succ i) in
              (Some max, Some min, i)
            | _ -> Some max, None, i
          end
        | _ -> None, None, i in

      scan_conversion skip max_opt min_opt ir f i

    and scan_conversion skip max_opt min_opt ir f i =
      let stack = if skip then no_stack else stack in
      let max = int_max max_opt in
      let min = int_min min_opt in
      match Sformat.get fmt i with
      | '%' as conv ->
        check_char ib conv; scan_fmt ir f (succ i)
      | 's' ->
        let i, stp = scan_fmt_stoppers (succ i) in
        let _x = scan_string stp max ib in
        scan_fmt ir (stack f (token_string ib)) (succ i)
      | 'S' ->
        let _x = scan_String max ib in
        scan_fmt ir (stack f (token_string ib)) (succ i)
      | '[' (* ']' *) ->
        let i, char_set = read_char_set fmt (succ i) in
        let i, stp = scan_fmt_stoppers (succ i) in
        let _x = scan_chars_in_char_set stp char_set max ib in
        scan_fmt ir (stack f (token_string ib)) (succ i)
      | ('c' | 'C') when max = 0 ->
        let c = Scanning.checked_peek_char ib in
        scan_fmt ir (stack f c) (succ i)
      | 'c' ->
        let _x = scan_char max ib in
        scan_fmt ir (stack f (token_char ib)) (succ i)
      | 'C' ->
        let _x = scan_Char max ib in
        scan_fmt ir (stack f (token_char ib)) (succ i)
      | 'd' | 'i' | 'o' | 'u' | 'x' | 'X' as conv ->
        let _x = scan_int_conv conv max min ib in
        scan_fmt ir (stack f (token_int conv ib)) (succ i)
      | 'N' as conv ->
        scan_fmt ir (stack f (get_count conv ib)) (succ i)
      | 'f' | 'e' | 'E' | 'g' | 'G' ->
        let min = float_min min_opt in
        let _x = scan_float max min ib in
        scan_fmt ir (stack f (token_float ib)) (succ i)
      | 'F' ->
        let min = float_min min_opt in
        let _x = scan_Float max min ib in
        scan_fmt ir (stack f (token_float ib)) (succ i)
(*      | 'B' | 'b' when max = Some 0 ->
        let _x = scan_bool max ib in
        scan_fmt ir (stack f (token_int ib)) (succ i) *)
      | 'B' | 'b' ->
        let _x = scan_bool max ib in
        scan_fmt ir (stack f (token_bool ib)) (succ i)
      | 'r' ->
        if ir > limr then assert false else
        let token = Obj.magic rv.(ir) ib in
        scan_fmt (succ ir) (stack f token) (succ i)
      | 'l' | 'n' | 'L' as conv0 ->
        let i = succ i in
        if i > lim then scan_fmt ir (stack f (get_count conv0 ib)) i else begin
        match Sformat.get fmt i with
        (* This is in fact an integer conversion (e.g. %ld, %ni, or %Lo). *)
        | 'd' | 'i' | 'o' | 'u' | 'x' | 'X' as conv1 ->
          let _x = scan_int_conv conv1 max min ib in
          (* Look back to the character that triggered the integer conversion
             (this character is either 'l', 'n' or 'L') to find the
             conversion to apply to the integer token read. *)
          begin match conv0 with
          | 'l' -> scan_fmt ir (stack f (token_int32 conv1 ib)) (succ i)
          | 'n' -> scan_fmt ir (stack f (token_nativeint conv1 ib)) (succ i)
          | _ -> scan_fmt ir (stack f (token_int64 conv1 ib)) (succ i) end
        (* This is not an integer conversion, but a regular %l, %n or %L. *)
        | _ -> scan_fmt ir (stack f (get_count conv0 ib)) i end
      | '!' ->
        if Scanning.end_of_input ib then scan_fmt ir f (succ i)
        else bad_input "end of input not found"
      | ',' ->
        scan_fmt ir f (succ i)
      | '(' | '{' as conv (* ')' '}' *) ->
        let i = succ i in
        (* Find the static specification for the format to read. *)
        let j =
          Tformat.sub_format
            incomplete_format bad_conversion conv fmt i in
        let mf = Sformat.sub fmt (Sformat.index_of_int i) (j - 2 - i) in
        (* Read the specified format string in the input buffer,
           and check its correctness. *)
        let _x = scan_String max ib in
        let rf = token_string ib in
        if not (compatible_format_type rf mf) then format_mismatch rf mf else
        (* For conversion %{%}, just return this format string as the token
           read. *)
        if conv = '{' (* '}' *) then scan_fmt ir (stack f rf) j else
        (* Or else, read according to the format string just read. *)
        let ir, nf = scan (string_to_format rf) ir (stack f rf) 0 in
        (* Return the format string read and the value just read,
           then go on with the rest of the format. *)
        scan_fmt ir nf j

      | c -> bad_conversion fmt i c

    and scan_fmt_stoppers i =
      if i > lim then i - 1, [] else
      match Sformat.get fmt i with
      | '@' when i < lim -> let i = succ i in i, [Sformat.get fmt i]
      | '@' when i = lim -> incomplete_format fmt
      | _ -> i - 1, [] in

    scan_fmt in


  Scanning.reset_token ib;

  let v =
    try snd (scan fmt 0 (fun () -> f) 0) with
    | (Scan_failure _ | Failure _ | End_of_file) as exc ->
      stack (delay ef ib) exc in
  return v
;;

let mkscanf ib ef fmt =
  let sc = scan_format ib ef in
  ascanf sc fmt
;;

let kscanf ib ef fmt = mkscanf ib ef fmt;;

let bscanf ib = kscanf ib scanf_bad_input;;

let sscanf s = bscanf (Scanning.from_string s);;

let bscanf_format ib fmt f =
  let fmt = Sformat.unsafe_to_string fmt in
  let fmt1 =
    ignore (scan_String max_int ib);
    token_string ib in
  if not (compatible_format_type fmt1 fmt) then
    format_mismatch fmt1 fmt else
  f (string_to_format fmt1)
;;

let sscanf_format s fmt = bscanf_format (Scanning.from_string s) fmt;;

let string_to_String s =
  let l = String.length s in
  let b = Buffer.create (l + 2) in
  Buffer.add_char b '\"';
  for i = 0 to l - 1 do
    let c = s.[i] in
    if c = '\"' then Buffer.add_char b '\\';
    Buffer.add_char b c;
  done;
  Buffer.add_char b '\"';
  Buffer.contents b
;;

let format_from_string s fmt =
  sscanf_format (string_to_String s) fmt (fun x -> x)
;;

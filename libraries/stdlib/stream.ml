(***********************************************************************)
(*                                                                     *)
(*                             Ocaml                                   *)
(*                                                                     *)
(*        Daniel de Rauglaudre, projet Cristal, INRIA Rocquencourt     *)
(*                                                                     *)
(*  Copyright 1997 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the GNU Library General Public License, with    *)
(*  the special exception on linking described in file ../LICENSE.     *)
(*                                                                     *)
(***********************************************************************)

(* $Id: stream.ml 8893 2008-06-18 15:35:02Z mauny $ *)

(* The fields of type t are not mutable to preserve polymorphism of
   the empty stream. This is type safe because the empty stream is never
   patched. *)

type 'a t = { count : int; data : 'a data }
and 'a data =
    Sempty
  | Scons of 'a * 'a data
  | Sapp of 'a data * 'a data
  | Slazy of 'a data Lazy.t
  | Sgen of 'a gen
and 'a gen = { mutable curr : 'a option option; func : int -> 'a option }
;;
exception Failure;;
exception Error of string;;

external count : 'a t -> int = "%field0";;
external set_count : 'a t -> int -> unit = "%setfield0";;
let set_data (s : 'a t) (d : 'a data) =
  Obj.set_field (Obj.repr s) 1 (Obj.repr d)
;;

let rec get_data count d = match d with
 (* Returns either Sempty or Scons(a, _) even when d is a generator
    or a buffer. In those cases, the item a is seen as extracted from
 the generator/buffer.
 The count parameter is used for calling `Sgen-functions'.  *)
   Sempty | Scons (_, _) -> d
 | Sapp (d1, d2) ->
     begin match get_data count d1 with
       Scons (a, d11) -> Scons (a, Sapp (d11, d2))
     | Sempty -> get_data count d2
     | _ -> assert false
     end
 | Sgen {curr = Some None; func = _ } -> Sempty
 | Sgen ({curr = Some(Some a); func = f} as g) ->
     g.curr <- None; Scons(a, d)
 | Sgen g ->
     begin match g.func count with
       None -> g.curr <- Some(None); Sempty
     | Some a -> Scons(a, d)
         (* Warning: anyone using g thinks that an item has been read *)
     end
 | Slazy f -> get_data count (Lazy.force f)
;;

let rec peek s =
 (* consult the first item of s *)
 match s.data with
   Sempty -> None
 | Scons (a, _) -> Some a
 | Sapp (_, _) ->
     begin match get_data s.count s.data with
       Scons(a, _) as d -> set_data s d; Some a
     | Sempty -> None
     | _ -> assert false
     end
 | Slazy f -> set_data s (Lazy.force f); peek s
 | Sgen {curr = Some a} -> a
 | Sgen g -> let x = g.func s.count in g.curr <- Some x; x
;;

let rec junk s =
  match s.data with
    Scons (_, d) -> set_count s (succ s.count); set_data s d
  | Sgen ({curr = Some _} as g) -> set_count s (succ s.count); g.curr <- None
  | _ ->
      match peek s with
        None -> ()
      | Some _ -> junk s
;;

let rec nget n s =
  if n <= 0 then [], s.data, 0
  else
    match peek s with
      Some a ->
        junk s;
        let (al, d, k) = nget (pred n) s in a :: al, Scons (a, d), succ k
    | None -> [], s.data, 0
;;

let npeek n s =
  let (al, d, len) = nget n s in set_count s (s.count - len); set_data s d; al
;;

let next s =
  match peek s with
    Some a -> junk s; a
  | None -> raise Failure
;;

let empty s =
  match peek s with
    Some _ -> raise Failure
  | None -> ()
;;

let iter f strm =
  let rec do_rec () =
    match peek strm with
      Some a -> junk strm; ignore(f a); do_rec ()
    | None -> ()
  in
  do_rec ()
;;

(* Stream building functions *)

let from f = {count = 0; data = Sgen {curr = None; func = f}};;

let of_list l =
  {count = 0; data = List.fold_right (fun x l -> Scons (x, l)) l Sempty}
;;

let of_string s =
  from (fun c -> if c < String.length s then Some s.[c] else None)
;;

(* Stream expressions builders *)

let iapp i s = {count = 0; data = Sapp (i.data, s.data)};;
let icons i s = {count = 0; data = Scons (i, s.data)};;
let ising i = {count = 0; data = Scons (i, Sempty)};;

let lapp f s =
  {count = 0; data = Slazy (lazy(Sapp ((f ()).data, s.data)))}
;;
let lcons f s = {count = 0; data = Slazy (lazy(Scons (f (), s.data)))};;
let lsing f = {count = 0; data = Slazy (lazy(Scons (f (), Sempty)))};;

let sempty = {count = 0; data = Sempty};;
let slazy f = {count = 0; data = Slazy (lazy(f ()).data)};;

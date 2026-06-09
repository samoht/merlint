(* Good examples - cases carry no redundant shared prefix. *)

(* Bare constructors; the type name supplies the context. *)
type status =
  | Pending
  | Running
  | Done

(* Bare fields. *)
type point = { x : int; y : int }

(* Shared leading letters but no underscore-delimited word in common. *)
type fruit =
  | Apple
  | Apricot

(* "start" and "end" are not shared by every field, so nothing is redundant. *)
type span = { start_line : int; start_col : int; end_line : int; end_col : int }

(* A single constructor cannot share a prefix with anything. *)
type wrapper = Wrapped of int

(** Shared detector for empty Alcotest / alcobar suites of the form
    [let suite = ("name", [])]. *)

open Ocaml_parsing

val is_empty_list : Parsetree.expression -> bool
(** [is_empty_list e] is [true] iff [e] is [[]], possibly under one or more
    [open ... in] / [M.[]] layers. *)

val find : Parsetree.structure -> Location.t option
(** [find s] returns the binding location of any top-level
    [let suite = ("name", [])], or [None]. *)

val check :
  prefix:string -> mk_payload:(string -> 'a) -> Context.file -> 'a Issue.t list
(** [check ~prefix ~mk_payload ctx] reports an issue for files whose basename
    starts with [<prefix>_] and whose [let suite = ...] binding has an empty
    test list. The suite name (basename minus [<prefix>_] minus [.ml]) is fed to
    [mk_payload] to build the rule-specific payload. *)

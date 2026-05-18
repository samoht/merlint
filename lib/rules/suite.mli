(** Typedtree queries for test-suite definitions and references. *)

type binding = { loc : Location.t; name : string option; empty : bool }
(** A top-level [suite] binding extracted from a test module. *)

val is_empty_list : Ocaml_typing.Typedtree.expression -> bool
(** [is_empty_list expr] checks whether [expr] is the empty list constructor. *)

val bindings : filename:string -> File_view.t -> binding list
(** [bindings ~filename view] returns top-level [suite] bindings in [view]. *)

val empty : filename:string -> File_view.t -> Location.t option
(** [empty ~filename view] returns the location of an empty top-level [suite]
    binding, if present. *)

val check_empty :
  prefix:string -> mk_payload:(string -> 'a) -> Context.file -> 'a Issue.t list
(** [check_empty ~prefix ~mk_payload ctx] implements the shared E621/E726 empty
    suite check for [test_*] or [fuzz_*] modules. *)

val references : File_view.t -> string -> bool
(** [references view module_name] checks whether [view] references
    [module_name].suite. *)

val references_with_prefix : File_view.t -> prefix:string -> bool
(** [references_with_prefix view ~prefix] checks whether [view] references a
    module whose name starts with [prefix] and exposes [suite]. *)

val calls_test_case : File_view.t -> bool
(** [calls_test_case view] checks whether [view] calls an Alcotest test-case
    constructor. *)

val is_compliant_view : expected:string -> File_view.t -> bool
(** [is_compliant_view ~expected view] checks that an interface exposes exactly
    one [suite] value with the expected test-suite type. *)

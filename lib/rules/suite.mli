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

type callers
(** Precomputed names that reference a [.suite] value. *)

val callers : File_view.t -> callers option
(** [callers view] extracts [.suite] callers once for repeated lookups. *)

val references_in : callers -> string -> bool
(** [references_in callers module_name] checks whether precomputed [callers]
    contains [module_name].suite. *)

(** The result of a typedtree-backed query. Returning this instead of a bare
    [bool] stops callers from reading {!constructor-Unresolved} as a negative
    answer, which is how an absence check ("module X is not referenced") turns
    into a false positive when artefacts are missing. *)
type 'a resolved =
  | Unresolved
      (** No fresh typedtree was available (the [.cmt]/[.cmti] is not built), so
          the query could not run. *)
  | Resolved of 'a  (** The query ran against a loaded typedtree. *)

val references : File_view.t -> string -> bool resolved
(** [references view module_name] is whether [view] references
    [module_name].suite, or {!constructor-Unresolved} when the typedtree is not
    built. *)

val references_with_prefix : File_view.t -> prefix:string -> bool resolved
(** [references_with_prefix view ~prefix] is whether [view] references a module
    whose name starts with [prefix] and exposes [suite], or
    {!constructor-Unresolved} when the typedtree is not built. *)

val calls_test_case : File_view.t -> bool resolved
(** [calls_test_case view] is whether [view] calls an Alcotest test-case
    constructor, or {!constructor-Unresolved} when the typedtree is not built.
*)

val is_compliant_view : expected:string -> File_view.t -> bool
(** [is_compliant_view ~expected view] checks that an interface exposes exactly
    one [suite] value with the expected test-suite type. *)

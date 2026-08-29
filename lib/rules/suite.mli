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
(** [callers view] extracts [.suite] callers once for repeated lookups, and is
    [None] where no build artefact describes [view]: see {!type-resolved}. *)

val references_in : callers -> string -> bool
(** [references_in callers module_name] checks whether precomputed [callers]
    contains [module_name].suite. *)

val missing_references : File_view.t -> string list -> string list
(** [missing_references view modules] is the subset of [modules] (capitalized
    module names) whose [<module>.suite] the runner [view] does not reference,
    in input order. Empty where no build artefact describes the runner: an
    unresolved runner answers no absence claims (see {!type-resolved}), it never
    flags every module. The caller set is computed once for the whole list. *)

(** The result of a typedtree-backed query. Returning this instead of a bare
    [bool] stops callers from reading {!constructor-Unresolved} as a negative
    answer, which is how an absence check ("module X is not referenced") turns
    into a false positive when artefacts are missing. *)
type 'a resolved =
  | Unresolved
      (** No [.cmt]/[.cmti] the compiler wrote for this source was available, so
          the query could not run. A typedtree merlint typechecked in place of
          one does not stand in: it recovers from the names it cannot resolve,
          so what it omits is as much a fact about the build directory as about
          the source. *)
  | Resolved of 'a  (** The query ran against a loaded typedtree. *)

val references : File_view.t -> string -> bool resolved
(** [references view module_name] is whether [view] references
    [module_name].suite, or {!constructor-Unresolved} where no artefact
    describes [view]. *)

val references_with_prefix : File_view.t -> prefix:string -> bool resolved
(** [references_with_prefix view ~prefix] is whether [view] references a module
    whose name starts with [prefix] and exposes [suite], or
    {!constructor-Unresolved} where no artefact describes [view]. *)

val calls_test_case : File_view.t -> bool resolved
(** [calls_test_case view] is whether [view] calls an Alcotest test-case
    constructor, or {!constructor-Unresolved} where no artefact describes
    [view]. *)

val is_compliant_view : expected:string -> File_view.t -> bool resolved
(** [is_compliant_view ~expected view] is whether an interface exposes exactly
    one [suite] value with the expected test-suite type, or
    {!constructor-Unresolved} where no artefact describes [view]. The expected
    type cannot be recognised without one, so a caller treating the absent
    answer as a mismatch reports every compliant interface in an unbuilt tree.
*)

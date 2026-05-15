(** Unified per-file view for rules.

    Hides the underlying sources — Merlin outline/dump, compiler-libs parsetree,
    and raw bytes — behind a single API rules call into. A file can be observed
    at multiple levels of richness ([.cmt] typed AST, parsetree, Merlin dump,
    raw bytes); each accessor picks the richest source available and falls back
    gracefully when something is missing. *)

exception Analysis_error of string
(** Raised by the lazy accessors when the underlying source cannot be read (file
    I/O failure, Merlin error, ...). *)

type t

val v :
  filename:string ->
  outline:(unit -> (Outline.t, string) result) ->
  dump:(unit -> (Merlin.Dump.t, string) result) ->
  t
(** [v ~filename ~outline ~dump] builds a fresh view over [filename]. The
    [outline] / [dump] thunks are called on first access and never twice. *)

val filename : t -> string
val content : t -> string

(** {2 Names — qualified identifiers}

    A {!Name.t} is a qualified path: a list of module prefixes plus a base.
    [Stdlib.List.map] is [prefix = ["Stdlib"; "List"]; base = "map"]. *)
module Name : sig
  type t

  val to_string : t -> string
  (** Print as a dotted path, e.g. ["Stdlib.List.map"]. *)

  val base : t -> string
  (** The unqualified rightmost segment. *)

  val prefix : t -> string list
  (** The module path leading up to the base, outermost first. *)

  val equals_path : t -> string list -> bool
  (** [equals_path n path] is [true] iff [path = prefix n @ [base n]]. *)

  val pp : t Fmt.t
end

(** {2 Types — structured shape queries on declared types} *)
module Type_view : sig
  type t

  val is_function : t -> bool
  val returns_option : t -> bool
  val return_type : t -> t option
  val pp : t Fmt.t

  val count_unlabelled : t -> match_:(t -> bool) -> int
  (** [count_unlabelled t ~match_] counts the unlabelled positional argument
      types in a function arrow whose domain satisfies [match_]. *)
end

(** {2 Items — top-level structure of the file (outline)} *)
module Item : sig
  type kind =
    | Value
    | Type
    | Module
    | Module_type
    | Class
    | Class_type
    | Constructor
    | Exception
    | Field
    | Method
    | Label

  type t

  val name : t -> string
  val kind : t -> kind
  val loc : t -> Location.t
  val deprecated : t -> bool
  val children : t -> t list

  val type_sig : t -> Type_view.t option
  (** Parsed type of this item, when one was declared. *)
end

(** {2 References — every use-site of an identifier in the file} *)
module Reference : sig
  type t

  val name : t -> Name.t
  val loc : t -> Location.t option
end

(** {2 Value signatures — [val name : type] in an interface}

    Only populated for [.mli] files (or [Interface] typedtrees). *)
module Value_sig : sig
  type t

  val name : t -> Name.t
  val loc : t -> Location.t option

  val type_path : t -> Name.t option
  (** Outermost type constructor path of the declared type, when the type is a
      [Ttyp_constr] / [Ptyp_constr]; [None] for arrows, tuples, variables, etc.
  *)
end

(** {2 Function applications — [callee arg1 arg2 ...] sites} *)
module Call : sig
  type t
  type arg

  val callee : t -> Name.t
  val args : t -> arg list
  val loc : t -> Location.t

  module Arg : sig
    val loc : arg -> Location.t

    val is_call : arg -> path:string list -> bool
    (** [is_call a ~path] is [true] when [a] is the application of an identifier
        whose qualified name equals [path]. *)
  end
end

(** {2 Top-level accessors} *)

val items : t -> Item.t list
(** Top-level outline of the file. *)

val identifiers : t -> Reference.t list
(** Every value identifier use-site in the file (every [Foo.x] in expression
    position). *)

val patterns : t -> Reference.t list
(** Every constructor / field reference in pattern position. *)

val variants : t -> Reference.t list
(** Every variant constructor occurrence (definition + use). *)

val modules : t -> Reference.t list
(** Every module name reference. *)

val types : t -> Reference.t list
(** Every type declaration in the file. *)

val exceptions : t -> Reference.t list
(** Every exception declaration in the file. *)

val values : t -> Reference.t list
(** Every value definition (a [let] at the top level). *)

val signatures : t -> Value_sig.t list
(** [val] declarations in a signature, for [.mli] sources. *)

val iter_applications : t -> (Call.t -> unit) -> unit
(** [iter_applications t f] applies [f] to every [Pexp_apply] site whose callee
    is a path identifier. *)

(** {2 Legacy accessors — to be removed once all rules migrate} *)

val parsetree : t -> Parsetree.structure option
val functions : t -> (string * Ast.expr) list
val ast : t -> Ast.t
val dump : t -> Merlin.Dump.t
val outline : t -> Outline.t

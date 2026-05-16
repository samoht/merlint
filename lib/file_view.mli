(** Unified per-file view for rules.

    Hides the underlying sources — native Merlin typedtree, compiler-libs
    parsetree, and raw bytes — behind a single API rules call into. A file can
    be observed at multiple levels of richness; each accessor commits to one
    level and is explicit when that level is unavailable.

    Two name-resolution levels are surfaced separately. They are NOT
    interchangeable:

    - {b Typedtree} (resolved): identifiers carry their fully-qualified
      [Path.t]. [Stdlib.Printf.printf], [Cmdliner.Cmd.v], a user's shadowing
      local [Fmt] all show up at their resolved paths. Rules that ask "is this
      the real [Stdlib.X]?" need this level.
    - {b Parsetree} (as-written): identifiers appear exactly as the user typed
      them. [Printf.printf] in source stays [Printf.printf] regardless of
      resolution; a user with a local [Printf] module is indistinguishable from
      the stdlib. Rules that lint surface syntax / convention need this level.

    Resolved accessors return [None] when only parsetree is available. The
    outline accessors prefer typedtree data and degrade to parsetree data. *)

exception Analysis_error of string
(** Raised by the lazy accessors when the underlying source cannot be read (file
    I/O failure, Merlin error, ...). *)

open Ocaml_parsing

type t

val v :
  filename:string ->
  load_content:(unit -> string) ->
  ?typedtree:(unit -> (Merlin.typedtree option, string) result) ->
  ?parsetree:(unit -> (Parsetree.structure option, string) result) ->
  ?signature:(unit -> (Parsetree.signature option, string) result) ->
  outline:(unit -> (Outline.t, string) result) ->
  unit ->
  t
(** [v ~filename ~load_content ?typedtree ?parsetree ?signature ~outline ()]
    builds a fresh view over [filename]. The [load_content] / [typedtree] /
    [parsetree] / [signature] / [outline] thunks are called on first access and
    never twice. When [parsetree] is omitted, the view falls back to parsing
    [load_content] directly. *)

val filename : t -> string
(** [filename t] is the source file this view describes. *)

val content : t -> string
(** [content t] is the raw bytes of the file. *)

val is_resolved : t -> bool
(** [is_resolved t] is [true] iff the AST dump came back at typedtree level.
    Rules use this if they want to know whether the resolved accessors below
    will yield [Some] or [None] for this file. *)

(** {2 Names — qualified identifiers}

    A {!Name.t} is a qualified path: a list of module prefixes plus a base.
    [Stdlib.List.map] is [prefix = ["Stdlib"; "List"]; base = "map"] at
    typedtree level; the same source written [List.map] would parse to
    [prefix = ["List"]; base = "map"] at parsetree level. *)
module Name : sig
  type t

  val to_string : t -> string
  (** [to_string n] prints [n] as a dotted path, e.g. ["Stdlib.List.map"]. *)

  val base : t -> string
  (** [base n] is the unqualified rightmost segment. *)

  val prefix : t -> string list
  (** [prefix n] is the module path leading up to {!base}, outermost first. *)

  val equals_path : t -> string list -> bool
  (** [equals_path n path] is [true] iff [path = prefix n @ [base n]]. *)

  val pp : t Fmt.t
  (** [pp ppf n] prints [n] via {!to_string}. *)
end

(** {2 Types — structured shape queries on declared types} *)
module Type_view : sig
  type t

  val is_function : t -> bool
  (** [is_function t] is [true] when [t] is an arrow type. *)

  val returns_option : t -> bool
  (** [returns_option t] is [true] when [t]'s final return position is
      [_ option]. *)

  val return_type : t -> t option
  (** [return_type t] follows arrow chains and returns the final non-arrow
      target. *)

  val pp : t Fmt.t
  (** [pp ppf t] prints the type using the compiler's pretty-printer. *)

  val count_unlabelled : t -> match_:(t -> bool) -> int
  (** [count_unlabelled t ~match_] counts unlabelled positional argument types
      in a function arrow whose domain satisfies [match_]. *)
end

(** {2 Items — top-level outline structure, always available} *)
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
  (** [name i] is the unqualified name of the declared item. *)

  val kind : t -> kind
  (** [kind i] is the syntactic kind of the declaration. *)

  val loc : t -> Merlin.Location.t
  (** [loc i] is the source location of the declaration. *)

  val deprecated : t -> bool
  (** [deprecated i] is [true] when the declaration carries a [[@deprecated]]
      attribute. *)

  val children : t -> t list
  (** [children i] is the list of nested items declared inside [i] (members of a
      module, fields of a record, ...). *)

  val type_sig : t -> Type_view.t option
  (** [type_sig i] is the parsed type of [i] when one was declared. *)
end

(** {2 References — use-sites of identifiers} *)
module Reference : sig
  type t

  val name : t -> Name.t
  (** [name r] is the qualified name referenced at this use-site. *)

  val loc : t -> Merlin.Location.t option
  (** [loc r] is the source location of the use-site, if Merlin reported one. *)

  val base : t -> string
  (** [base r] is [Name.base (name r)]. *)

  val prefix : t -> string list
  (** [prefix r] is [Name.prefix (name r)]. *)

  val matches_path : t -> string list -> bool
  (** [matches_path r path] is [Name.equals_path (name r) path]. *)
end

(** {2 Value signatures — [val name : type] in an interface} *)
module Value_sig : sig
  type t

  val name : t -> Name.t
  (** [name v] is the value's declared name. *)

  val loc : t -> Merlin.Location.t option
  (** [loc v] is the source location of the declaration, if Merlin reported one.
  *)

  val type_path : t -> Name.t option
  (** Outermost type constructor path of the declared type, when the type is a
      [Ttyp_constr] / [Ptyp_constr]; [None] for arrows, tuples, variables, etc.
  *)
end

(** {2 Function-application sites — parsetree-level syntactic walk}

    [iter_applications] always works (it parses the source directly); it
    surfaces syntax exactly as written and is the right primitive for
    style/convention rules. Rules that need resolved callees should use the
    resolved accessors below instead. *)
module Call : sig
  type t
  type arg

  val callee : t -> Name.t
  (** [callee c] is the qualified name of the function being applied. *)

  val args : t -> arg list
  (** [args c] is the list of arguments at the application site. *)

  val loc : t -> Merlin.Location.t
  (** [loc c] is the source location of the whole application. *)

  module Arg : sig
    val loc : arg -> Merlin.Location.t
    (** [loc a] is the source location of the argument expression. *)

    val is_call : arg -> path:string list -> bool
    (** [is_call a ~path] is [true] when [a] is the application of an identifier
        whose qualified name equals [path]. *)
  end
end

(** {2 Top-level accessors}

    Outline accessors are always available. *)

val items : t -> Item.t list
(** [items t] is the file's top-level outline. *)

(** {3 Resolved (typedtree) — [None] when only parsetree is available}

    These return fully-qualified, resolution-correct names. A rule that matches
    by path uses these; if it gets [None], it should skip the file rather than
    fall back to unresolved names. The engine reports every file where resolved
    info was missing, so silent misses are impossible. *)

val resolved_identifiers : t -> Reference.t list option
(** Every value identifier use-site, fully resolved. *)

val resolved_patterns : t -> Reference.t list option
(** Every constructor / field reference in pattern position, resolved. *)

val resolved_variants : t -> Reference.t list option
(** Every variant constructor occurrence (definition + use), resolved. *)

val resolved_modules : t -> Reference.t list option
(** Every module name reference, resolved. *)

val resolved_types : t -> Reference.t list option
(** Every type declaration in the file, resolved. *)

val resolved_exceptions : t -> Reference.t list option
(** Every exception declaration, resolved. *)

val resolved_values : t -> Reference.t list option
(** Every value definition (top-level let binding), resolved. *)

val resolved_signatures : t -> Value_sig.t list option
(** Value-signature declarations in an interface source, resolved. *)

(** {3 Parsetree-level — for syntactic rules}

    These walk the source as written, before resolution. Use them for rules
    whose intent is "did the user type X.y here?" (style / convention rules). *)

val iter_applications : t -> (Call.t -> unit) -> unit
(** [iter_applications t f] applies [f] to every [Pexp_apply] site whose callee
    is a path identifier. *)

val outline_identifiers : t -> Reference.t list
(** Value identifier use-sites from the typedtree outline, or from the parsetree
    outline when typedtree is unavailable. *)

val outline_patterns : t -> Reference.t list
(** Value-binding pattern names from the typedtree outline, or from the
    parsetree outline when typedtree is unavailable. *)

val outline_variants : t -> Reference.t list
(** Variant constructor declarations and use-sites from the typedtree outline,
    or from the parsetree outline when typedtree is unavailable. *)

val outline_variant_definitions : t -> Reference.t list
(** Variant constructor declarations only, from the typedtree outline, or from
    the parsetree outline when typedtree is unavailable. *)

val outline_modules : t -> Reference.t list
(** Module declarations and references from the typedtree outline, or from the
    parsetree outline when typedtree is unavailable. *)

val outline_module_definitions : t -> Reference.t list
(** Module declarations only, from the typedtree outline, or from the parsetree
    outline when typedtree is unavailable. *)

val outline_types : t -> Reference.t list
(** Type declarations from the typedtree outline, or from the parsetree outline
    when typedtree is unavailable. *)

val outline_type_definitions : t -> Reference.t list
(** Type declarations only, from the typedtree outline, or from the parsetree
    outline when typedtree is unavailable. *)

val outline_exceptions : t -> Reference.t list
(** Exception declarations from the typedtree outline, or from the parsetree
    outline when typedtree is unavailable. *)

val outline_values : t -> Reference.t list
(** Value definitions from the typedtree outline, or from the parsetree outline
    when typedtree is unavailable. *)

(** {2 Legacy accessors — to be removed once all rules migrate} *)

val parsetree : t -> Parsetree.structure option
(** [parsetree t] is the compiler-libs parsetree of the file, when available. *)

val signature : t -> Parsetree.signature option
(** [signature t] is the interface parsetree of the file when a fresh typedtree
    made it available. *)

val typedtree : t -> Merlin.typedtree option
(** [typedtree t] is the typedtree for the file, when a fresh [.cmt] made it
    available. *)

val functions : t -> (string * Ast.expr) list
(** [functions t] is the file's top-level functions, derived from the shared
    parsetree. *)

val ast : t -> Ast.t
(** [ast t] is the control-flow AST, derived from the shared parsetree. *)

val outline : t -> Outline.t
(** [outline t] is the underlying Merlin outline; prefer {!items}. *)

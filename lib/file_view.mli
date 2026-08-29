(** Unified per-file view for rules.

    File_view has two tiers, and which one a rule reads decides what it needs on
    disk.

    The parsetree tier is the source: {!items} and the doc comments hanging off
    them come from a parse of the file, so a rule reading nothing else answers
    for a file no build has ever touched.

    The typedtree tier is the artefact. The engine supplies a lazy
    [.cmt]/[.cmti] load, and everything derived from it is memoized from that
    typedtree. Where no fresh typedtree is available, its accessors return
    [None] or an empty collection -- {!typed_items} included -- so the
    corresponding rule run is skipped for that file rather than falling back to
    names the compiler never resolved. *)

exception Analysis_error of string
(** Raised by the lazy accessors when the underlying source cannot be read (file
    I/O failure, Merlin error, ...). *)

type t

val pp : t Fmt.t
(** [pp] prints a {!t} as its filename — enough to identify the view in debug
    output. *)

val v :
  filename:string ->
  content:string Lazy.t ->
  typedtree:(unit -> ((Merlin.typedtree * Merlin.docs) option, string) result) ->
  unit ->
  t
(** [v ~filename ~content ~typedtree ()] builds a fresh view over [filename].
    The [typedtree] thunk is called on first access and never twice; [content]
    is forced only if something asks for a declaration or a doc comment, both of
    which are read from a parse of the source rather than from the typedtree. *)

val filename : t -> string
(** [filename t] is the source file this view describes. *)

val docs_recorded : t -> bool
(** [docs_recorded t] is [true] iff the typedtree carries the source's doc
    comments. It does not when the tree was typechecked from source rather than
    read from an artefact: merlin's lexer does not emit doc comments, so every
    declaration looks undocumented. A rule that reads a doc comment must skip
    the file when this is [false] rather than report on what it cannot see. *)

val is_resolved : t -> bool
(** [is_resolved t] is [true] iff a typedtree is available for the file, whether
    it was read from an artefact or typechecked from the source in place of one
    that was missing or stale. Rules use this if they want to know whether the
    typedtree-backed accessors below will run or be skipped for this file. A
    rule that argues from what the tree does {e not} hold wants
    {!from_artefact}. *)

val from_artefact : t -> bool
(** [from_artefact t] is [true] iff the typedtree came from a [.cmt] or [.cmti]
    the compiler wrote for this exact source, and [false] when merlint
    typechecked the source itself because no artefact described it. Both are a
    typedtree to read and only one is evidence of absence: a typecheck recovers
    from what it cannot resolve, so a reference whose module has no [.cmi] in
    the build directory is simply not in the tree it produces. A rule that reads
    that absence as the source not making the reference reports on the state of
    a build directory, which is not what its finding says and not the same from
    one run to the next. *)

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
  (** [pp] prints a {!t} via {!to_string}. *)
end

(** {2 Types — structured shape queries on declared types} *)
module Type_view : sig
  type t

  val arrow : t -> (Ocaml_parsing.Asttypes.arg_label * t * t) option
  (** [arrow t] returns the top-level arrow shape, if any. *)

  val is_function : t -> bool
  (** [is_function t] is [true] when [t] is an arrow type. *)

  val is_variable : t -> bool
  (** [is_variable t] is [true] for unresolved/inferred type variables. *)

  val tuple : t -> t list option
  (** [tuple t] returns tuple fields when [t] is a tuple type. *)

  val constr : t -> (Name.t * t list) option
  (** [constr t] returns the resolved constructor path and arguments when [t] is
      a named type constructor. *)

  val constrs : t -> Name.t list
  (** [constrs t] returns every named type constructor reachable from [t],
      including nested type arguments. *)

  val is_constr : t -> path:string list -> bool
  (** [is_constr t ~path] checks whether [t] is exactly constructor [path]. *)

  val is_unit : t -> bool
  (** [is_unit t] checks whether [t] is [unit]. *)

  val is_bool : t -> bool
  (** [is_bool t] checks whether [t] is [bool]. *)

  val is_string : t -> bool
  (** [is_string t] checks whether [t] is [string]. *)

  val is_list : t -> elem:(t -> bool) -> bool
  (** [is_list t ~elem] checks whether [t] is a list whose element type matches
      [elem]. *)

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

(** {2 Items — declarations, from the source or from the artefact} *)
module Doc : sig
  type t

  val text : t -> string
  (** [text d] is the trimmed documentation payload. *)

  val loc : t -> Merlin.Location.t
  (** [loc d] is the source location of the documentation comment. *)
end

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
    | Extension
    | Field
    | Method
    | Instance_variable

  type t

  val name : t -> string
  (** [name i] is the unqualified name of the declared item. *)

  val kind : t -> kind
  (** [kind i] is the syntactic kind of the declaration. *)

  val equal_kind : kind -> kind -> bool
  (** [equal_kind a b] is [true] when [a] and [b] are the same kind. *)

  val loc : t -> Merlin.Location.t
  (** [loc i] is the source location of the declaration. *)

  val deprecated : t -> bool
  (** [deprecated i] is [true] when the declaration carries a [[@deprecated]]
      attribute. *)

  val doc : t -> Doc.t option
  (** [doc i] is the documentation comment attached to [i], when present. Both
      preceding and following OCaml doc comments are represented here by the
      compiler. *)

  val derives : t -> string -> bool
  (** [derives i name] is [true] when [i] carries [[@@deriving name]]. *)

  val children : t -> t list
  (** [children i] is the list of nested items declared inside [i] (members of a
      module, fields of a record, ...). *)

  val type_sig : t -> Type_view.t option
  (** [type_sig i] is the type the compiler gave [i]. Only an item from
      {!typed_items} has one: an implementation writes no type for most of its
      bindings, and what it does write is in {!arg_labels}. *)

  val arg_labels : t -> Ocaml_parsing.Asttypes.arg_label list
  (** [arg_labels i] is the labels of the arguments [i]'s type takes, outermost
      first, and [[]] when it takes none -- so a value that is not a function
      has none. Written arrows are syntactic, so this answers on both tiers. *)

  val is_mutable_field : t -> bool
  (** [is_mutable_field i] is [true] when [i] is a record field declared
      [mutable]. *)
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
  (** [type_path v] is the outermost type-constructor path of the declared type,
      when the type is a [Ttyp_constr] / [Ptyp_constr]; [None] for arrows,
      tuples, variables, etc. *)
end

(** {2 Function-application sites — typedtree walk} *)
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

(** {2 Message matches — [match] over the protocol message type}

    A {!Message_match.t} records a [match] whose scrutinee is the protocol
    message type and whose wildcard arm silently accepts an unexpected message
    (the nqsb-tls "Messy State of the Union" shape). E951 flags these. *)
module Message_match : sig
  type t

  val type_path : t -> Name.t
  (** [type_path m] is the message type's constructor path. *)

  val loc : t -> Merlin.Location.t
  (** [loc m] is the source location of the whole [match] expression. *)
end

(** {2 Top-level accessors} *)

val items : t -> Item.t list
(** [items t] is the file's top-level declarations, from a parse of the source.
    Available for any file that can be read. *)

val all_items : t -> Item.t list
(** [all_items t] is {!items} together with everything nested inside them. *)

val value_items : t -> Item.t list
(** [value_items t] is the value declarations among {!all_items}. *)

val typed_items : t -> Item.t list
(** [typed_items t] is the file's top-level declarations as the compiler typed
    them, so {!Item.type_sig} answers on each. Empty when no fresh typedtree is
    available, which is how a rule that needs a type skips a file rather than
    reporting on one it could not type. *)

val typed_all_items : t -> Item.t list
(** [typed_all_items t] is {!typed_items} together with everything nested inside
    them. *)

(** {3 Resolved typedtree accessors}

    These return fully-qualified, resolution-correct names. A rule that matches
    by path uses these; if it gets [None], it should skip the file rather than
    fall back to unresolved names. *)

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

val referenced_module_names : t -> string list
(** Capitalized module path components seen in the shared typedtree reference
    outline. *)

val iter_applications : t -> (Call.t -> unit) -> unit
(** [iter_applications t f] applies [f] to every [Pexp_apply] site whose callee
    is a path identifier. *)

val iter_asserts : t -> (Merlin.Location.t -> unit) -> unit
(** [iter_asserts t f] applies [f] to the location of every [assert _]
    expression. *)

val iter_message_matches : t -> (Message_match.t -> unit) -> unit
(** [iter_message_matches t f] applies [f] to every [match] over the protocol
    message type that has a wildcard arm whose body silently accepts an
    unexpected message (returns a normal value rather than an [Error]). *)

val calls_path : t -> string list -> bool
(** [calls_path t path] is [true] when [t] contains a call to resolved [path].
*)

val references_path : t -> string list -> bool
(** [references_path t path] is [true] when [t] contains a value reference to
    resolved [path]. *)

val references_suffix : t -> string list -> bool
(** [references_suffix t suffix] is [true] when [t] contains a value reference
    whose resolved path ends in [suffix]. *)

val outline_identifiers : t -> Reference.t list
(** Value identifier use-sites from the typedtree outline. *)

val outline_patterns : t -> Reference.t list
(** Value-binding pattern names from the typedtree outline. *)

val outline_variants : t -> Reference.t list
(** Variant constructor declarations and use-sites from the typedtree outline.
*)

val outline_variant_definitions : t -> Reference.t list
(** Variant constructor declarations only, from the typedtree outline. *)

val outline_modules : t -> Reference.t list
(** Module declarations and references from the typedtree outline. *)

val outline_module_definitions : t -> Reference.t list
(** Module declarations only, from the typedtree outline. *)

val outline_types : t -> Reference.t list
(** Type declarations from the typedtree outline. *)

val outline_type_definitions : t -> Reference.t list
(** Type declarations only, from the typedtree outline. *)

val outline_exceptions : t -> Reference.t list
(** Exception declarations from the typedtree outline. *)

val outline_values : t -> Reference.t list
(** Value definitions from the typedtree outline. *)

val typedtree : t -> Merlin.typedtree option
(** [typedtree t] is the typedtree for the file, when a fresh [.cmt] made it
    available. *)

val values : t -> Function_metrics.value list
(** [values t] is the file's top-level value bindings with typedtree-derived
    control-flow metrics. *)

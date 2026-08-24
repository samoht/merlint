(** Classify a cross-module type as abstract or transparent by reading its
    declaring module's [.cmti] interface, so polymorphic comparison can be
    flagged only on types whose representation is hidden. *)

type t =
  | Abstract  (** declared [type t] with no public manifest *)
  | Transparent of Ocaml_typing.Types.type_expr list
      (** a variant, record, or manifest alias - including a private one, whose
          representation is still readable - carrying the member types to
          compare in turn (an alias's target, a record's fields, a variant's
          arguments) so a transparent type that contains an abstract one is
          still rejected *)
  | Unknown  (** the declaring interface or the type could not be resolved *)

val pp : t Fmt.t
(** [pp] prints the classification name (for debugging). *)

type locals
(** The modules and module types one compilation unit defines itself. A module
    bound in a source file is not a compilation unit and has no interface on
    disk - a functor applied there writes no artefact at all - so a type it
    names ([Streams.key] for a local [Map.Make (Counted)]) resolves only from
    the module type the typechecker recorded for the binding. *)

val locals :
  [ `Interface of Ocaml_typing.Typedtree.signature
  | `Implementation of Ocaml_typing.Typedtree.structure ]
  option ->
  locals
(** [locals tree] reads the top-level module and module-type bindings of
    [tree]'s compilation unit, empty for [None]. A nested module needs no entry
    of its own: it is reached by navigating the enclosing binding's module type.
*)

val names_local : locals option -> string -> bool
(** [names_local locals path] is [true] when [path]'s head is one of the modules
    [locals] records, so {!classify} will read [path] out of that binding. A
    caller uses it to decide whether a resolved type's members are written in
    this unit's scope (they are, when it holds) or in the scope of the interface
    they were read from (when it does not). *)

val mangle_lib : string -> string
(** [mangle_lib m] maps the first component of a type path to its library's
    compilation-unit prefix: it lowercases an ordinary module ([X509] ->
    ["x509"]), keeps a compiler-mangled suffix ([Eio__File] -> ["eio__File"]),
    and strips a trailing namespace marker ([Eio__] -> ["eio"]). *)

val collapse_underscores : string -> string
(** [collapse_underscores s] folds any run of three or more underscores back to
    two, since a compilation-unit name never has three in a row (joining a
    ["Eio__"] wrapper with a submodule yields ["eio____File"] -> ["eio__File"]).
*)

val library_of : ?enclosing:string -> string -> string
(** [library_of ?enclosing path] names the library [path]'s head belongs to, so
    a type's members - themselves short sibling references - resolve against it.
    A wrapped sub-unit head names its library before the ["__"]
    (["Cascade__Css.t"] -> ["cascade"]); a bare head is a short sibling alias
    when [enclosing] is set (taking that library) or a library of its own
    otherwise (["Re.t"] -> ["re"]). *)

val classify :
  root:string -> ?locals:locals -> ?lib:string -> path:string -> unit -> t
(** [classify ~root ~path ()] resolves the fully qualified type [path] (e.g.
    ["X509.Key_type.t"]) against the project's built interfaces under [root],
    memoised. Follows module aliases, reads a type re-exported via
    [include module type of], and reads a [.cmt] implementation for modules that
    ship no [.mli]. [?lib] resolves a short sibling reference that does not
    resolve on its own (a wrapped library records cross-unit aliases by their
    short name) by retrying it as a sub-unit of library [lib]. [?locals]
    resolves a path headed by one of the citing unit's own modules from the
    module type the typechecker recorded for that binding, since no interface
    for it exists on disk; such a path is memoised per unit rather than per
    project. Reads cmt files purely; never touches [Env] / [Load_path]. *)

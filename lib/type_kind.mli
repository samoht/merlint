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

val classify : root:string -> ?lib:string -> path:string -> unit -> t
(** [classify ~root ~path ()] resolves the fully qualified type [path] (e.g.
    ["X509.Key_type.t"]) against the project's built interfaces under [root],
    memoised. Follows module aliases, reads a type re-exported via
    [include module type of], and reads a [.cmt] implementation for modules that
    ship no [.mli]. [?lib] resolves a short sibling reference that does not
    resolve on its own (a wrapped library records cross-unit aliases by their
    short name) by retrying it as a sub-unit of library [lib]. Reads cmt files
    purely; never touches [Env] / [Load_path]. *)

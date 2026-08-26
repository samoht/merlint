(** The declarations of one source file, from its parse.

    What a file declares -- the name, the kind, the span, the attributes written
    on it, and the nesting of members inside a module, constructors inside a
    type, fields inside a record -- is what the source says, so a parse answers
    it. Reading the outline here rather than off a typedtree is what lets a rule
    that needs nothing else run against a file no build has ever touched.

    A declared type is syntactic too, but only where one is written: an
    interface writes every value's type, an implementation infers most. So
    {!field-arg_labels} carries what an arrow written in the source says and
    nothing more; the inferred type of a binding is in the typedtree alone. *)

(** The syntactic kind of a declaration. *)
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

val equal_kind : kind -> kind -> bool
(** [equal_kind a b] is [true] when [a] and [b] name the same syntactic kind. *)

type item = {
  name : string;  (** The unqualified name of the declaration. *)
  kind : kind;  (** The syntactic kind of the declaration. *)
  loc : Ocaml_parsing.Location.t;
      (** The declaration's own span. The doc comment written on it is keyed by
          this span, and both come from the same parse. *)
  deprecated : bool;  (** [true] when it carries a [[@deprecated]] attribute. *)
  deriving : string list;  (** The names listed in its [[@@deriving ...]]. *)
  arg_labels : Ocaml_parsing.Asttypes.arg_label list;
      (** The argument labels of the type written on the declaration, outermost
          first, and [[]] when none is written or the type is not an arrow. *)
  mutable_field : bool;  (** [true] for a record field declared [mutable]. *)
  children : item list;
      (** The declarations nested inside this one: the members of a module, the
          constructors of a variant, the fields of a record. *)
}
(** The type for one declaration. *)

val v : Ast.t -> item list
(** [v ast] is the top-level declarations of [ast], in source order. *)

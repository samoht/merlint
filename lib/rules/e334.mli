(** E334: Redundant Variant/Field Prefixes

    This rule detects variant types and records whose every case shares a common
    leading word (e.g. [Foo_bar | Foo_baz] or [{ foo_bar; foo_baz }]). The
    shared prefix duplicates the type name and can be dropped, relying on
    OCaml's type-directed disambiguation at call sites. *)

val rule : Rule.t
(** [rule] is the E334 rule definition. *)

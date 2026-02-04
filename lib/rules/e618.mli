(** E618: Avoid X__Y Module Access - Use X.Y Instead

    This rule detects usage of double underscore module access patterns like
    Module__Submodule and suggests using dot notation Module.Submodule instead.
    Double underscore notation is internal to the OCaml module system and should
    not be used in application code. *)

val rule : Rule.t
(** The E618 rule definition *)

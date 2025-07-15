(** E100: No Obj.magic

    This rule detects usage of Obj.magic, which bypasses OCaml's type system and
    can lead to runtime crashes. *)

val check : Typedtree.t -> Issue.t list
(** [check typedtree] analyzes the typedtree to find usage of Obj.magic. Returns
    a list of issues for each usage found. *)

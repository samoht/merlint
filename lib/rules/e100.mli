(** E100: No Obj.magic

    This rule detects usage of Obj.magic, which bypasses OCaml's type system and
    can lead to runtime crashes. *)

val check : Context.file -> Issue.t list
(** [check AST] analyzes the AST to find usage of Obj.magic. Returns a list of
    issues for each usage found. *)

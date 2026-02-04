(** E100: No Obj.magic

    This rule detects usage of Obj.magic, which bypasses OCaml's type system and
    can lead to runtime crashes. *)

val rule : Rule.t
(** The E100 rule definition *)

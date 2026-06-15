(** E101: No Marshal usage

    This rule detects any reference into the [Stdlib.Marshal] module and the
    [output_value] / [input_value] channel functions. All perform untyped
    (de)serialization: the bytes carry no type, so a value can be read back at
    any type, forging values of even abstract types. *)

val rule : Rule.t
(** [rule] is the E101 rule definition. *)

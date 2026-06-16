(** Fixture: a variant [t] surfaced through the [_intf] trick, to check that
    [Type_kind] reads it as transparent. *)

include module type of Colour_intf

val to_string : t -> string
(** [to_string c] renders [c] as a string. *)

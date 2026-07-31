(** A type documented before its declaration, with one documented case. *)

(** The type for a parameter type, which says how to read a raw value. *)
type parameter_type =
  | Integer_parameter_type of { size_in_bits : int }
  | String_parameter_type of { name : string }
  | Aggregate_parameter_type of { members : string list }
      (** A group of other types under one name. Its members are addressed by
          path. *)

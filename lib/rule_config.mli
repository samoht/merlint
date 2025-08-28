(** Rule exclusion management with file pattern matching. *)

type rule_pattern = {
  pattern : string;
      (** File glob pattern like "lib/prose*" or "**/*_test.ml" *)
  rules : string list;
      (** List of rule codes to exclude like ["E330"; "E410"] *)
}
(** [rule_pattern] represents a file pattern and the rules to exclude for
    matching files. *)

type t
(** [t] represents a collection of exclusion rules. *)

val empty : t
(** [empty] is an empty exclusion configuration. *)

val add : rule_pattern -> t -> t
(** [add pattern exclusions] adds a new exclusion pattern to the configuration.
*)

val should_exclude : t -> rule:string -> file:string -> bool
(** [should_exclude exclusions ~rule ~file] returns true if the rule should be
    excluded for the given file path. *)

val parse_exclusion_line : string -> rule_pattern option
(** [parse_exclusion_line line] parses a configuration line like "lib/prose*.ml
    = E330,E410" into a rule_pattern. *)

val pp : t Fmt.t
(** [pp] is a pretty-printer for exclusions. *)

val equal : t -> t -> bool
(** [equal a b] returns true if [a] and [b] contain the same exclusions. *)

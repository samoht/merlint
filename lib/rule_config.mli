(** Rule exclusion management with file pattern matching. *)

type rule_pattern = {
  pattern : string;
      (** File glob pattern like "lib/prose*" or "**/*_test.ml" *)
  rules : string list;
      (** List of rule codes to exclude like ["E330"; "E410"] *)
  config_dir : string;
      (** Directory of the [merlint.toml] that declared the pattern. Patterns
          are matched relative to this directory as well as against the raw
          analyzed file path. *)
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

val merge : t -> t -> t
(** [merge a b] combines two exclusion configurations. *)

val should_exclude : t -> rule:string -> file:string -> bool
(** [should_exclude exclusions ~rule ~file] returns true if the rule should be
    excluded for the given file path. *)

val is_wildcard_excluded : t -> file:string -> bool
(** [is_wildcard_excluded exclusions ~file] is [true] when [file] is matched by
    a rule whose exclude list is the catch-all [["*"]] -- the vendored-tree
    pattern ([files = "vendor/**/*.ml" exclude = ["*"]]). Such a rule means "do
    not lint these files at all", so their skips are not suppressed findings and
    are kept out of the suppression statistics. *)

val matches_pattern : string -> string -> bool
(** [matches_pattern pattern file] is [true] when [file] matches the glob
    [pattern]. [*] matches within a path segment, [**] across segments. *)

val pp : t Fmt.t
(** [pp] is a pretty-printer for exclusions. *)

val equal : t -> t -> bool
(** [equal a b] returns true if [a] and [b] contain the same exclusions. *)

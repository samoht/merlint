(** Centralized configuration for all merlint rules. *)

type t = {
  (* Complexity rules *)
  max_complexity : int;
  max_function_length : int;
  max_nesting : int;
  exempt_data_definitions : bool; (* Don't check length for pure data *)
  (* Naming rules *)
  max_underscores_in_name : int;
  min_name_length_underscore : int;
  allowed_words : string list;
      (** Words treated as atomic by naming rules (e.g. EdDSA, ECDSA). Parsed
          from [allowed_words] or [acronyms] in [merlint.toml]. *)
  topics : string list;
      (** Canonical opam tag vocabulary. Parsed from [topics] in [merlint.toml].
          When non-empty, E915 rejects any opam tag not in this list (plus the
          [org:*] namespace prefix which is always allowed). *)
  allowed_states : string list;
      (** State-machine module basenames for a protocol package whose machines
          do not use the default role vocabulary, parsed from [allowed_states]
          in [merlint.toml]. When set, this list {e replaces} the default
          vocabulary for the protocol rules (E946-E949): the package's state
          machines are exactly these modules, and [State] and the role names are
          no longer recognised. A package with several deliberate machines (e.g.
          a CFDP Class-1/Class-2 sender and receiver) splits them into one
          module per machine and declares those module names here. *)
  allowed_names : string list;
      (** Value names a package documents as exempt from the naming rules that
          would otherwise flag them, parsed from [allowed-names] in
          [merlint.toml]. Currently consulted by E955 (the ban on the ['] verb
          suffix): a name listed here keeps its ['] (e.g. a format-native
          keyword escape like ["object'"], or a ["pp"]/["pp'"]
          configuration-variant pair) without being rejected. *)
  disallowed_modules : string list;
      (** Module paths whose use is banned in matching files, parsed from
          [disallowed_modules] in [merlint.toml] (e.g.
          [["Stdlib.Printf"; "Stdlib.Format"; "Fmt"]]). E221 flags any reference
          whose resolved path is, or sits under, one of these. Empty by default,
          so the rule is silent until a project opts in -- typically via a
          [merlint.toml] in the subtree it should cover (a [js_of_ocaml]
          directory that must not pull in [Printf]/[Format]/[Fmt]). *)
  disallowed_libraries : string list;
      (** Library / opam-package names banned from a package's dependencies,
          parsed from [disallowed_libraries] in [merlint.toml] (e.g. [["fmt"]]).
          E942 flags any package that links one of these via [(libraries ...)]
          or declares it in [depends:]. Empty by default. *)
  (* Style rules *)
  allow_obj_magic : bool;
  allow_str_module : bool;
  allow_catch_all_exceptions : bool;
  (* Format rules *)
  require_ocamlformat_file : bool;
  require_mli_files : bool;
  (* Rule exclusions *)
  exclusions : Rule_config.t;
}

val default : t
(** [default] configuration with recommended settings. *)

val allows : t -> bare:string -> qualified:string -> bool
(** [allows t ~bare ~qualified] is whether {!allowed_words} exempts a name,
    matching either its bare form ([create]) or its module-qualified form
    ([Container.create]). A qualified entry exempts only that one binding. *)

val equal : t -> t -> bool
(** [equal a b] returns true if [a] and [b] are equal. *)

val compare : t -> t -> int
(** [compare a b] returns a comparison result between [a] and [b]. *)

val pp : t Fmt.t
(** [pp] is a pretty-printer for the configuration. *)

(** Configuration file loading. *)

val file : string -> string option
(** [file path] finds the outermost merlint.toml config file from the given
    path. *)

val load : string -> t
(** [load path] loads and merges all merlint.toml config files from [path] up to
    the workspace root. Settings from closer files override outer ones; rule
    exclusions accumulate. *)

val for_file : string -> t
(** [for_file file] returns the config that applies to [file], merging
    merlint.toml files from [file]'s directory up to the workspace root.
    Settings from closer files override outer ones; rule exclusions accumulate.
*)

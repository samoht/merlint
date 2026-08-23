(** Centralized configuration for all merlint rules *)

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
  topics : string list;
  allowed_states : string list;
  (* Protocol state-machine module basenames declared by a package whose state
     machines do not use the default role vocabulary (E946-E949). *)
  allowed_names : string list;
  (* Value names a package documents as exempt from the naming rules that would
     otherwise flag them (e.g. E955's ban on the ' suffix). *)
  disallowed_modules : string list;
  (* Module paths banned from use in matching files (E221). *)
  disallowed_libraries : string list;
  (* Library / opam-package names banned from a package's deps (E942). *)
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

let default =
  {
    (* Complexity defaults *)
    max_complexity = 10;
    max_function_length = 50;
    max_nesting = 4;
    exempt_data_definitions = true;
    (* Naming defaults *)
    max_underscores_in_name = 4;
    min_name_length_underscore = 5;
    allowed_words = [];
    topics = [];
    allowed_states = [];
    allowed_names = [];
    disallowed_modules = [];
    disallowed_libraries = [];
    (* Style defaults - all issues enabled *)
    allow_obj_magic = false;
    allow_str_module = false;
    allow_catch_all_exceptions = false;
    (* Format defaults *)
    require_ocamlformat_file = true;
    require_mli_files = true;
    (* Rule exclusions *)
    exclusions = Rule_config.empty;
  }

let allows t ~bare ~qualified =
  List.mem bare t.allowed_words || List.mem qualified t.allowed_words

let file path =
  match Project.config_files path with [] -> None | first :: _ -> Some first

(** Parse boolean value *)
let parse_bool value =
  match String.lowercase_ascii value with
  | "true" | "yes" | "1" -> true
  | "false" | "no" | "0" -> false
  | _ -> Fmt.failwith "Invalid boolean value: %s" value

(** Parse integer value *)
let parse_int value =
  try int_of_string value
  with Failure _ -> Fmt.failwith "Invalid integer value: %s" value

(** Normalize config key from kebab-case to snake_case *)
let normalize_key key = String.map (function '-' -> '_' | c -> c) key

(* Every key a [merlint.toml] may set, normalized. Only used to suggest the key
   a rejected one is a near miss of; [apply_config] below is what decides
   whether a key is known. *)
let known_keys =
  [
    "max_complexity";
    "max_function_length";
    "max_nesting";
    "exempt_data_definitions";
    "max_underscores_in_name";
    "min_name_length_underscore";
    "allowed_words";
    "acronyms";
    "topics";
    "allowed_states";
    "allowed_names";
    "disallowed_modules";
    "disallowed_libraries";
    "allow_obj_magic";
    "allow_str_module";
    "allow_catch_all_exceptions";
    "require_ocamlformat_file";
    "require_mli_files";
    "workspace";
  ]

(* Levenshtein distance between [a] and [b], over two rolling rows. *)
let distance a b =
  let la = String.length a and lb = String.length b in
  let prev = Array.init (lb + 1) Fun.id and curr = Array.make (lb + 1) 0 in
  for i = 1 to la do
    curr.(0) <- i;
    for j = 1 to lb do
      let subst = prev.(j - 1) + if a.[i - 1] = b.[j - 1] then 0 else 1 in
      curr.(j) <- min (min (curr.(j - 1) + 1) (prev.(j) + 1)) subst
    done;
    Array.blit curr 0 prev 0 (lb + 1)
  done;
  prev.(lb)

(* The known key [normalized] is closest to, when close enough that a typo is
   the likely explanation. Rendered with the separator the author used, so the
   suggestion can be pasted straight back into the file. *)
let nearest_key ~raw normalized =
  let render key =
    if String.contains raw '-' then
      String.map (function '_' -> '-' | c -> c) key
    else key
  in
  let near =
    List.filter_map
      (fun known ->
        let d = distance normalized known in
        if d <= 2 then Some (d, render known) else None)
      known_keys
  in
  match List.stable_sort (fun (a, _) (b, _) -> Int.compare a b) near with
  | [] -> None
  | (_, closest) :: _ -> Some closest

(* A key merlint has no case for is a typo, a key that was renamed, or one from
   a merlint that never existed. Reading past it leaves the file looking like
   configuration that is in force when none of it is: a misspelt
   [disallowed-modules] leaves E221's ban list empty and the rule the author
   configured never runs. Refuse, and name the key merlint knows that it is
   closest to. *)
let err_unknown_key ~file ~raw normalized =
  match nearest_key ~raw normalized with
  | Some closest ->
      Fmt.failwith "merlint config: %s: unknown key %S -- did you mean %S?" file
        raw closest
  | None ->
      Fmt.failwith
        "merlint config: %s: unknown key %S. Run `merlint help config` for the \
         keys merlint accepts."
        file raw

(** Parse comma or space separated list, optionally wrapped in [...] *)
let parse_list value =
  let stripped =
    let v = String.trim value in
    if String.length v >= 2 && v.[0] = '[' && v.[String.length v - 1] = ']' then
      String.sub v 1 (String.length v - 2)
    else v
  in
  String.split_on_char ',' stripped
  |> List.concat_map (fun s -> String.split_on_char ' ' (String.trim s))
  |> List.filter (fun s -> s <> "")

(** Apply a configuration key-value pair to the config *)
let apply_config ~file config key value : t =
  match normalize_key key with
  (* Complexity rules *)
  | "max_complexity" -> { config with max_complexity = parse_int value }
  | "max_function_length" ->
      { config with max_function_length = parse_int value }
  | "max_nesting" -> { config with max_nesting = parse_int value }
  | "exempt_data_definitions" ->
      { config with exempt_data_definitions = parse_bool value }
  (* Naming rules *)
  | "max_underscores_in_name" ->
      { config with max_underscores_in_name = parse_int value }
  | "min_name_length_underscore" ->
      { config with min_name_length_underscore = parse_int value }
  | "allowed_words" | "acronyms" ->
      (* Accumulate across nested configs: a closer merlint.toml extends the
         outer allowlist rather than replacing it. *)
      { config with allowed_words = config.allowed_words @ parse_list value }
  | "topics" -> { config with topics = parse_list value }
  | "allowed_states" ->
      (* Accumulate across nested configs, like [allowed_words]. *)
      { config with allowed_states = config.allowed_states @ parse_list value }
  | "allowed_names" ->
      (* The config-file key is [allowed-names]; [normalize_key] maps the dash
         to an underscore before this match. Accumulate like [allowed_words]. *)
      { config with allowed_names = config.allowed_names @ parse_list value }
  | "disallowed_modules" ->
      (* Accumulate so a closer merlint.toml extends the ban list rather than
         replacing it. *)
      {
        config with
        disallowed_modules = config.disallowed_modules @ parse_list value;
      }
  | "disallowed_libraries" ->
      {
        config with
        disallowed_libraries = config.disallowed_libraries @ parse_list value;
      }
  (* Style rules *)
  | "allow_obj_magic" -> { config with allow_obj_magic = parse_bool value }
  | "allow_str_module" -> { config with allow_str_module = parse_bool value }
  | "allow_catch_all_exceptions" ->
      { config with allow_catch_all_exceptions = parse_bool value }
  (* Format rules *)
  | "require_ocamlformat_file" ->
      { config with require_ocamlformat_file = parse_bool value }
  | "require_mli_files" -> { config with require_mli_files = parse_bool value }
  (* Read by {!Project}, which resolves the path against the file that declares
     it; nothing here consumes it. *)
  | "workspace" -> config
  | normalized -> err_unknown_key ~file ~raw:key normalized

let load path =
  let config_files = Project.config_files path in
  List.fold_left
    (fun acc file ->
      match Config_parser.parse_file file with
      | Some parsed ->
          let config =
            List.fold_left
              (fun c (key, value) -> apply_config ~file c key value)
              acc parsed.Config_parser.settings
          in
          {
            config with
            exclusions =
              Rule_config.merge config.exclusions
                parsed.Config_parser.exclusions;
          }
      | None -> acc)
    default config_files

let for_file file =
  let dir = if Sys.file_exists file then Filename.dirname file else file in
  load dir

(** Standard functions for type t *)
let equal a b =
  List.for_all Fun.id
    [
      a.max_complexity = b.max_complexity;
      a.max_function_length = b.max_function_length;
      a.max_nesting = b.max_nesting;
      a.exempt_data_definitions = b.exempt_data_definitions;
      a.max_underscores_in_name = b.max_underscores_in_name;
      a.min_name_length_underscore = b.min_name_length_underscore;
      a.allowed_words = b.allowed_words;
      a.topics = b.topics;
      a.allowed_states = b.allowed_states;
      a.allowed_names = b.allowed_names;
      a.disallowed_modules = b.disallowed_modules;
      a.disallowed_libraries = b.disallowed_libraries;
      a.allow_obj_magic = b.allow_obj_magic;
      a.allow_str_module = b.allow_str_module;
      a.allow_catch_all_exceptions = b.allow_catch_all_exceptions;
      a.require_ocamlformat_file = b.require_ocamlformat_file;
      a.require_mli_files = b.require_mli_files;
    ]

let compare = compare

let pp ppf t =
  Fmt.pf ppf
    "@[<v>{ max_complexity = %d; max_function_length = %d; max_nesting = %d; \
     exempt_data_definitions = %b; max_underscores_in_name = %d; \
     min_name_length_underscore = %d; topics = [%s]; disallowed_modules = \
     [%s]; disallowed_libraries = [%s]; allow_obj_magic = %b; allow_str_module \
     = %b; allow_catch_all_exceptions = %b; require_ocamlformat_file = %b; \
     require_mli_files = %b }@]"
    t.max_complexity t.max_function_length t.max_nesting
    t.exempt_data_definitions t.max_underscores_in_name
    t.min_name_length_underscore
    (String.concat "; " t.topics)
    (String.concat "; " t.disallowed_modules)
    (String.concat "; " t.disallowed_libraries)
    t.allow_obj_magic t.allow_str_module t.allow_catch_all_exceptions
    t.require_ocamlformat_file t.require_mli_files

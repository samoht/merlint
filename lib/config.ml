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
let apply_config config key value : t =
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
  (* Style rules *)
  | "allow_obj_magic" -> { config with allow_obj_magic = parse_bool value }
  | "allow_str_module" -> { config with allow_str_module = parse_bool value }
  | "allow_catch_all_exceptions" ->
      { config with allow_catch_all_exceptions = parse_bool value }
  (* Format rules *)
  | "require_ocamlformat_file" ->
      { config with require_ocamlformat_file = parse_bool value }
  | "require_mli_files" -> { config with require_mli_files = parse_bool value }
  | _ ->
      (* Unknown key - ignore for forward compatibility *)
      config

let load path =
  let config_files = Project.config_files path in
  List.fold_left
    (fun acc path ->
      match Config_parser.parse_file path with
      | Some parsed ->
          let config =
            List.fold_left
              (fun c (key, value) -> apply_config c key value)
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
     min_name_length_underscore = %d; topics = [%s]; allow_obj_magic = %b; \
     allow_str_module = %b; allow_catch_all_exceptions = %b; \
     require_ocamlformat_file = %b; require_mli_files = %b }@]"
    t.max_complexity t.max_function_length t.max_nesting
    t.exempt_data_definitions t.max_underscores_in_name
    t.min_name_length_underscore
    (String.concat "; " t.topics)
    t.allow_obj_magic t.allow_str_module t.allow_catch_all_exceptions
    t.require_ocamlformat_file t.require_mli_files

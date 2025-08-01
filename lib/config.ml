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
  (* Style rules *)
  allow_obj_magic : bool;
  allow_str_module : bool;
  allow_catch_all_exceptions : bool;
  (* Format rules *)
  require_ocamlformat_file : bool;
  require_mli_files : bool;
}

let default =
  {
    (* Complexity defaults *)
    max_complexity = 10;
    max_function_length = 50;
    max_nesting = 3;
    exempt_data_definitions = true;
    (* Naming defaults *)
    max_underscores_in_name = 3;
    min_name_length_underscore = 5;
    (* Style defaults - all issues enabled *)
    allow_obj_magic = false;
    allow_str_module = false;
    allow_catch_all_exceptions = false;
    (* Format defaults *)
    require_ocamlformat_file = true;
    require_mli_files = true;
  }

let filename = ".merlintrc"

let file path =
  let project_root =
    if Sys.is_directory path then path else Filename.dirname path
  in
  let config_path = Filename.concat project_root filename in
  if Sys.file_exists config_path then Some config_path else None

(** Parse a single configuration line *)
let parse_line line =
  let line = String.trim line in
  if String.length line = 0 || String.get line 0 = '#' then None
  else
    match String.split_on_char '=' line with
    | [ key; value ] ->
        let key = String.trim key in
        let value = String.trim value in
        Some (key, value)
    | _ -> None

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

(** Apply a configuration key-value pair to the config *)
let apply_config config key value : t =
  match key with
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
  try
    let ic = open_in path in
    let rec read_lines config =
      try
        let line = input_line ic in
        let config' =
          match parse_line line with
          | Some (key, value) -> (
              try apply_config config key value
              with Failure msg ->
                Fmt.epr "Warning: %s (line: %s)\n" msg line;
                config)
          | None -> config
        in
        read_lines config'
      with End_of_file ->
        close_in ic;
        config
    in
    read_lines default
  with
  | Sys_error _ -> default
  | exn ->
      Fmt.epr "Warning: Error loading config from %s: %s\n" path
        (Printexc.to_string exn);
      default

let load_from_path path =
  match file path with Some config_path -> load config_path | None -> default

(** Standard functions for type t *)
let equal a b =
  a.max_complexity = b.max_complexity
  && a.max_function_length = b.max_function_length
  && a.max_nesting = b.max_nesting
  && a.exempt_data_definitions = b.exempt_data_definitions
  && a.max_underscores_in_name = b.max_underscores_in_name
  && a.min_name_length_underscore = b.min_name_length_underscore
  && a.allow_obj_magic = b.allow_obj_magic
  && a.allow_str_module = b.allow_str_module
  && a.allow_catch_all_exceptions = b.allow_catch_all_exceptions
  && a.require_ocamlformat_file = b.require_ocamlformat_file
  && a.require_mli_files = b.require_mli_files

let compare = compare

let pp ppf t =
  Fmt.pf ppf
    "@[<v>{ max_complexity = %d; max_function_length = %d; max_nesting = %d; \
     exempt_data_definitions = %b; max_underscores_in_name = %d; \
     min_name_length_underscore = %d; allow_obj_magic = %b; allow_str_module = \
     %b; allow_catch_all_exceptions = %b; require_ocamlformat_file = %b; \
     require_mli_files = %b }@]"
    t.max_complexity t.max_function_length t.max_nesting
    t.exempt_data_definitions t.max_underscores_in_name
    t.min_name_length_underscore t.allow_obj_magic t.allow_str_module
    t.allow_catch_all_exceptions t.require_ocamlformat_file t.require_mli_files

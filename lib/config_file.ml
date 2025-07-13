(** Configuration file loading for merlint *)

let config_filename = ".merlintrc"

let rec find_config_file path =
  let current = if Sys.is_directory path then path else Filename.dirname path in
  let config_path = Filename.concat current config_filename in
  if Sys.file_exists config_path then Some config_path
  else
    let parent = Filename.dirname current in
    if parent = current then None (* reached root *)
    else find_config_file parent

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
let apply_config (config : Config.t) key value : Config.t =
  match key with
  (* Complexity rules *)
  | "max_complexity" -> { config with Config.max_complexity = parse_int value }
  | "max_function_length" ->
      { config with Config.max_function_length = parse_int value }
  | "max_nesting" -> { config with Config.max_nesting = parse_int value }
  | "exempt_data_definitions" ->
      { config with Config.exempt_data_definitions = parse_bool value }
  (* Naming rules *)
  | "max_underscores_in_name" ->
      { config with Config.max_underscores_in_name = parse_int value }
  | "min_name_length_underscore" ->
      { config with Config.min_name_length_underscore = parse_int value }
  (* Style rules *)
  | "allow_obj_magic" ->
      { config with Config.allow_obj_magic = parse_bool value }
  | "allow_str_module" ->
      { config with Config.allow_str_module = parse_bool value }
  | "allow_catch_all_exceptions" ->
      { config with Config.allow_catch_all_exceptions = parse_bool value }
  (* Format rules *)
  | "require_ocamlformat_file" ->
      { config with Config.require_ocamlformat_file = parse_bool value }
  | "require_mli_files" ->
      { config with Config.require_mli_files = parse_bool value }
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
    read_lines Config.default
  with
  | Sys_error _ -> Config.default
  | exn ->
      Fmt.epr "Warning: Error loading config from %s: %s\n" path
        (Printexc.to_string exn);
      Config.default

let load_from_path path =
  match find_config_file path with
  | Some config_path -> load config_path
  | None -> Config.default

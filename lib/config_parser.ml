(** Configuration file parser for [merlint.toml] (TOML 1.1).

    Parses with {!Toml.Value.codec} to a TOML AST and projects to
    {!parsed_config}: settings as a [(key, string)] list plus a list of
    file/exclude rule patterns. {!Config.apply_config} re-parses the string
    values through {!Config.parse_bool} / {!Config.parse_int} /
    {!Config.parse_list}. *)

type parsed_config = {
  settings : (string * string) list;
  exclusions : Rule_config.t;
}

let rec scalar_to_string : Toml.Value.t -> string = function
  | String (s, _) -> s
  | Int (i, _) -> Int64.to_string i
  | Float (f, _) -> string_of_float f
  | Bool (true, _) -> "true"
  | Bool (false, _) -> "false"
  | Datetime (s, _)
  | Datetime_local (s, _)
  | Date_local (s, _)
  | Time_local (s, _) ->
      s
  | Array (items, _) -> String.concat ", " (List.map scalar_to_string items)
  | Table _ -> Fmt.failwith "merlint config: unexpected nested table value"

(* Project a top-level (key, value) pair to either:
   - (key, string) settings entries, or
   - rule-pattern entries when the key is "rules" and the value is an array of
     tables. *)
let lookup_member name members =
  List.find_map (fun ((k, _), v) -> if k = name then Some v else None) members

let exclude_string_of_value = function
  | Toml.Value.String (s, _) -> s
  | _ -> Fmt.failwith "merlint config: rule.exclude entries must be strings"

let exclude_rules_of_member = function
  | Some (Toml.Value.Array (items, _)) -> List.map exclude_string_of_value items
  | Some _ -> Fmt.failwith "merlint config: rule.exclude must be a list"
  | None -> Fmt.failwith "merlint config: rule missing 'exclude'"

let files_string_of_member = function
  | Some (Toml.Value.String (s, _)) -> s
  | _ -> Fmt.failwith "merlint config: rule missing string 'files'"

let extract_pattern (entry : Toml.Value.t) =
  match entry with
  | Table (members, _) ->
      let files = files_string_of_member (lookup_member "files" members) in
      let rules = exclude_rules_of_member (lookup_member "exclude" members) in
      { Rule_config.pattern = files; rules }
  | _ -> Fmt.failwith "merlint config: rule entries must be tables"

let project_setting (key, (value : Toml.Value.t)) =
  match (key, value) with
  | "rules", Array (entries, _) -> `Rules (List.map extract_pattern entries)
  | _ -> `Setting (key, scalar_to_string value)

let parse content =
  let value =
    match Toml.of_string Toml.Value.codec content with
    | Ok v -> v
    | Error e -> Fmt.failwith "merlint config: %s" (Toml.Error.to_string e)
  in
  let members =
    match value with
    | Table (members, _) -> members
    | _ -> Fmt.failwith "merlint config: expected a TOML document (table)"
  in
  List.fold_left
    (fun acc ((key, _), v) ->
      match project_setting (key, v) with
      | `Setting (k, s) -> { acc with settings = (k, s) :: acc.settings }
      | `Rules patterns ->
          let exclusions =
            List.fold_left
              (fun excl p -> Rule_config.add p excl)
              acc.exclusions patterns
          in
          { acc with exclusions })
    { settings = []; exclusions = Rule_config.empty }
    members

let parse_file path =
  if Sys.file_exists path then
    let content = In_channel.with_open_text path In_channel.input_all in
    Some (parse content)
  else None

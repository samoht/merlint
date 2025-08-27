(** Configuration file parser for .merlint files with YAML-like syntax *)

type parsed_config = {
  settings : (string * string) list;
  exclusions : Exclusions.t;
}

type section = Rules | Exclusions | Settings

(** Determine section from header line *)
let parse_section_header line =
  let line = String.trim line in
  if line = "rules:" then Some Rules
  else if line = "exclusions:" then Some Exclusions
  else if line = "settings:" then Some Settings
  else None

(** Parse a settings line *)
let parse_setting line =
  match String.split_on_char ':' line with
  | [ key; value ] ->
      let key = String.trim key in
      let value = String.trim value in
      Some (key, value)
  | _ -> None

(** Parse an exclusion line in YAML format *)
let parse_exclusion_yaml line =
  (* Format: "  - pattern: lib/prose*.ml" or "    rules: [E330, E410]" *)
  let line = String.trim line in
  if String.starts_with ~prefix:"- pattern:" line then
    let pattern = String.sub line 10 (String.length line - 10) |> String.trim in
    Some (`Pattern pattern)
  else if String.starts_with ~prefix:"rules:" line then
    let rules_str = String.sub line 6 (String.length line - 6) |> String.trim in
    (* Remove brackets if present *)
    let rules_str =
      if
        String.starts_with ~prefix:"[" rules_str
        && String.ends_with ~suffix:"]" rules_str
      then String.sub rules_str 1 (String.length rules_str - 2)
      else rules_str
    in
    let rules =
      rules_str |> String.split_on_char ',' |> List.map String.trim
      |> List.filter (fun s -> String.length s > 0)
    in
    Some (`Rules rules)
  else None

(** Parse configuration content *)
let parse content =
  let lines = String.split_on_char '\n' content in
  let rec process_lines current_section current_pattern exclusions settings =
    function
    | [] ->
        let exclusions =
          match current_pattern with
          | Some (pattern, rules) when List.length rules > 0 ->
              Exclusions.add exclusions { pattern; rules }
          | _ -> exclusions
        in
        { settings; exclusions }
    | line :: rest -> (
        let trimmed = String.trim line in
        (* Skip empty lines and comments *)
        if String.length trimmed = 0 || String.get trimmed 0 = '#' then
          process_lines current_section current_pattern exclusions settings rest
        (* Check for section headers *)
          else
          match parse_section_header trimmed with
          | Some section ->
              let exclusions =
                match current_pattern with
                | Some (pattern, rules) when List.length rules > 0 ->
                    Exclusions.add exclusions { pattern; rules }
                | _ -> exclusions
              in
              process_lines section None exclusions settings rest
          | None -> (
              (* Process based on current section *)
              match current_section with
              | Settings ->
                  let new_settings =
                    match parse_setting trimmed with
                    | Some kv -> kv :: settings
                    | None -> settings
                  in
                  process_lines current_section current_pattern exclusions
                    new_settings rest
              | Exclusions -> (
                  match parse_exclusion_yaml trimmed with
                  | Some (`Pattern pattern) ->
                      (* Save previous exclusion if any *)
                      let exclusions =
                        match current_pattern with
                        | Some (prev_pattern, rules) when List.length rules > 0
                          ->
                            Exclusions.add exclusions
                              { pattern = prev_pattern; rules }
                        | _ -> exclusions
                      in
                      process_lines current_section
                        (Some (pattern, []))
                        exclusions settings rest
                  | Some (`Rules rules) ->
                      let current_pattern =
                        match current_pattern with
                        | Some (pattern, _) -> Some (pattern, rules)
                        | None -> None
                      in
                      process_lines current_section current_pattern exclusions
                        settings rest
                  | None ->
                      process_lines current_section current_pattern exclusions
                        settings rest)
              | Rules ->
                  (* Legacy format support or future rules configuration *)
                  process_lines current_section current_pattern exclusions
                    settings rest))
  in
  process_lines Settings None Exclusions.empty [] lines

let parse_file path =
  if Sys.file_exists path then
    let content = In_channel.with_open_text path In_channel.input_all in
    Some (parse content)
  else None

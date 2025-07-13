(* Test file for error pattern detection *)

(* Should trigger E340: inline error construction *)
let validate_user name age =
  if String.length name < 3 then
    Error (Fmt.str "Name too short: %s" name)
  else if age < 0 then
    Error (Fmt.str "Invalid age: %d" age)
  else if age > 150 then
    Error (Fmt.str "Age too high: %d" age)
  else
    Ok (name, age)

(* Should trigger E340: multiple error patterns *)
let process_file filename =
  match Sys.file_exists filename with
  | false -> Error (Fmt.str "File not found: %s" filename)
  | true ->
      let size = (Unix.stat filename).st_size in
      if size > 1_000_000 then
        Error (Fmt.str "File too large: %d bytes" size)
      else
        Ok filename

(* Good: using error helpers *)
let err_invalid_config msg = Error (Fmt.str "Invalid config: %s" msg)
let err_missing_field field = Error (Fmt.str "Missing field: %s" field)

let parse_config data =
  match data.version with
  | None -> err_missing_field "version"
  | Some v when v < 1 -> err_invalid_config "version too old"
  | Some _ -> Ok data
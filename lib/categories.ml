let filename = "categories.toml"

let is_section_header line =
  let len = String.length line in
  len >= 3 && line.[0] = '[' && line.[1] <> '[' && line.[len - 1] = ']'

let parse_header line =
  let len = String.length line in
  String.sub line 1 (len - 2) |> String.trim

let read_lines path =
  let ic = open_in path in
  let rec loop acc =
    match input_line ic with
    | line -> loop (line :: acc)
    | exception End_of_file ->
        close_in ic;
        List.rev acc
  in
  try loop []
  with exn ->
    close_in_noerr ic;
    raise exn

let load project_root =
  let path = Filename.concat project_root filename in
  try
    read_lines path |> List.map String.trim
    |> List.filter is_section_header
    |> List.map parse_header
  with Sys_error _ -> []

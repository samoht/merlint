(** E524: One Cmdliner subcommand per file.

    A CLI tool typically composes its top-level command as a [Cmd.group] of
    subcommands. The convention here is that each subcommand lives in its own
    file (e.g. [bin/cmd_pull.ml] / [bin/cmd_push.ml] / ...), and [bin/main.ml]
    only references them. This keeps each subcommand's arguments, manpage and
    term self-contained and reviewable in isolation.

    A file that defines two or more [Cmd.v ...] terms is mixing several
    subcommands together. Split each one into its own file.

    {b How to fix:} for each [Cmd.v] in the offending file, create a sibling
    file (e.g. [cmd_<name>.ml]) that exposes a single [val cmd : ... Cmd.t], and
    reference it from [main.ml]'s [Cmd.group]. Sub-subcommands of a grouped
    subcommand should likewise live one-per-file (use a directory like
    [cmd_verse/] with one file per leaf, or use [cmd_verse_<name>.ml] siblings).
*)

type payload = { file : string; count : int }

let cmd_v_re =
  Re.compile (Re.seq [ Re.bow; Re.str "Cmd"; Re.char '.'; Re.str "v"; Re.eow ])

let count_cmd_v contents = Re.all cmd_v_re contents |> List.length

let read_file path =
  try
    let ic = open_in path in
    let n = in_channel_length ic in
    let s = really_input_string ic n in
    close_in ic;
    Some s
  with Sys_error _ -> None

let find_ml_files root =
  let try_readdir d =
    try Sys.readdir d |> Array.to_list with Sys_error _ -> []
  in
  let is_dir p = try Sys.is_directory p with Sys_error _ -> false in
  let rec walk dir acc =
    List.fold_left
      (fun acc name ->
        if
          name = "_build" || name = "_opam" || name = ".git"
          || String.starts_with ~prefix:"." name
        then acc
        else
          let p = Filename.concat dir name in
          if is_dir p then walk p acc
          else if Filename.check_suffix name ".ml" then p :: acc
          else acc)
      acc (try_readdir dir)
  in
  walk root []

let check (ctx : Context.project) =
  let files = find_ml_files ctx.project_root in
  List.filter_map
    (fun path ->
      match read_file path with
      | None -> None
      | Some contents ->
          let count = count_cmd_v contents in
          if count >= 2 then Some (Issue.v { file = path; count }) else None)
    files

let pp ppf { file; count } =
  Fmt.pf ppf
    "%s defines %d Cmdliner subcommands in one file; split them into one file \
     per subcommand"
    file count

let rule =
  Rule.v ~code:"E524" ~title:"Multiple Cmdliner subcommands in one file"
    ~category:Rule.Project_structure
    ~hint:
      "Each Cmd.v subcommand should live in its own file. Move each Cmd.v into \
       a sibling file (e.g. cmd_<name>.ml exposing a single val cmd) and \
       reference it from main.ml's Cmd.group. Sub-subcommands of a grouped \
       subcommand follow the same rule — use cmd_<parent>/<leaf>.ml or \
       cmd_<parent>_<leaf>.ml siblings."
    ~examples:[] ~pp (Project check)

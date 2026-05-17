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

type payload = { count : int }

(* Match the resolved [Cmdliner.Cmd.v] path. Requires typedtree so a local
   [Cmd] module doesn't trip the rule and an [open Cmdliner; Cmd.v] site
   still does. *)
let count_cmd_v identifiers =
  List.fold_left
    (fun acc ident ->
      if File_view.Reference.matches_path ident [ "Cmdliner"; "Cmd"; "v" ] then
        acc + 1
      else acc)
    0 identifiers

let is_cmd_v_call call =
  let callee = File_view.Call.callee call in
  match (File_view.Name.prefix callee, File_view.Name.base callee) with
  | [ "Cmd" ], "v" | [ "Cmdliner"; "Cmd" ], "v" -> true
  | _ -> false

let count_cmd_v_surface view =
  let count = ref 0 in
  File_view.iter_applications view (fun call ->
      if is_cmd_v_call call then incr count);
  !count

let check (ctx : Context.file) =
  if not (Filename.check_suffix ctx.filename ".ml") then []
  else
    match File_view.resolved_identifiers (Context.view ctx) with
    | None ->
        let count = count_cmd_v_surface (Context.view ctx) in
        if count >= 2 then
          [ Issue.v ~loc:(Location.in_file ctx.filename) { count } ]
        else []
    | Some identifiers ->
        let count = count_cmd_v identifiers in
        if count >= 2 then
          [ Issue.v ~loc:(Location.in_file ctx.filename) { count } ]
        else []

let pp ppf { count } =
  Fmt.pf ppf
    "defines %d Cmdliner subcommands in one file; split them into one file per \
     subcommand"
    count

let rule =
  Rule.v ~code:"E524" ~title:"Multiple Cmdliner subcommands in one file"
    ~category:Rule.Project_structure
    ~hint:
      "Each Cmd.v subcommand should live in its own file. Move each Cmd.v into \
       a sibling file (e.g. cmd_<name>.ml exposing a single val cmd) and \
       reference it from main.ml's Cmd.group. Sub-subcommands of a grouped \
       subcommand follow the same rule — use cmd_<parent>/<leaf>.ml or \
       cmd_<parent>_<leaf>.ml siblings."
    ~examples:[] ~pp (File check)

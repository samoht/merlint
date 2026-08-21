(** Shell out to [dune build] for the artefacts typedtree-backed rules need. See
    {!Build.mli}. *)

let src = Logs.Src.create "merlint.build" ~doc:"Build helpers"

module Log = (val Logs.src_log src : Logs.LOG)

let err fmt = Fmt.kstr (fun s -> Error s) fmt
let err_build_failed msg = err "Failed to build project: %s" msg

let err_outside_root ~root scope =
  err "%a is outside the dune root %a, so it has no [@@check] alias there"
    Fpath.pp scope Fpath.pp root

let log_command cmd =
  match Logs.level () with
  | Some (Logs.Info | Logs.Debug) ->
      Fmt.epr "Running: %s@.    cwd: %s@." cmd (Sys.getcwd ())
  | _ -> ()

(* How dune names the [check] alias of the directory [rel] on its command line.
   [rel] is relative to the dune root, which is where dune resolves it from. *)
let alias_of_rel rel = Fmt.str "@@%a/check" Fpath.pp (Fpath.rem_empty_seg rel)

(* The [check] alias to ask [dune build] for on behalf of [scope]: the bare one
   at [root] itself, the directory's own below it. Dune resolves a scoped alias
   against the whole workspace, so cross-package dependencies still build and
   only the targets narrow. A scope [root] does not contain has no alias here,
   and warming the whole tree in its place would build something other than
   what was asked for without saying so. *)
let check_alias ~root scope =
  let scope = Fpath.(to_dir_path (normalize scope)) in
  if not (Fpath.is_prefix root scope) then err_outside_root ~root scope
  else
    match Fpath.relativize ~root scope with
    | None -> err_outside_root ~root scope
    | Some rel when Fpath.equal rel (Fpath.v "./") -> Ok "@check"
    | Some rel -> Ok (alias_of_rel rel)

(* One alias per scope, in the order given and without repeats, so two files of
   one directory name that directory once. *)
let check_aliases ~root scopes =
  let rec collect acc = function
    | [] -> Ok (List.rev acc)
    | scope :: rest -> (
        match check_alias ~root scope with
        | Error msg -> Error msg
        | Ok alias when List.mem alias acc -> collect acc rest
        | Ok alias -> collect (alias :: acc) rest)
  in
  collect [] scopes

let ensure_project_built ~root ~scopes mgr =
  let root = Fpath.(to_dir_path (normalize root)) in
  match check_aliases ~root scopes with
  | Error msg -> Error msg
  | Ok aliases -> (
      let aliases =
        match aliases with [] -> [ "@check" ] | aliases -> aliases
      in
      let suppress_stderr =
        match Logs.Src.level src with
        | Some Logs.Debug -> ""
        | _ -> " 2>/dev/null"
      in
      let cmd =
        Fmt.str "dune build --root %s %s%s"
          (Filename.quote (Fpath.to_string root))
          (String.concat " " (List.map Filename.quote aliases))
          suppress_stderr
      in
      log_command cmd;
      match Command.run mgr cmd with
      | Ok _ -> Ok ()
      | Error msg -> err_build_failed msg)

(* [.cmt]/[.cmti] for [file] with [true] when it describes the current source.
   Whether an artefact still describes its source is {!Merlin.Cmt}'s to answer,
   so a rebuild decision here and a rule's reading of the same artefact cannot
   disagree about which files a run actually examined. *)
let cmt_artefact ~root file =
  let file = Fpath.to_string file in
  match Merlin.Project.cmt ~root_dir:root file with
  | None -> None
  | Some cmt when not (Sys.file_exists cmt) -> None
  | Some cmt -> Some (cmt, Merlin.Cmt.describes ~root_dir:root file)

type source_status = Compiled | Not_compiled | Skipped | Missing

let source_status ~root ~index file =
  match Project_index.source_presence index file with
  | Project_index.Absent -> Missing
  | Project_index.Unindexed -> Skipped
  | Project_index.Indexed -> (
      match cmt_artefact ~root file with
      | Some (_, true) -> Compiled
      | None | Some (_, false) -> Not_compiled)

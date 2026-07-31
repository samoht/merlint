(** Shell out to [dune build] for the artefacts typedtree-backed rules need. See
    {!Build.mli}. *)

let src = Logs.Src.create "merlint.build" ~doc:"Build helpers"

module Log = (val Logs.src_log src : Logs.LOG)

let err_build_failed msg =
  Fmt.kstr (fun s -> Error s) "Failed to build project: %s" msg

let log_command cmd =
  match Logs.level () with
  | Some (Logs.Info | Logs.Debug) ->
      Fmt.epr "Running: %s@.    cwd: %s@." cmd (Sys.getcwd ())
  | _ -> ()

let ensure_project_built ~path mgr =
  let suppress_stderr =
    match Logs.Src.level src with Some Logs.Debug -> "" | _ -> " 2>/dev/null"
  in
  let cmd =
    Fmt.str "dune build --root %s @check%s" (Filename.quote path)
      suppress_stderr
  in
  log_command cmd;
  match Command.run mgr cmd with
  | Ok _ -> Ok ()
  | Error msg -> err_build_failed msg

let dune_target_of_cmt ~root cmt =
  let build_root =
    Fpath.(v (Dune.Root.default_context_dir root) |> normalize)
  in
  let cmt = Fpath.(v cmt |> normalize) in
  Fpath.rem_prefix build_root cmt

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

let maybe_cmt_target ~root file =
  match cmt_artefact ~root file with
  | None | Some (_, true) -> None
  | Some (cmt, false) -> dune_target_of_cmt ~root cmt

type source_status = Compiled | Not_compiled | Skipped | Missing

let source_status ~root ~index file =
  match Project_index.source_presence index file with
  | Project_index.Absent -> Missing
  | Project_index.Unindexed -> Skipped
  | Project_index.Indexed -> (
      match cmt_artefact ~root file with
      | Some (_, true) -> Compiled
      | None | Some (_, false) -> Not_compiled)

let refresh_stale_cmt_targets ~path ~files mgr =
  let targets = List.filter_map (maybe_cmt_target ~root:path) files in
  match targets with
  | [] -> Ok ()
  | targets -> (
      let cmd =
        "dune build --root " ^ Filename.quote path ^ " "
        ^ String.concat " "
            (List.map (fun p -> Filename.quote (Fpath.to_string p)) targets)
      in
      log_command cmd;
      match Command.run mgr cmd with
      | Ok _ -> Ok ()
      | Error msg -> err_build_failed msg)

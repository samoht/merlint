(** Shell out to [dune build] for the artefacts typedtree-backed rules need. See
    {!Build.mli}. *)

let src = Logs.Src.create "merlint.build" ~doc:"Build helpers"

module Log = (val Logs.src_log src : Logs.LOG)

let err fmt = Fmt.kstr (fun s -> Error s) fmt
let err_build_failed msg = err "Failed to build project: %s" msg

let err_invalidate_failed ~error ~operation ~path =
  err "Failed to invalidate stale typedtree artefact %s: %s (%s)" path
    (Unix.error_message error) operation

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

let is_ocaml_source file =
  let path = Fpath.to_string file in
  Filename.check_suffix path ".ml" || Filename.check_suffix path ".mli"

type stale_cmt = { source : Fpath.t; artefact : string; target : Fpath.t }

let maybe_stale_cmt ~root source =
  match if is_ocaml_source source then cmt_artefact ~root source else None with
  | None | Some (_, true) -> None
  | Some (artefact, false) ->
      dune_target_of_cmt ~root artefact
      |> Option.map (fun target -> { source; artefact; target })

let invalidate_artefact artefact =
  match Unix.unlink artefact with
  | () -> Ok ()
  | exception Unix.Unix_error (Unix.ENOENT, _, _) -> Ok ()
  | exception Unix.Unix_error (error, operation, path) ->
      err_invalidate_failed ~error ~operation ~path

let invalidate_stale_cmts stale_cmts =
  stale_cmts
  |> List.map (fun stale -> stale.artefact)
  |> List.sort_uniq String.compare
  |> List.fold_left
       (fun result artefact ->
         match result with
         | Error _ -> result
         | Ok () -> invalidate_artefact artefact)
       (Ok ())

let stale_sources ~root stale_cmts =
  List.filter_map
    (fun stale ->
      if Merlin.Cmt.describes ~root_dir:root (Fpath.to_string stale.source) then
        None
      else Some stale.source)
    stale_cmts

let err_still_stale sources =
  let paths =
    sources |> List.map Fpath.to_string |> List.sort_uniq String.compare
  in
  err "Dune completed, but these typedtree artefacts remain stale: %a"
    Fmt.(list ~sep:(any ", ") string)
    paths

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
  let stale_cmts = List.filter_map (maybe_stale_cmt ~root:path) files in
  match stale_cmts with
  | [] -> Ok ()
  | stale_cmts -> (
      let targets =
        stale_cmts
        |> List.map (fun stale -> stale.target)
        |> List.sort_uniq Fpath.compare
      in
      match invalidate_stale_cmts stale_cmts with
      | Error _ as error -> error
      | Ok () -> (
          let cmd =
            "dune build --cache=disabled --root " ^ Filename.quote path ^ " "
            ^ String.concat " "
                (List.map (fun p -> Filename.quote (Fpath.to_string p)) targets)
          in
          log_command cmd;
          match Command.run mgr cmd with
          | Ok _ -> (
              match stale_sources ~root:path stale_cmts with
              | [] -> Ok ()
              | sources -> err_still_stale sources)
          | Error msg -> err_build_failed msg))

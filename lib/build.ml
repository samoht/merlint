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
  let build_root = Fpath.(v root / "_build" / "default" |> normalize) in
  let cmt = Fpath.(v cmt |> normalize) in
  Fpath.rem_prefix build_root cmt

let maybe_cmt_target ~root file =
  match Merlin.Project.cmt ~root_dir:root (Fpath.to_string file) with
  | None -> None
  | Some cmt when not (Sys.file_exists cmt) -> None
  | Some cmt -> (
      try
        let source_mtime = (Unix.stat (Fpath.to_string file)).st_mtime in
        let cmt_mtime = (Unix.stat cmt).st_mtime in
        if cmt_mtime >= source_mtime then None else dune_target_of_cmt ~root cmt
      with Unix.Unix_error _ -> None)

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

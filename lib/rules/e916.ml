(** E916: a [dune.lock] that does not honour a [dune-project] pin.

    Runs only on a project that has both a [dune-project] declaring [(pin ...)]
    stanzas and a [dune.lock] directory beside it. A project that pins nothing,
    or that has no lock to check the pins against, is skipped silently.

    The comparison itself is {!Dune.Lock.unhonoured}: for each package a pin
    provides, the URL the pin declares against the source the lock entry
    records. *)

let log_src = Logs.Src.create "merlint.rules.e916" ~doc:"E916 rule diagnostics"

module Log = (val Logs.src_log log_src : Logs.LOG)

type payload = Dune.Lock.mismatch

let read ctx path =
  match Context.file_content ctx path with
  | content -> Some content
  | exception Sys_error _ -> None
  | exception File_view.Analysis_error _ -> None

let pins ctx dune_project =
  match read ctx dune_project with
  | None -> []
  | Some content -> (
      match Dune.Project.of_string content with
      | Ok project -> Dune.Project.pins project
      | Error _ -> [])

let pinned_packages pins =
  List.concat_map
    (fun pin ->
      List.map
        (fun (p : Dune.Project.Pin.package) -> p.name)
        (Dune.Project.Pin.packages pin))
    pins

(* dune names a lock entry [<package>.<version>.pkg] and package names carry no
   dot, so the pinned names select their own entries by prefix and the rest of
   the lock -- 151 entries in the tree this was measured on -- is never read.
   Which package an entry describes is still {!Dune.Lock.Pkg.name}'s answer,
   not the prefix's: an entry whose file name and recorded version disagree is
   dropped here and reported as a missing entry, which is the safe direction. *)
let entries ctx root names =
  let dir = Fpath.(root / "dune.lock") in
  let selects file_name =
    Filename.check_suffix file_name ".pkg"
    && List.exists
         (fun n -> String.starts_with ~prefix:(n ^ ".") file_name)
         names
  in
  Fs.readdir_or_empty (Fpath.to_string dir)
  |> List.filter selects
  |> List.filter_map (fun file_name ->
      match read ctx (Context.resolve ctx Fpath.(dir / file_name)) with
      | None -> None
      | Some content -> (
          match Dune.Lock.Pkg.of_string content with
          | Error _ -> None
          | Ok e ->
              Option.map
                (fun name -> (name, e))
                (Dune.Lock.Pkg.name ~file_name e)))

let check (ctx : Context.project) =
  let root = Fpath.v (Context.project_root_path ctx) in
  if not (Fs.is_directory (Fpath.to_string Fpath.(root / "dune.lock"))) then []
  else
    let dune_project = Context.resolve ctx Fpath.(root / "dune-project") in
    match pins ctx dune_project with
    | [] -> []
    | pins ->
        let names = pinned_packages pins in
        let entries = entries ctx root names in
        Log.debug (fun m ->
            m "E916: %d pinned package(s), %d lock entr(ies)"
              (List.length names) (List.length entries));
        let loc =
          Loc.in_file
            (Loc.current_dir_relative (Context.fpath_of_path dune_project))
        in
        Dune.Lock.unhonoured ~pins ~entries
        |> List.map (fun mismatch -> Issue.v ~loc mismatch)

let pp : payload Fmt.t = Dune.Lock.pp_mismatch

let rule =
  Rule.v ~code:"E916" ~title:"Unhonoured source pin"
    ~category:Rule.Project_structure
    ~hint:
      "A (pin ...) stanza names the exact revision its packages are built \
       from, and `dune pkg lock` resolves the package from somewhere else \
       rather than failing when it cannot honour one -- an overlay's copy, or \
       the released archive, which beats a pin that names no version. Re-run \
       `dune pkg lock` and check the entry again; if the pinned revision still \
       does not win, give the pin's (package ...) a (version ...) so the \
       release cannot outrank it, or point the pin at a revision that exists."
    ~examples:[] ~pp (Project check)

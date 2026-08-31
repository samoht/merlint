(** Shell out to [dune build] for the artefacts typedtree-backed rules need. See
    {!Build.mli}. *)

let src = Logs.Src.create "merlint.build" ~doc:"Build helpers"

module Log = (val Logs.src_log src : Logs.LOG)

type unbuilt = Contended of string | Broken of string | Unscoped of string

let message = function
  | Contended msg ->
      Fmt.str
        "another dune session holds this build root, so the build has not run: \
         %s"
        msg
  | Broken msg -> Fmt.str "the project does not build: %s" msg
  | Unscoped msg -> msg

(* Dune answers a root another instance holds and code that does not compile
   with the same exit code, and says which on stderr. These are the shapes it
   prints when the build never started: a client that reached a server and got
   no build out of it, one whose connection to it died, and the plain lock
   refusal. Anything else is read as the project not building.

   The direction of a misreading is the reason this is a list of markers rather
   than a parse. Contention read as breakage refuses immediately instead of
   waiting; breakage read as contention waits and then refuses. Both end in a
   refusal, so neither costs a verdict -- only wall time. *)
let contention_markers =
  [
    "error kind: Code_error";
    "Connection_dead";
    "Server returned error";
    "lock the build directory";
    "Another instance of dune";
  ]

let classify msg =
  if
    List.exists
      (fun affix -> Astring.String.is_infix ~affix msg)
      contention_markers
  then Contended msg
  else Broken msg

let err_outside_root ~root scope =
  Fmt.kstr
    (fun s -> Error (Unscoped s))
    "%a is outside the dune root %a, so it has no [@@check] alias there"
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

let target_of_path ~root target =
  let target = Fpath.(normalize target |> rem_empty_seg) in
  if not (Fpath.is_prefix root target) then err_outside_root ~root target
  else
    match Fpath.relativize ~root target with
    | None -> err_outside_root ~root target
    | Some rel -> Ok Fpath.(to_string (rem_empty_seg rel))

let target_args ~root targets =
  let rec collect acc = function
    | [] -> Ok (List.rev acc)
    | target :: rest -> (
        match target_of_path ~root target with
        | Error msg -> Error msg
        | Ok target when List.mem target acc -> collect acc rest
        | Ok target -> collect (target :: acc) rest)
  in
  collect [] targets

let ensure_project_built ~root ~scopes ~targets mgr =
  let root = Fpath.(to_dir_path (normalize root)) in
  match (check_aliases ~root scopes, target_args ~root targets) with
  | Error msg, _ | _, Error msg -> Error msg
  | Ok aliases, Ok targets -> (
      let requests =
        match aliases @ targets with [] -> [ "@check" ] | requests -> requests
      in
      let cmd =
        Fmt.str "dune build --root %s %s"
          (Filename.quote (Fpath.to_string root))
          (String.concat " " (List.map Filename.quote requests))
      in
      log_command cmd;
      match Command.run mgr cmd with
      | Ok _ -> Ok ()
      | Error msg -> Error (classify msg))

(* [.cmt]/[.cmti] for [file] with what it can answer for the current source.
   Whether an artefact still describes its source is {!Merlin.Cmt}'s to answer,
   so a rebuild decision here and a rule's reading of the same artefact cannot
   disagree about which files a run actually examined. *)
let cmt_artefact ~root file =
  let file = Fpath.to_string file in
  match Merlin.Project.cmt ~root_dir:root file with
  | None -> None
  | Some cmt when not (Sys.file_exists cmt) -> None
  | Some cmt -> Some (cmt, Merlin.Cmt.status ~root_dir:root file)

let materialized_artefacts ~root ~index file =
  Project_index.materialized_source_files index (Fpath.v file)
  |> List.concat_map (fun materialized ->
      Merlin.Project.materialized_cmts ~root_dir:root
        (Fpath.to_string materialized))
  |> List.map (fun (m : Merlin.Project.materialized_cmt) ->
      (m.cmt, Merlin.Cmt.status ~root_dir:m.root_dir m.source_file))

type source_status =
  | Compiled
  | Not_compiled
  | Uncompilable
  | Skipped
  | Missing

(* A source the compiler refused is its own answer, not a variety of
   [Not_compiled]. The artefact left for it looks current -- it carries the
   digest of the whole file -- while describing only the part typed before the
   error, so reading it as the record of the unit reports on code the compiler
   never accepted. And no build clears it: [dune build] will fail on the same
   error, which is what [Not_compiled] would have the caller recommend. *)
let source_status ~root ~index file =
  match Project_index.source_presence index file with
  | Project_index.Absent -> Missing
  | Project_index.Unindexed -> Skipped
  | Project_index.Indexed ->
      let artefacts =
        Option.to_list (cmt_artefact ~root file)
        @ materialized_artefacts ~root ~index (Fpath.to_string file)
      in
      if List.exists (fun (_, status) -> Result.is_ok status) artefacts then
        Compiled
      else if
        List.exists
          (function _, Error Merlin.Cmt.Unusable.Partial -> true | _ -> false)
          artefacts
      then Uncompilable
      else Not_compiled

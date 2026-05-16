(** E525: Package root dune must enable strict warnings for standalone builds.

    Inside the monorepo, the workspace-root [dune] file declares

    {v (env (dev (flags :standard %{dune-warnings}))) v}

    which promotes warnings to errors under the [dev] profile. That stanza only
    applies when dune is run from the workspace root. When a package is
    published standalone (e.g. installed via opam from its own subtree), the
    workspace-root [dune] is not shipped and the strict-warnings policy
    disappears — a release that was clean in-tree may compile with warnings
    after upstream publication.

    Each package must therefore carry its own root [dune] file that redeclares
    the [%\{dune-warnings\}] flag set, and its [dune-project] must declare
    [(lang dune 3.21)] or newer (the release that introduced
    [%\{dune-warnings\}]).

    Reference standalone package: [alcobar/dune]:

    {v (env (dev (flags :standard %{dune-warnings}))) v}

    {b How to fix:}
    - create [<package>/dune] with the stanza above, and
    - set [(lang dune 3.21)] (or newer) in [<package>/dune-project]. *)

type kind =
  | Missing_dune
  | Missing_warnings
  | Lang_too_old of { version : string }

type payload = { package : string; kind : kind }

let min_major = 3
let min_minor = 21
let try_readdir d = try Sys.readdir d |> Array.to_list with Sys_error _ -> []
let is_dir p = try Sys.is_directory p with Sys_error _ -> false

let skip_entry name =
  name = "_build" || name = "_opam" || name = ".git"
  || String.starts_with ~prefix:"." name

let has_opam_file pkg_dir =
  List.exists
    (fun name -> Filename.check_suffix name ".opam")
    (try_readdir pkg_dir)

let content ctx path =
  try Some (File_view.content (Context.file_view ctx path))
  with Sys_error _ | File_view.Analysis_error _ -> None

let version_too_old v =
  match String.split_on_char '.' v with
  | major :: minor :: _ -> (
      match (int_of_string_opt major, int_of_string_opt minor) with
      | Some mj, Some mn -> mj < min_major || (mj = min_major && mn < min_minor)
      | _, _ -> false)
  | _ -> false

let dune_issue ctx name dune_path =
  let loc = Location.in_file dune_path in
  if not (Sys.file_exists dune_path) then
    [ Issue.v ~loc { package = name; kind = Missing_dune } ]
  else
    match content ctx dune_path with
    | Some c -> (
        match Dune.File.of_string c with
        | Ok file when Dune.File.has_dune_warnings file -> []
        | Ok _ | Error _ ->
            [ Issue.v ~loc { package = name; kind = Missing_warnings } ])
    | _ -> [ Issue.v ~loc { package = name; kind = Missing_warnings } ]

let lang_issue ctx name dp_path =
  match content ctx dp_path with
  | Some c -> (
      match Dune.Project.of_string c with
      | Error _ -> []
      | Ok project -> (
          let _lang, version = Dune.Project.lang project in
          match Some version with
          | Some version when version_too_old version ->
              [
                Issue.v ~loc:(Location.in_file dp_path)
                  { package = name; kind = Lang_too_old { version } };
              ]
          | _ -> []))
  | None -> []

let check_package ctx root name =
  if skip_entry name then []
  else
    let pkg_dir = Filename.concat root name in
    if (not (is_dir pkg_dir)) || not (has_opam_file pkg_dir) then []
    else
      let dune_path = Filename.concat pkg_dir "dune" in
      let dp_path = Filename.concat pkg_dir "dune-project" in
      dune_issue ctx name dune_path @ lang_issue ctx name dp_path

let check (ctx : Context.project) =
  let root = ctx.project_root in
  List.concat_map (check_package ctx root) (try_readdir root)

let pp ppf { package; kind } =
  match kind with
  | Missing_dune ->
      Fmt.pf ppf
        "%s has no root dune file; add %s/dune with (env (dev (flags :standard \
         %%{dune-warnings}))) so standalone opam builds fail on warnings"
        package package
  | Missing_warnings ->
      Fmt.pf ppf
        "%s/dune does not enable %%{dune-warnings}; add (env (dev (flags \
         :standard %%{dune-warnings}))) so standalone opam builds fail on \
         warnings"
        package
  | Lang_too_old { version } ->
      Fmt.pf ppf
        "%s/dune-project declares (lang dune %s); %%{dune-warnings} requires \
         (lang dune %d.%d) or newer"
        package version min_major min_minor

let rule =
  Rule.v ~code:"E525" ~title:"Package root dune missing %{dune-warnings}"
    ~category:Rule.Project_structure
    ~hint:
      "Create <package>/dune containing (env (dev (flags :standard \
       %{dune-warnings}))), and bump <package>/dune-project to (lang dune \
       3.21) or newer. This mirrors the workspace-root dune so that a \
       standalone opam build of the package still enforces strict warnings \
       under the dev profile. Reference: alcobar/dune."
    ~examples:[] ~pp (Project check)

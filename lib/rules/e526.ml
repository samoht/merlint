(** E526: Package dune-project must disable implicit transitive deps.

    With [(implicit_transitive_deps true)] (the dune default), all transitive
    library dependencies are visible at compile time. That makes
    [(re_export foo)] meaningless for visibility and quietly propagates deps
    into downstream META [requires], which leaks into consumers' opam depends.

    Each package [dune-project] must declare

    {v (implicit_transitive_deps false) v}

    or the graceful-fallback variant on older OCaml:

    {v (implicit_transitive_deps false-if-hidden-includes-supported) v}

    so only libraries listed in [(libraries ...)] are in scope, and [re_export]
    regains its intended role as the explicit opt-in for forwarding a dep to
    consumers.

    {b How to fix:}
    - add [(implicit_transitive_deps false)] to [<package>/dune-project], and
    - audit each [(libraries ...)] clause to list any previously transitive deps
      the package actually uses. *)

type kind = Missing | Set_to_true
type payload = { package : string; kind : kind }

let issue_of_setting name loc = function
  | Some "false" | Some "false-if-hidden-includes-supported" -> []
  | Some "true" -> [ Issue.v ~loc { package = name; kind = Set_to_true } ]
  | Some _ | None -> [ Issue.v ~loc { package = name; kind = Missing } ]

let check_package pkg =
  if Project_index.Package.is_anonymous pkg then []
  else if Project_index.Package.library_names pkg = [] then
    (* A package that ships no dune library can't leak transitive deps
       through META requires -- [implicit_transitive_deps] is irrelevant. *)
    []
  else
    match Project_index.Package.raw_dune_project pkg with
    | None -> []
    | Some c -> (
        match Dune.Project.of_string c with
        | Error _ -> []
        | Ok project ->
            let name = Project_index.Package.name pkg in
            let loc =
              match Project_index.Package.source_dir pkg with
              | None -> Location.in_file (Filename.concat name "dune-project")
              | Some dir ->
                  Fpath.(dir / "dune-project")
                  |> Loc.current_dir_relative |> Loc.in_file
            in
            issue_of_setting name loc
              (Dune.Project.implicit_transitive_deps project))

let check (ctx : Context.project) =
  Context.index ctx |> Project_index.source_package_list
  |> List.concat_map check_package

let pp ppf { package; kind } =
  match kind with
  | Missing ->
      Fmt.pf ppf
        "%s/dune-project is missing (implicit_transitive_deps false); \
         transitive deps leak into downstream META requires and pollute \
         consumers' opam depends"
        package
  | Set_to_true ->
      Fmt.pf ppf
        "%s/dune-project sets (implicit_transitive_deps true); change to false \
         (or false-if-hidden-includes-supported) to keep transitive deps \
         scoped to the library that needs them"
        package

let rule =
  Rule.v ~code:"E526"
    ~title:"Package dune-project must disable implicit transitive deps"
    ~category:Rule.Project_structure
    ~hint:
      "Add (implicit_transitive_deps false) to <package>/dune-project (or \
       (implicit_transitive_deps false-if-hidden-includes-supported) if you \
       need to keep compatibility with OCaml < 5.2). Then audit each \
       (libraries ...) clause to list any transitive deps the package actually \
       uses directly. This makes (re_export ...) meaningful again and prevents \
       deps from leaking into downstream opam depends via META requires."
    ~examples:[] ~pp (Project check)

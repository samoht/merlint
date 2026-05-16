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

let stanza_re =
  Re.compile
    (Re.seq
       [
         Re.char '(';
         Re.rep Re.space;
         Re.str "implicit_transitive_deps";
         Re.rep1 Re.space;
         Re.group
           (Re.alt
              [
                Re.str "false-if-hidden-includes-supported";
                Re.str "false";
                Re.str "true";
              ]);
         Re.rep Re.space;
         Re.char ')';
       ])

let find_setting contents =
  match Re.exec_opt stanza_re contents with
  | None -> None
  | Some g -> Some (Re.Group.get g 1)

let issue_of_setting name loc = function
  | Some "false" | Some "false-if-hidden-includes-supported" -> []
  | Some "true" -> [ Issue.v ~loc { package = name; kind = Set_to_true } ]
  | Some _ | None -> [ Issue.v ~loc { package = name; kind = Missing } ]

let check_package ctx root name =
  if skip_entry name then []
  else
    let pkg_dir = Filename.concat root name in
    if (not (is_dir pkg_dir)) || not (has_opam_file pkg_dir) then []
    else
      let dp_path = Filename.concat pkg_dir "dune-project" in
      match content ctx dp_path with
      | None -> []
      | Some c ->
          issue_of_setting name (Location.in_file dp_path) (find_setting c)

let check (ctx : Context.project) =
  let root = ctx.project_root in
  List.concat_map (check_package ctx root) (try_readdir root)

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

(** E522: Package-prefixed module names belong in sublibs, not the main lib.

    If a package [foo] keeps modules named [foo_bar.ml], [foo_baz.ml] etc.
    directly under [lib/] it is usually a leftover from a period where the
    package wasn't wrapped. Dune's default [wrapped = true] makes the modules
    accessible as [Foo.Bar] / [Foo.Baz] automatically, so the prefix adds
    nothing and pollutes the source tree.

    The legitimate use for a [<pkg>_xxx.ml] name is a {e sublibrary}: a sibling
    directory ([lib_xxx/] or [lib/xxx/]) with its own [dune] and
    [(public_name foo.xxx)]. In that case the prefix encodes the qualified
    public name and is not flagged.

    {b How to fix:} rename the prefixed modules to drop the package prefix and
    rely on dune's wrapping; or move them into their own sublib directory if
    they really need to be independently installable. *)

type payload = { package : string; file : string }

let try_readdir d = try Fs.readdir d |> Array.to_list with Sys_error _ -> []
let is_dir p = try Fs.is_directory p with Sys_error _ -> false

let modules_explicitly_claimed ctx dune_path =
  try
    match Context.file_content ctx dune_path |> Dune.File.of_string with
    | Ok file -> Dune.File.explicitly_claimed_modules file
    | Error _ -> []
  with File_view.Analysis_error _ -> []

let package_prefix pkg =
  let p =
    if String.starts_with ~prefix:"ocaml-" pkg then
      String.sub pkg 6 (String.length pkg - 6)
    else pkg
  in
  String.map (fun c -> if c = '-' then '_' else c) p ^ "_"

let prefixed_module ~prefix name =
  Filename.check_suffix name ".ml"
  && String.length name > String.length prefix + 3
  && String.starts_with ~prefix name

let issue_for_module pkg claimed prefix name =
  if prefixed_module ~prefix name then
    let mod_name = String.lowercase_ascii (Filename.chop_suffix name ".ml") in
    if List.mem mod_name claimed then None
    else
      let path = Filename.concat (Filename.concat pkg "lib") name in
      let loc = Location.in_file path in
      Some (Issue.v ~loc { package = pkg; file = path })
  else None

let package_issues ctx root pkg =
  let pkg_dir = Filename.concat root pkg in
  let lib_dir = Filename.concat pkg_dir "lib" in
  if pkg = "_build" || pkg = "_opam" || pkg = ".git" || not (is_dir lib_dir)
  then []
  else
    let claimed =
      modules_explicitly_claimed ctx
        (Context.resolve ctx (Fpath.v (Filename.concat lib_dir "dune")))
    in
    let prefix = package_prefix pkg in
    try_readdir lib_dir |> List.filter_map (issue_for_module pkg claimed prefix)

let check (ctx : Context.project) =
  let root = Context.project_root_path ctx in
  try_readdir root |> List.concat_map (package_issues ctx root)

let pp ppf { package = _; file } =
  Fmt.pf ppf
    "%s uses package-prefixed module name; drop the prefix and let dune's \
     wrapping expose it as a submodule, or move it into a sublib directory"
    file

let rule =
  Rule.v ~code:"E522"
    ~title:"Package-prefixed module in main lib/ instead of wrapped submodule"
    ~category:Rule.Project_structure
    ~hint:
      "Rename <pkg>/lib/<pkg>_foo.ml to <pkg>/lib/foo.ml (and update the .mli \
       similarly). Dune's default wrapped mode will expose it as <Pkg>.Foo. \
       For something that really needs its own public name, create a sublib \
       directory (<pkg>/lib_foo/ with its own dune) instead."
    ~examples:[] ~pp (Project check)

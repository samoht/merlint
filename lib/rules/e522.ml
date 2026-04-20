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

let check (ctx : Context.project) =
  let root = ctx.project_root in
  let try_readdir d =
    try Sys.readdir d |> Array.to_list with Sys_error _ -> []
  in
  let issues = ref [] in
  let packages = try_readdir root in
  List.iter
    (fun pkg ->
      let pkg_dir = Filename.concat root pkg in
      let lib_dir = Filename.concat pkg_dir "lib" in
      let is_dir p = try Sys.is_directory p with Sys_error _ -> false in
      if pkg <> "_build" && pkg <> "_opam" && pkg <> ".git" && is_dir lib_dir
      then
        let prefix =
          (* Accept both [foo] and [ocaml-foo] package dirs; the module
             prefix is [foo_] in both cases. *)
          let p =
            if String.starts_with ~prefix:"ocaml-" pkg then
              String.sub pkg 6 (String.length pkg - 6)
            else pkg
          in
          (* Dune mangles [-] to [_] in module names. *)
          String.map (fun c -> if c = '-' then '_' else c) p ^ "_"
        in
        let has_ml name = Filename.check_suffix name ".ml" in
        List.iter
          (fun name ->
            if
              has_ml name
              && String.length name > String.length prefix + 3
              && String.sub name 0 (String.length prefix) = prefix
            then
              let path = Filename.concat (Filename.concat pkg "lib") name in
              issues := Issue.v { package = pkg; file = path } :: !issues)
          (try_readdir lib_dir))
    packages;
  !issues

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

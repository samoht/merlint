(** E520: Package library directory should be named lib/, not src/.

    The monorepo convention is that a package's primary library lives under
    [lib/]. Older packages that still use [src/] must be renamed. *)

type payload = { package : string }

let check (ctx : Context.project) =
  let root = Context.project_root_path ctx in
  let try_readdir d =
    try Fs.readdir d |> Array.to_list with Sys_error _ -> []
  in
  let issues = ref [] in
  let packages = try_readdir root in
  List.iter
    (fun pkg ->
      let pkg_dir = Filename.concat root pkg in
      if
        Fs.file_exists pkg_dir && Fs.is_directory pkg_dir && pkg <> "_build"
        && pkg <> ".git" && pkg <> "_opam"
      then
        let src_dir = Filename.concat pkg_dir "src" in
        let has_ml f = Filename.check_suffix f ".ml" in
        if Fs.file_exists src_dir && Fs.is_directory src_dir then
          let src_has_ml = List.exists has_ml (try_readdir src_dir) in
          if src_has_ml then
            let loc = Location.in_file (Filename.concat pkg "dune-project") in
            issues := Issue.v ~loc { package = pkg } :: !issues)
    packages;
  !issues

let pp ppf { package } =
  Fmt.pf ppf
    "%s uses src/ for its library; rename to lib/ to match the monorepo \
     convention"
    package

let rule =
  Rule.v ~code:"E520" ~title:"Library directory should be lib/, not src/"
    ~category:Rule.Project_structure
    ~hint:
      "The monorepo convention is lib/ for library code. Rename src/ to lib/ \
       with `git mv`; no dune changes are needed because dune auto-discovers \
       modules in either directory."
    ~examples:[] ~pp (Project check)

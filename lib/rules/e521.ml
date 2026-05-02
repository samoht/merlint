(** E521: Cram tests belong under test/cram/, not scattered in test/.

    The monorepo convention is that all cram tests for a package live under
    [<package>/test/cram/]:

    {v
      test/cram/
      ├── dune            # one (cram ...) stanza
      ├── helpers.sh      # auto-sourced, exports PATH etc.
      ├── helpers/        # driver exe sources
      │   ├── dune
      │   └── demo.ml
      └── cli.t/
          └── run.t
    v}

    This rule flags cram tests (.t files or .t directories containing run.t)
    that sit directly in test/ rather than under test/cram/. *)

type payload = { package : string; path : string }

let check (ctx : Context.project) =
  let root = ctx.project_root in
  let try_readdir d =
    try Sys.readdir d |> Array.to_list with Sys_error _ -> []
  in
  let issues = ref [] in
  let packages = try_readdir root in
  List.iter
    (fun pkg ->
      let test_dir = Filename.concat (Filename.concat root pkg) "test" in
      let is_cram name full =
        Filename.check_suffix name ".t"
        && ((not (Sys.is_directory full && Sys.file_exists full))
           || Sys.file_exists (Filename.concat full "run.t"))
      in
      if pkg <> "_build" && pkg <> "_opam" && Sys.file_exists test_dir then
        let entries = try_readdir test_dir in
        List.iter
          (fun name ->
            let full = Filename.concat test_dir name in
            let ok = try is_cram name full with Sys_error _ -> false in
            if ok then
              let path = Filename.concat "test" name in
              let loc = Location.in_file (Filename.concat pkg path) in
              issues := Issue.v ~loc { package = pkg; path } :: !issues)
          entries)
    packages;
  !issues

let pp ppf { package; path } =
  Fmt.pf ppf "%s/%s should live under %s/test/cram/" package path package

let rule =
  Rule.v ~code:"E521" ~title:"Cram test outside test/cram/"
    ~category:Rule.Project_structure
    ~hint:
      "Move cram tests (.t files or .t/ directories) under the package's \
       test/cram/ umbrella. Shared driver exes go in test/cram/helpers/; shell \
       setup goes in test/cram/helpers.sh (sourced via (setup_scripts \
       helpers.sh))."
    ~examples:[] ~pp (Project check)

(** E803: Interop test shells out to external tool *)

type payload = { dir : string; pattern : string }

let shell_patterns =
  [
    "Sys.command";
    "Unix.system";
    "Unix.create_process";
    "Unix.open_process";
    "Eio.Process";
    "Eio_process";
  ]

let check (ctx : Context.project) =
  let dirs = Interop.oracle_dirs ctx.project_root in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      if d.has_test_ml then
        let content = Interop.test_content d.path in
        let found =
          List.find_opt
            (fun pat -> Astring.String.is_infix ~affix:pat content)
            shell_patterns
        in
        match found with
        | Some pattern ->
            let loc = Location.in_file (Filename.concat d.path "test.ml") in
            Some (Issue.v ~loc { dir = d.path; pattern })
        | None -> None
      else None)
    dirs

let pp ppf { dir; pattern } =
  Fmt.pf ppf
    "Interop test %s/test.ml calls %s — test must run from traces alone" dir
    pattern

let rule =
  Rule.v ~code:"E803" ~title:"Interop test requires external tool"
    ~category:Interop_testing
    ~hint:
      "Interop tests must run from committed traces without needing the \
       external tool at test time. The test.ml should only read trace files, \
       never shell out to run the oracle. If you need the oracle, put it in \
       the generator script."
    ~examples:[] ~pp (Project check)

(** E803: Interop test shells out to external tool *)

type payload = { dir : string; pattern : string }

let shell_call view =
  let found = ref None in
  File_view.iter_applications view (fun call ->
      let name = File_view.Call.callee call in
      let path = File_view.Name.prefix name @ [ File_view.Name.base name ] in
      match (path, !found) with
      | [ "Sys"; "command" ], None -> found := Some "Sys.command"
      | [ "Unix"; "system" ], None -> found := Some "Unix.system"
      | [ "Unix"; "create_process" ], None ->
          found := Some "Unix.create_process"
      | [ "Unix"; "open_process" ], None -> found := Some "Unix.open_process"
      | [ "Eio"; "Process"; "run" ], None -> found := Some "Eio.Process.run"
      | [ "Eio"; "Process"; "spawn" ], None -> found := Some "Eio.Process.spawn"
      | [ "Eio"; "Process"; "parse_out" ], None ->
          found := Some "Eio.Process.parse_out"
      | [ "Eio_process"; "run" ], None -> found := Some "Eio_process.run"
      | [ "Eio_process"; "spawn" ], None -> found := Some "Eio_process.spawn"
      | _ -> ());
  !found

let check (ctx : Context.project) =
  let dirs = Interop.oracle_dirs ctx.project_root in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      if d.has_test_ml then
        let path = Filename.concat d.path "test.ml" in
        let found =
          try shell_call (Context.file_view ctx path)
          with File_view.Analysis_error _ -> None
        in
        match found with
        | Some pattern ->
            let loc = Location.in_file path in
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

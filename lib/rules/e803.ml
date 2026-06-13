(** E803: Interop test shells out to external tool *)

type payload = { dir : string; pattern : string }

let shell_call view =
  let found = ref None in
  let ends_with path suffix =
    let rec drop n xs =
      if n <= 0 then xs
      else match xs with [] -> [] | _ :: xs -> drop (n - 1) xs
    in
    let len = List.length path in
    let suffix_len = List.length suffix in
    len >= suffix_len && drop (len - suffix_len) path = suffix
  in
  let set call pattern = found := Some (pattern, File_view.Call.loc call) in
  File_view.iter_applications view (fun call ->
      let name = File_view.Call.callee call in
      let path = File_view.Name.prefix name @ [ File_view.Name.base name ] in
      match (path, !found) with
      | _, None when ends_with path [ "Sys"; "command" ] ->
          set call "Sys.command"
      | _, None when ends_with path [ "Unix"; "system" ] ->
          set call "Unix.system"
      | _, None when ends_with path [ "Unix"; "create_process" ] ->
          set call "Unix.create_process"
      | _, None when ends_with path [ "Unix"; "open_process" ] ->
          set call "Unix.open_process"
      | _, None when ends_with path [ "Eio"; "Process"; "run" ] ->
          set call "Eio.Process.run"
      | _, None when ends_with path [ "Eio"; "Process"; "spawn" ] ->
          set call "Eio.Process.spawn"
      | _, None when ends_with path [ "Eio"; "Process"; "parse_out" ] ->
          set call "Eio.Process.parse_out"
      | _, None when ends_with path [ "Eio_process"; "run" ] ->
          set call "Eio_process.run"
      | _, None when ends_with path [ "Eio_process"; "spawn" ] ->
          set call "Eio_process.spawn"
      | _ -> ());
  !found

let check (ctx : Context.project) =
  let dirs = Interop.oracle_dirs_for ctx in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      if d.has_test_ml then
        let path = Path.(d.path / "test.ml") in
        let found =
          try shell_call (Context.file_view ctx path)
          with File_view.Analysis_error _ -> None
        in
        match found with
        | Some (pattern, loc) ->
            Some (Issue.v ~loc { dir = Interop.display d; pattern })
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

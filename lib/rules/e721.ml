(** E621: Misplaced Fuzz Directory *)

type payload = { fuzz_dir : string }

let path_segments s =
  String.split_on_char '/' s |> List.filter (fun s -> s <> "")

(** Check if a fuzz/ directory is nested under a test/ directory. *)
let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  let all_dirs =
    let test_dirs =
      List.filter_map
        (fun (t : Dune.test_info) ->
          match t.files with
          | f :: _ -> Some (Fpath.parent f |> Fpath.to_string)
          | [] -> None)
        (Dune.tests dune_describe)
    in
    let exec_dirs =
      List.filter_map
        (fun (_, files) ->
          match files with
          | f :: _ -> Some (Fpath.parent f |> Fpath.to_string)
          | [] -> None)
        (Dune.executables dune_describe)
    in
    List.sort_uniq String.compare (test_dirs @ exec_dirs)
  in
  List.filter_map
    (fun dir ->
      let segments = path_segments dir in
      let has_fuzz = List.mem "fuzz" segments in
      let has_test = List.mem "test" segments in
      if has_fuzz && has_test then
        let loc =
          Location.v
            ~file:(Filename.concat dir "dune")
            ~start_line:1 ~start_col:0 ~end_line:1 ~end_col:0
        in
        Some (Issue.v ~loc { fuzz_dir = dir })
      else None)
    all_dirs

let pp ppf { fuzz_dir } =
  Fmt.pf ppf
    "Fuzz directory '%s' is nested inside a test directory - fuzz/ should be a \
     sibling of test/, not nested inside it"
    fuzz_dir

let rule =
  Rule.v ~code:"E621" ~title:"Misplaced Fuzz Directory" ~category:Testing
    ~hint:
      "Fuzz directories should be at the same level as test directories \
       (siblings), not nested inside them. Move fuzz/ to be a sibling of \
       test/."
    ~examples:[] ~pp (Project check)

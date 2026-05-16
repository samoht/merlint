(** E820: Hand-rolled CSV parsing in interop test *)

type payload = { dir : string }

let has_resolved_path refs path =
  List.exists (fun r -> File_view.Reference.matches_path r path) refs

let has_resolved_base refs base =
  List.exists (fun r -> File_view.Reference.base r = base) refs

let hand_rolled_csv view =
  match File_view.resolved_identifiers view with
  | None -> false
  | Some refs ->
      let has_open =
        has_resolved_path refs [ "Stdlib"; "open_in" ]
        || has_resolved_base refs "open_in"
      in
      let has_line =
        has_resolved_path refs [ "Stdlib"; "input_line" ]
        || has_resolved_base refs "input_line"
      in
      let has_split =
        has_resolved_path refs [ "Stdlib"; "String"; "split_on_char" ]
        || has_resolved_base refs "split_on_char"
      in
      has_open && has_line && has_split

let check (ctx : Context.project) =
  let dirs = Interop.oracle_dirs ctx.project_root in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      if d.has_test_ml then
        let path = Filename.concat d.path "test.ml" in
        let view = Context.file_view ctx path in
        if hand_rolled_csv view then
          let loc = Location.in_file path in
          Some (Issue.v ~loc { dir = d.path })
        else None
      else None)
    dirs

let pp ppf { dir } =
  Fmt.pf ppf "Interop test %s/test.ml hand-rolls CSV parsing instead of csv" dir

let rule =
  Rule.v ~code:"E820" ~title:"Hand-rolled CSV parsing" ~category:Interop_testing
    ~hint:
      "Use csv (Csv.decode_file with a Csv.Row codec) for CSV trace parsing. \
       Never hand-roll CSV readers with open_in/input_line/split_on_char."
    ~examples:[] ~pp (Project check)

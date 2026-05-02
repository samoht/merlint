(** E820: Hand-rolled CSV parsing in interop test *)

type payload = { dir : string }

let check (ctx : Context.project) =
  let dirs = Interop.find_oracle_dirs ctx.project_root in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      if d.has_test_ml then
        let content = Interop.test_content d.path in
        (* Detect the common hand-rolled pattern: open_in + input_line +
           split_on_char ',' *)
        let has_open_in = Astring.String.is_infix ~affix:"open_in" content in
        let has_input_line =
          Astring.String.is_infix ~affix:"input_line" content
        in
        let has_split_comma =
          Astring.String.is_infix ~affix:"split_on_char" content
          && Astring.String.is_infix ~affix:"','" content
        in
        if has_open_in && has_input_line && has_split_comma then
          let loc = Location.in_file (Filename.concat d.path "test.ml") in
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

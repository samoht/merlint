(** E725: Fuzz Test Name Prefix *)

type payload = {
  fuzz_file : string;
  expected_prefix : string;
  actual_name : string;
}

let is_fuzz_dir = File.is_in_fuzz_dir

(** Extract the expected group name from fuzz_foo.ml -> "foo". *)
let expected_group file =
  let basename = Fpath.(file |> rem_ext |> basename) in
  if String.starts_with ~prefix:"fuzz_" basename then
    Some (String.sub basename 5 (String.length basename - 5))
  else None

(** Extract all add_test name strings from file content. *)
let extract_test_names content =
  let pat =
    Re.compile
      (Re.seq
         [
           Re.str "add_test";
           Re.rep Re.space;
           Re.str "~name:\"";
           Re.group (Re.rep (Re.diff Re.any (Re.char '"')));
           Re.char '"';
         ])
  in
  Re.all pat content
  |> List.filter_map (fun g -> try Some (Re.Group.get g 1) with _ -> None)

(** Check that add_test names in fuzz_foo.ml start with "foo: ". *)
let check ctx =
  let files = Context.all_files ctx in
  List.concat_map
    (fun filename ->
      let fp = Fpath.v filename in
      if Fpath.has_ext ".ml" fp && is_fuzz_dir fp then
        match expected_group fp with
        | None -> []
        | Some expected ->
            let content =
              try In_channel.with_open_text filename In_channel.input_all
              with _ -> ""
            in
            let names = extract_test_names content in
            List.filter_map
              (fun name ->
                let prefix = expected ^ ": " in
                if String.starts_with ~prefix name then None
                else
                  let loc =
                    Location.v ~file:filename ~start_line:1 ~start_col:0
                      ~end_line:1 ~end_col:0
                  in
                  Some
                    (Issue.v ~loc
                       {
                         fuzz_file = filename;
                         expected_prefix = expected;
                         actual_name = name;
                       }))
              names
      else [])
    files

let pp ppf { fuzz_file = _; expected_prefix; actual_name } =
  Fmt.pf ppf "Fuzz test name %S should start with %S" actual_name
    (expected_prefix ^ ": ")

let rule =
  Rule.v ~code:"E725" ~title:"Fuzz Test Name Prefix" ~category:Testing
    ~hint:
      "Fuzz test names must follow the convention \"<module>: <description>\" \
       where <module> matches the filename (fuzz_<module>.ml with underscores \
       replaced by hyphens). This enables automatic grouping in test output."
    ~examples:[] ~pp (Project check)

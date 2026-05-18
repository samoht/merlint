(** E725: Fuzz Test Suite Mismatch *)

module Issue_location = Location

type payload = {
  fuzz_file : string;
  expected_suite : string;
  actual_suite : string;
}

(** Extract the expected suite name from fuzz_foo.ml -> "foo". *)
let expected_suite file =
  let basename = Fpath.(file |> rem_ext |> basename) in
  if String.starts_with ~prefix:"fuzz_" basename then
    Some (String.sub basename 5 (String.length basename - 5))
  else None

let suite_names ctx filename =
  try
    Context.file_view ctx filename
    |> Suite.bindings ~filename
    |> List.filter_map (fun (binding : Suite.binding) -> binding.name)
  with File_view.Analysis_error _ -> []

let issue_for_suite filename expected suite =
  if suite = expected then None
  else
    let loc =
      Issue_location.v ~file:filename ~start_line:1 ~start_col:0 ~end_line:1
        ~end_col:0
    in
    Some
      (Issue.v ~loc
         {
           fuzz_file = filename;
           expected_suite = expected;
           actual_suite = suite;
         })

let check_file ctx filename =
  let fp = Fpath.v filename in
  if not (Fpath.has_ext ".ml" fp && File.is_in_fuzz_dir fp) then []
  else
    match expected_suite fp with
    | None -> []
    | Some expected ->
        suite_names ctx filename
        |> List.filter_map (issue_for_suite filename expected)

(** Check that suite name in fuzz_foo.ml matches "foo". *)
let check ctx =
  let files = Context.analyze_set ctx in
  List.concat_map (check_file ctx) files

let pp ppf { fuzz_file = _; expected_suite; actual_suite } =
  Fmt.pf ppf "Fuzz suite %S should be %S" actual_suite expected_suite

let rule =
  Rule.v ~code:"E725" ~title:"Fuzz Test Suite Mismatch" ~category:Testing
    ~hint:
      "Fuzz tests must declare let suite = (\"<module>\", [...]) where \
       <module> matches the filename: fuzz_<module>.ml should use \
       suite:\"<module>\"."
    ~examples:[] ~pp (Project check)

(** E710: Fuzz Without Library *)

type payload = { fuzz_file : string; expected_module : string }

let is_fuzz_dir = File.is_in_fuzz_dir

(** Extract the expected library module name from a fuzz file. fuzz_foo.ml ->
    foo *)
let expected_lib_module fuzz_file =
  let basename = Fpath.(fuzz_file |> rem_ext |> basename) in
  if String.starts_with ~prefix:"fuzz_" basename then
    Some (String.sub basename 5 (String.length basename - 5))
  else None

let check (ctx : Context.project) =
  let dune_describe = Context.dune_describe ctx in
  let lib_modules = Dune.lib_modules dune_describe in
  let tests = Dune.tests dune_describe in
  let execs = Dune.executables dune_describe in
  let fuzz_files =
    let from_tests =
      List.concat_map
        (fun (t : Dune.test_info) ->
          List.filter (fun f -> Fpath.has_ext ".ml" f && is_fuzz_dir f) t.files)
        tests
    in
    let from_execs =
      List.concat_map
        (fun (_, files) ->
          List.filter (fun f -> Fpath.has_ext ".ml" f && is_fuzz_dir f) files)
        execs
    in
    from_tests @ from_execs
  in
  List.filter_map
    (fun file ->
      match expected_lib_module file with
      | None -> None
      | Some expected ->
          (* Check if this module exists in any library (case-insensitive) *)
          let found =
            List.exists
              (fun lib_mod ->
                String.lowercase_ascii lib_mod = String.lowercase_ascii expected)
              lib_modules
          in
          if not found then
            let loc =
              Location.v ~file:(Fpath.to_string file) ~start_line:1 ~start_col:0
                ~end_line:1 ~end_col:0
            in
            Some
              (Issue.v ~loc
                 {
                   fuzz_file = Fpath.to_string file;
                   expected_module = expected;
                 })
          else None)
    fuzz_files

let pp ppf { fuzz_file = _; expected_module } =
  Fmt.pf ppf "Fuzz file exists but corresponding library module '%s' not found"
    expected_module

let rule =
  Rule.v ~code:"E710" ~title:"Fuzz Without Library" ~category:Testing
    ~hint:
      "Every fuzz module (fuzz_<module>.ml) should have a corresponding \
       library module (<module>.ml). This ensures fuzz tests are testing \
       actual library functionality."
    ~examples:[] ~pp (Project check)

(** E700: Fuzz Module Convention *)

module Issue_location = Location

type payload = { filename : string; module_name : string }

let uses_fuzz_module_suites view =
  Suite.references_with_prefix view ~prefix:"Fuzz_"

let defines_own_tests = Suite.calls_test_case

(* Only flag when we know the runner defines its own tests and know it does not
   delegate. An unbuilt typedtree ([Unresolved]) means we cannot tell, so skip
   rather than report. *)
let inline_tests_without_delegation view =
  match (defines_own_tests view, uses_fuzz_module_suites view) with
  | Suite.Resolved true, Suite.Resolved false -> true
  | _ -> false

(** Check if fuzz.ml properly delegates to fuzz modules via Fuzz_*.suite instead
    of defining its own tests inline. *)
let check ctx =
  let files = Context.analyze_set ctx in
  List.concat_map
    (fun filename ->
      let fp = Context.fpath_of_path filename in
      if
        Context.Path.has_ext ".ml" filename
        && File.is_in_fuzz_dir fp
        && Fpath.(fp |> rem_ext |> basename) = "fuzz"
      then
        try
          let view = Context.file_view ctx filename in
          let filename = Context.string_of_path filename in
          if inline_tests_without_delegation view then
            [
              Issue.v
                ~loc:
                  (Issue_location.v ~file:filename ~start_line:1 ~start_col:0
                     ~end_line:1 ~end_col:0)
                { filename; module_name = "fuzz" };
            ]
          else []
        with File_view.Analysis_error _ -> []
      else [])
    files

let pp ppf { filename; module_name = _ } =
  Fmt.pf ppf
    "Fuzz runner '%s' defines tests inline - use Fuzz_*.suite to delegate to \
     fuzz modules"
    (Filename.basename filename)

let rule =
  Rule.v ~code:"E700" ~title:"Fuzz Module Convention" ~category:Testing
    ~hint:
      "The fuzz runner (fuzz.ml) should collect Fuzz_*.suite from each fuzz \
       module rather than defining test_case directly. This keeps fuzz tests \
       organized per-module."
    ~examples:[] ~pp (Project check)

(** E725: Fuzz Test Suite Mismatch *)

module Issue_location = Location
open Ocaml_parsing

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

(** Extract suite names from [let suite = ("name", [...])] declarations. *)
let suite_name_of_expr (expr : Parsetree.expression) =
  match expr.pexp_desc with
  | Pexp_tuple
      (( _,
         {
           pexp_desc =
             Pexp_constant { pconst_desc = Pconst_string (name, _, _); _ };
           _;
         } )
      :: _) ->
      Some name
  | _ -> None

let extract_suites structure =
  List.filter_map
    (fun (item : Parsetree.structure_item) ->
      match item.pstr_desc with
      | Pstr_value (_, bindings) ->
          List.find_map
            (fun (binding : Parsetree.value_binding) ->
              match binding.pvb_pat.ppat_desc with
              | Ppat_var { txt = "suite"; _ } ->
                  suite_name_of_expr binding.pvb_expr
              | _ -> None)
            bindings
      | _ -> None)
    structure

(** Check that suite name in fuzz_foo.ml matches "foo". *)
let check ctx =
  let files = Context.all_files ctx in
  List.concat_map
    (fun filename ->
      let fp = Fpath.v filename in
      if Fpath.has_ext ".ml" fp && File.is_in_fuzz_dir fp then
        match expected_suite fp with
        | None -> []
        | Some expected ->
            let suites =
              try
                match File_view.parsetree (Context.file_view ctx filename) with
                | None -> []
                | Some structure -> extract_suites structure
              with File_view.Analysis_error _ -> []
            in
            List.filter_map
              (fun suite ->
                if suite = expected then None
                else
                  let loc =
                    Issue_location.v ~file:filename ~start_line:1 ~start_col:0
                      ~end_line:1 ~end_col:0
                  in
                  Some
                    (Issue.v ~loc
                       {
                         fuzz_file = filename;
                         expected_suite = expected;
                         actual_suite = suite;
                       }))
              suites
      else [])
    files

let pp ppf { fuzz_file = _; expected_suite; actual_suite } =
  Fmt.pf ppf "Fuzz suite %S should be %S" actual_suite expected_suite

let rule =
  Rule.v ~code:"E725" ~title:"Fuzz Test Suite Mismatch" ~category:Testing
    ~hint:
      "Fuzz tests must declare let suite = (\"<module>\", [...]) where \
       <module> matches the filename: fuzz_<module>.ml should use \
       suite:\"<module>\"."
    ~examples:[] ~pp (Project check)

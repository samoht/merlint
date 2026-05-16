(** E700: Fuzz Module Convention *)

module Issue_location = Location
open Ocaml_parsing

type payload = { filename : string; module_name : string }

let suite_ref lid =
  match Longident.flatten lid with
  | [ module_name; "suite" ] when String.starts_with ~prefix:"Fuzz_" module_name
    ->
      true
  | _ -> false

let uses_fuzz_module_suites structure =
  let found = ref false in
  Ast.iter_expressions structure (fun (expr : Parsetree.expression) ->
      match expr.pexp_desc with
      | Pexp_ident { txt; _ } when suite_ref txt -> found := true
      | _ -> ());
  !found

let defines_own_tests structure =
  let found = ref false in
  Ast.iter_apply structure (fun _ fn _ ->
      match Longident.flatten fn with
      | [ "Alcobar"; "test_case" ] | [ "Alcotest"; "test_case" ] ->
          found := true
      | _ -> ());
  !found

(** Check if fuzz.ml properly delegates to fuzz modules via Fuzz_*.suite instead
    of defining its own tests inline. *)
let check ctx =
  let files = Context.all_files ctx in
  List.concat_map
    (fun filename ->
      let fp = Fpath.v filename in
      if
        Fpath.has_ext ".ml" fp && File.is_in_fuzz_dir fp
        && Fpath.(fp |> rem_ext |> basename) = "fuzz"
      then
        try
          match File_view.parsetree (Context.file_view ctx filename) with
          | None -> []
          | Some structure ->
              if
                defines_own_tests structure
                && not (uses_fuzz_module_suites structure)
              then
                [
                  Issue.v
                    ~loc:
                      (Issue_location.v ~file:filename ~start_line:1
                         ~start_col:0 ~end_line:1 ~end_col:0)
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

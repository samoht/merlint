(** OCamlmerlin parsetree output - focused on syntax-level analysis *)

type t = {
  has_function : bool;
  has_match : bool;
  case_count : int;
  is_data : bool; (* True if primarily data definition *)
  raw_text : string; (* Keep raw text for style/naming analysis *)
}
(** Parsetree analysis result *)

(** Check for pattern matching indicators in parsetree string *)
let has_match_indicators str =
  String.contains str '\n'
  &&
  let lines = String.split_on_char '\n' str in
  List.exists
    (fun line ->
      let trimmed = String.trim line in
      String.starts_with ~prefix:"Pexp_match" trimmed
      || String.starts_with ~prefix:"Pexp_function" trimmed
      || String.starts_with ~prefix:"function" trimmed)
    lines

(** Check for function indicators in parsetree string *)
let has_function_indicators str =
  String.contains str '\n'
  &&
  let lines = String.split_on_char '\n' str in
  List.exists
    (fun line ->
      let trimmed = String.trim line in
      String.starts_with ~prefix:"Pexp_fun" trimmed
      || String.starts_with ~prefix:"Pexp_function" trimmed
      || String.starts_with ~prefix:"value_binding" trimmed)
    lines

(** Count pattern match cases in parsetree string *)
let count_cases_in_string str =
  if String.contains str '\n' then
    let lines = String.split_on_char '\n' str in
    List.fold_left
      (fun acc line ->
        let trimmed = String.trim line in
        if
          String.starts_with ~prefix:"case" trimmed
          || String.starts_with ~prefix:"Pexp_case" trimmed
        then acc + 1
        else acc)
      0 lines
  else 0

(** Check if the parsetree represents primarily data (lists, records, constants)
*)
let is_data_definition str =
  if String.contains str '\n' then
    let lines = String.split_on_char '\n' str in
    let total_lines = List.length lines in
    let data_lines =
      List.fold_left
        (fun acc line ->
          let trimmed = String.trim line in
          if
            String.starts_with ~prefix:"Pexp_constant" trimmed
            || String.starts_with ~prefix:"Pexp_construct" trimmed
            || String.starts_with ~prefix:"Pexp_variant" trimmed
            || String.starts_with ~prefix:"Pexp_tuple" trimmed
            || String.starts_with ~prefix:"Pexp_array" trimmed
            || String.starts_with ~prefix:"Pexp_record" trimmed
            || String.starts_with ~prefix:"Pconst_string" trimmed
            || String.starts_with ~prefix:"Pconst_int" trimmed
            || String.contains trimmed
                 ':' (* List construction - checking for :: *)
          then acc + 1
          else acc)
        0 lines
    in
    (* Consider it data if >80% of lines are data-related *)
    float_of_int data_lines /. float_of_int total_lines > 0.8
  else false

(** Parse parsetree output *)
let of_json json =
  match json with
  | `String str ->
      {
        has_function = has_function_indicators str;
        has_match = has_match_indicators str;
        case_count = count_cases_in_string str;
        is_data = is_data_definition str;
        raw_text = str;
      }
  | _ ->
      {
        has_function = false;
        has_match = false;
        case_count = 0;
        is_data = false;
        raw_text = "";
      }

(** Check if has pattern matching *)
let has_pattern_matching t = t.has_match

(** Check if has function *)
let has_function t = t.has_function

(** Get case count *)
let get_case_count t = t.case_count

(** Check if primarily data definition *)
let is_data_definition t = t.is_data

(** Pretty print *)
let pp ppf t =
  Fmt.pf ppf "{ function: %b; match: %b; cases: %d }" t.has_function t.has_match
    t.case_count

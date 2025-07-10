(** OCamlmerlin parsetree output - focused on syntax-level analysis *)

type t = {
  has_function : bool;
  has_match : bool;
  case_count : int;
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

(** Parse parsetree output *)
let of_json json =
  match json with
  | `String str ->
      {
        has_function = has_function_indicators str;
        has_match = has_match_indicators str;
        case_count = count_cases_in_string str;
        raw_text = str;
      }
  | _ ->
      { has_function = false; has_match = false; case_count = 0; raw_text = "" }

(** Check if has pattern matching *)
let has_pattern_matching t = t.has_match

(** Check if has function *)
let has_function t = t.has_function

(** Get case count *)
let get_case_count t = t.case_count

(** Pretty print *)
let pp ppf t =
  Fmt.pf ppf "{ function: %b; match: %b; cases: %d }" t.has_function t.has_match
    t.case_count

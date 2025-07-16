(** Central registry of all linting rules *)

(* Import all rule modules *)
module E001 = Rules_new.E001
module E100 = Rules_new.E100  
module E351 = Rules_new.E351

(* The complete list of all rules *)
let all_rules = [
  E001.rule;
  E100.rule;
  E351.rule;
  (* TODO: Add remaining rules as they are converted:
     E005.rule;  (* Long Functions *)
     E010.rule;  (* Deep Nesting *)
     E105.rule;  (* Catch-all Exception *)
     E110.rule;  (* Silenced Warning *)
     E200.rule;  (* Outdated Str Module *)
     E205.rule;  (* Printf Instead of Fmt *)
     E300.rule;  (* Bad Variant Naming *)
     E305.rule;  (* Bad Module Naming *)
     E310.rule;  (* Bad Value Naming *)
     E315.rule;  (* Bad Type Naming *)
     E320.rule;  (* Long Identifier Names *)
     E325.rule;  (* Bad Function Naming *)
     E330.rule;  (* Redundant Module Names *)
     E335.rule;  (* Used Underscore Binding *)
     E340.rule;  (* Inline Error Construction *)
     E350.rule;  (* Boolean Blindness *)
     E400.rule;  (* Missing Module Documentation *)
     E405.rule;  (* Missing Value Documentation *)
     E410.rule;  (* Bad Documentation Style *)
     E415.rule;  (* Missing Standard Functions *)
     E500.rule;  (* Missing .ocamlformat File *)
     E505.rule;  (* Missing .mli File *)
     E510.rule;  (* Missing Log Source *)
     E600.rule;  (* Test Module Convention *)
     E605.rule;  (* Missing Test File *)
     E610.rule;  (* Test Without Library *)
     E615.rule;  (* Test Suite Not Included *)
  *)
]

(* Get all file-scoped rules *)
let file_rules = 
  List.filter_map (fun rule ->
    match rule.Rule_new.check with
    | Rule_new.File_check check -> Some (rule, check)
    | _ -> None
  ) all_rules

(* Get all project-scoped rules *)
let project_rules =
  List.filter_map (fun rule ->
    match rule.Rule_new.check with
    | Rule_new.Project_check check -> Some (rule, check)
    | _ -> None
  ) all_rules
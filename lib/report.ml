type t = {
  rule_name : string;
  passed : bool;
  issues : Issue.t list;
  file_count : int;
}

let create ~rule_name ~passed ~issues ~file_count =
  { rule_name; passed; issues; file_count }

let print_status passed = if passed then "✓" else "✗"

let print_color passed text =
  if passed then Printf.sprintf "\027[32m%s\027[0m" text (* green *)
  else Printf.sprintf "\027[31m%s\027[0m" text (* red *)

let print_detailed report =
  let status = print_status report.passed in
  let colored_status = print_color report.passed status in
  Printf.printf "  %s %s (%d issues)\n" colored_status report.rule_name
    (List.length report.issues);
  (* Show detailed issues sorted by priority *)
  let sorted_issues = List.sort Issue.compare report.issues in
  List.iter
    (fun issue ->
      let formatted = Issue.format issue in
      if formatted <> "" then Printf.printf "    %s\n" formatted)
    sorted_issues

let print_summary reports =
  let total_issues =
    List.fold_left (fun acc report -> acc + List.length report.issues) 0 reports
  in
  let all_passed = List.for_all (fun report -> report.passed) reports in

  Printf.printf "\nSummary: %s %d total issues\n"
    (print_color all_passed (print_status all_passed))
    total_issues;

  if all_passed then
    Printf.printf "%s All checks passed!\n" (print_color true "✓")
  else
    Printf.printf "%s Some checks failed. See details above.\n"
      (print_color false "✗")

let get_all_issues reports =
  List.fold_left (fun acc report -> report.issues @ acc) [] reports

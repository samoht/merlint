type t = {
  rule_name : string;
  passed : bool;
  issues : Rule.Run.result list;
  file_count : int;
}

(** Standard functions using polymorphic equality and comparison *)
let equal = ( = )
let compare = compare

let create ~rule_name ~passed ~issues ~file_count =
  { rule_name; passed; issues; file_count }

let print_status passed = if passed then "✓" else "✗"

let pp_color passed ppf text =
  if passed then Fmt.pf ppf "\027[32m%s\027[0m" text (* green *)
  else Fmt.pf ppf "\027[31m%s\027[0m" text (* red *)

let print_color passed text = Fmt.str "%a" (pp_color passed) text

let pp ppf report =
  let status = print_status report.passed in
  Fmt.pf ppf "  %a %s (%d issues)@." (pp_color report.passed) status
    report.rule_name
    (List.length report.issues);
  (* Show detailed issues sorted by priority *)
  let sorted_issues = List.sort Rule.Run.compare report.issues in
  List.iter (fun issue -> Fmt.pf ppf "    %a@." Rule.Run.pp issue) sorted_issues

let pp_summary ppf reports =
  let total_issues =
    List.fold_left (fun acc report -> acc + List.length report.issues) 0 reports
  in
  let all_passed = List.for_all (fun report -> report.passed) reports in
  let rule_count = List.length reports in

  Fmt.pf ppf "@.Summary: %a %d total issues (applied %d rules)@."
    (pp_color all_passed) (print_status all_passed) total_issues rule_count;

  if all_passed then Fmt.pf ppf "%a All checks passed!@." (pp_color true) "✓"
  else
    Fmt.pf ppf "%a Some checks failed. See details above.@." (pp_color false)
      "✗"

let print_summary reports = Fmt.pr "%a" pp_summary reports

let get_all_issues reports =
  List.fold_left (fun acc report -> report.issues @ acc) [] reports

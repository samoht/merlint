(** Legacy format module - all checks have been moved to rules/e500.ml and
    rules/e505.ml *)

let check project_root files =
  let e500_issues = E500.check project_root in
  let e505_issues = E505.check project_root files in
  e500_issues @ e505_issues

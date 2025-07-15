(** Legacy test coverage module - all checks have been moved to rules/*.ml *)

let check_test_coverage dune_describe files =
  let e605_issues =
    try E605.check dune_describe files with Issue.Disabled _ -> []
  in
  let e610_issues =
    try E610.check dune_describe files with Issue.Disabled _ -> []
  in
  e605_issues @ e610_issues

let check_test_runner_completeness dune_describe files =
  try E615.check dune_describe files with Issue.Disabled _ -> []

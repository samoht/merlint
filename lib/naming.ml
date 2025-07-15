(** Legacy naming module - all checks have been moved to rules/*.ml *)

let check ~filename ~outline typedtree =
  let e300_issues = E300.check typedtree in
  let e305_issues = E305.check typedtree in
  let e310_issues =
    try E310.check ~filename ~outline typedtree with Issue.Disabled _ -> []
  in
  let e315_issues = E315.check typedtree in
  let e320_issues = E320.check typedtree in
  let e325_issues = E325.check ~filename ~outline in
  let e330_issues = E330.check ~filename ~outline in
  let e335_issues = E335.check typedtree in
  e300_issues @ e305_issues @ e310_issues @ e315_issues @ e320_issues
  @ e325_issues @ e330_issues @ e335_issues

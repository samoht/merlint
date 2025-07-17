(** Central registry of all linting rules *)

(* The complete list of all rules *)
let all_rules =
  [
    E001.rule;
    E005.rule;
    E010.rule;
    E100.rule;
    E105.rule;
    E110.rule;
    E200.rule;
    E205.rule;
    E300.rule;
    E305.rule;
    E310.rule;
    E315.rule;
    E320.rule;
    E325.rule;
    E330.rule;
    E335.rule;
    E340.rule;
    E350.rule;
    E351.rule;
    E400.rule;
    E405.rule;
    E410.rule;
    E415.rule;
    E500.rule;
    E505.rule;
    E510.rule;
    E600.rule;
    E605.rule;
    E610.rule;
    E615.rule;
    (* TODO: Convert remaining rules to GADT format
  Rule.Pack E005.rule;
  Rule.Pack E010.rule;
  Rule.Pack E100.rule;
  Rule.Pack E105.rule;
  Rule.Pack E110.rule;
  Rule.Pack E200.rule;
  Rule.Pack E205.rule;
  Rule.Pack E300.rule;
  Rule.Pack E305.rule;
  Rule.Pack E310.rule;
  Rule.Pack E315.rule;
  Rule.Pack E320.rule;
  Rule.Pack E325.rule;
  Rule.Pack E330.rule;
  Rule.Pack E335.rule;
  Rule.Pack E340.rule;
  Rule.Pack E350.rule;
  Rule.Pack E351.rule;
  Rule.Pack E400.rule;
  Rule.Pack E405.rule;
  Rule.Pack E410.rule;
  Rule.Pack E415.rule;
  Rule.Pack E500.rule;
  Rule.Pack E505.rule;
  Rule.Pack E510.rule;
  Rule.Pack E600.rule;
  Rule.Pack E605.rule;
  Rule.Pack E610.rule;
  Rule.Pack E615.rule;
  *)
  ]

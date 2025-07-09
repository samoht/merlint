(** Explicit rules processor with visual feedback *)

type rule_result = {
  rule_name : string;
  passed : bool;
  issues : Issue.t list;
  file_count : int;
}

type category_result = {
  category_name : string;
  passed : bool;
  rules : rule_result list;
  total_issues : int;
}

val process : Config.t -> string -> string list -> Issue.t list
(** [process config project_root files] runs all rule categories with visual
    feedback and returns issues *)

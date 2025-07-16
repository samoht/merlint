(** New simplified linting engine *)

open Rule

let src = Logs.Src.create "merlint.engine" ~doc:"Linting engine"
module Log = (val Logs.src_log src : Logs.LOG)

(** Run all file-scoped rules on a single file *)
let check_file ~filter ctx =
  let file_rules = Rules_registry.file_rules in
  
  (* Filter rules based on the filter *)
  let applicable_rules = 
    List.filter (fun (rule, _) ->
      Filter.is_enabled_by_code filter rule.code
    ) file_rules
  in
  
  (* Run each rule's check function *)
  List.concat_map (fun (rule, check) ->
    Log.debug (fun m -> m "Running rule %s on %s" rule.code ctx.Context.filename);
    try
      check ctx
    with exn ->
      Log.err (fun m -> 
        m "Rule %s failed on %s: %s" 
          rule.code ctx.filename (Printexc.to_string exn));
      []
  ) applicable_rules

(** Run all project-scoped rules *)
let check_project ~filter ctx =
  let project_rules = Rules_registry.project_rules in
  
  (* Filter rules based on the filter *)
  let applicable_rules =
    List.filter (fun (rule, _) ->
      Filter.is_enabled_by_code filter rule.code
    ) project_rules
  in
  
  (* Run each rule's check function *)
  List.concat_map (fun (rule, check) ->
    Log.debug (fun m -> m "Running project rule %s" rule.code);
    try
      check ctx
    with exn ->
      Log.err (fun m -> 
        m "Project rule %s failed: %s" 
          rule.code (Printexc.to_string exn));
      []
  ) applicable_rules

(** Run all checks on a project *)
let run ~filter ~exclude project_root =
  Log.info (fun m -> m "Starting analysis of %s" project_root);
  
  (* Create project context *)
  let project_ctx = Context.create_project ~exclude project_root in
  
  (* Run project-scoped rules *)
  let project_issues = check_project ~filter project_ctx in
  
  (* Run file-scoped rules on each file *)
  let file_issues =
    List.concat_map (fun filename ->
      try
        let file_ctx = Context.create_file project_ctx filename in
        check_file ~filter file_ctx
      with exn ->
        Log.err (fun m -> 
          m "Failed to analyze %s: %s" filename (Printexc.to_string exn));
        []
    ) (Context.all_files project_ctx)
  in
  
  (* Combine all issues *)
  let all_issues = project_issues @ file_issues in
  
  (* Sort issues by priority and location *)
  List.sort Issue.compare all_issues
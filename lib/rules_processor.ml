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

let print_status passed = if passed then "✓" else "✗"

let print_color passed text =
  if passed then Printf.sprintf "\027[32m%s\027[0m" text (* green *)
  else Printf.sprintf "\027[31m%s\027[0m" text (* red *)

let print_rule_result (rule : rule_result) =
  let status = print_status rule.passed in
  let colored_status = print_color rule.passed status in
  Printf.printf "  %s %s (%d issues)\n" colored_status rule.rule_name
    (List.length rule.issues);
  (* Show detailed issues *)
  List.iter
    (fun issue ->
      let formatted = Issue.format issue in
      if formatted <> "" then Printf.printf "    %s\n" formatted)
    rule.issues

let print_category_result category =
  let status = print_status category.passed in
  let colored_status = print_color category.passed status in
  Printf.printf "%s %s (%d total issues)\n" colored_status
    category.category_name category.total_issues;
  List.iter print_rule_result category.rules

let process_naming_rules _config files =
  let issues = ref [] in
  let file_count = ref 0 in

  List.iter
    (fun file ->
      incr file_count;
      match Merlin.dump_value "parsetree" file with
      | Ok structure ->
          let file_issues = Naming_rules.check structure in
          issues := file_issues @ !issues
      | Error _ -> ())
    files;

  {
    rule_name = "Naming conventions (snake_case)";
    passed = !issues = [];
    issues = !issues;
    file_count = !file_count;
  }

let process_style_rules _config files =
  let issues = ref [] in
  let file_count = ref 0 in

  List.iter
    (fun file ->
      incr file_count;
      match Merlin.dump_value "parsetree" file with
      | Ok structure ->
          let file_issues = Style_rules.check structure in
          issues := file_issues @ !issues
      | Error _ -> ())
    files;

  {
    rule_name = "Style rules (no Obj.magic, no Str, no catch-all)";
    passed = !issues = [];
    issues = !issues;
    file_count = !file_count;
  }

let process_complexity_rules config files =
  let issues = ref [] in
  let file_count = ref 0 in
  let complexity_config = Config.to_complexity_config config in

  List.iter
    (fun file ->
      incr file_count;
      match Merlin.dump_value "browse" file with
      | Ok browse_value ->
          let file_issues =
            Cyclomatic_complexity.analyze_browse_value complexity_config
              browse_value
          in
          issues := file_issues @ !issues
      | Error _ -> ())
    files;

  {
    rule_name = "Complexity rules (complexity ≤10, length ≤50, nesting ≤3)";
    passed = !issues = [];
    issues = !issues;
    file_count = !file_count;
  }

let process_format_rules _config project_root =
  let issues = Format_rules.check project_root in
  {
    rule_name = "Format rules (.ocamlformat, .mli files)";
    passed = issues = [];
    issues;
    file_count = 1;
    (* project-level *)
  }

let process_documentation_rules _config files =
  let mli_files = List.filter (String.ends_with ~suffix:".mli") files in
  let issues = Doc_rules.check_mli_files mli_files in

  {
    rule_name = "Documentation rules (module docs)";
    passed = issues = [];
    issues;
    file_count = List.length mli_files;
  }

let process config project_root files =
  Printf.printf "Running merlint analysis...\n\n";

  (* Separate ML and MLI files *)
  let ml_files = List.filter (String.ends_with ~suffix:".ml") files in
  let mli_files = List.filter (String.ends_with ~suffix:".mli") files in
  let all_files = ml_files @ mli_files in

  Printf.printf "Analyzing %d files (%d .ml, %d .mli)\n\n"
    (List.length all_files) (List.length ml_files) (List.length mli_files);

  (* Process each category *)
  let naming_result = process_naming_rules config ml_files in
  let style_result = process_style_rules config ml_files in
  let complexity_result = process_complexity_rules config ml_files in
  let format_result = process_format_rules config project_root in
  let doc_result = process_documentation_rules config all_files in

  let categories =
    [
      {
        category_name = "Code Quality";
        passed = complexity_result.passed;
        rules = [ complexity_result ];
        total_issues = List.length complexity_result.issues;
      };
      {
        category_name = "Code Style";
        passed = style_result.passed;
        rules = [ style_result ];
        total_issues = List.length style_result.issues;
      };
      {
        category_name = "Naming Conventions";
        passed = naming_result.passed;
        rules = [ naming_result ];
        total_issues = List.length naming_result.issues;
      };
      {
        category_name = "Documentation";
        passed = doc_result.passed;
        rules = [ doc_result ];
        total_issues = List.length doc_result.issues;
      };
      {
        category_name = "Project Structure";
        passed = format_result.passed;
        rules = [ format_result ];
        total_issues = List.length format_result.issues;
      };
    ]
  in

  (* Print results *)
  List.iter print_category_result categories;

  (* Summary *)
  let total_issues =
    List.fold_left (fun acc cat -> acc + cat.total_issues) 0 categories
  in
  let all_passed = List.for_all (fun cat -> cat.passed) categories in

  Printf.printf "\nSummary: %s %d total issues\n"
    (print_color all_passed (print_status all_passed))
    total_issues;

  if all_passed then
    Printf.printf "%s All checks passed!\n" (print_color true "✓")
  else
    Printf.printf "%s Some checks failed. See details above.\n"
      (print_color false "✗");

  (* Return all issues for traditional output *)
  List.fold_left
    (fun acc cat ->
      List.fold_left (fun acc rule -> rule.issues @ acc) acc cat.rules)
    [] categories

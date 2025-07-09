let find_project_root file =
  (* Walk up directories to find project root (contains dune-project) *)
  let rec find_root dir =
    let dune_project = Filename.concat dir "dune-project" in
    if Sys.file_exists dune_project then dir
    else
      let parent = Filename.dirname dir in
      if parent = dir then dir (* reached filesystem root *)
      else find_root parent
  in
  let file_dir =
    if Sys.is_directory file then file else Filename.dirname file
  in
  find_root file_dir

let analyze_file config file =
  (* Create rules config with actual project root *)
  let project_root = find_project_root file in
  let rules_config = Rules.{ merlint_config = config; project_root } in
  let category_reports = Rules.analyze_project rules_config [ file ] in
  let all_issues =
    List.fold_left
      (fun acc (_category_name, reports) ->
        List.fold_left
          (fun acc report -> report.Report.issues @ acc)
          acc reports)
      [] category_reports
  in
  Ok all_issues

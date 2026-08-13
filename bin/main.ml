open Cmdliner

let logs_src = Logs.Src.create "merlint" ~doc:"Merlint OCaml linter"

module Log = (val Logs.src_log logs_src : Logs.LOG)

let wrap_text ?(indent = 2) text = Console.Width.wrap ~indent 80 text
let normalize_fpath path = Fpath.(path |> normalize |> rem_empty_seg)

let relativize_rendered_issue text =
  let root = normalize_fpath (Fpath.v (Sys.getcwd ())) in
  let root_s = Fpath.to_string root in
  let root_len = String.length root_s in
  let text_len = String.length text in
  let buf = Buffer.create text_len in
  let path_delim = function
    | ' ' | '\t' | '\n' | '\r' | ':' | ',' | ';' | ')' | ']' | '}' | '\'' | '"'
      ->
        true
    | _ -> false
  in
  let rec path_end i =
    if i >= text_len || path_delim text.[i] then i else path_end (i + 1)
  in
  let relativize_path raw =
    let path = normalize_fpath (Fpath.v raw) in
    match Fpath.relativize ~root path with
    | Some rel -> Fpath.to_string rel
    | None -> raw
  in
  let starts_with_root i =
    i + root_len <= text_len && String.sub text i root_len = root_s
  in
  let rec loop i =
    if i >= text_len then ()
    else if starts_with_root i then (
      let j = path_end i in
      Buffer.add_string buf (relativize_path (String.sub text i (j - i)));
      loop j)
    else (
      Buffer.add_char buf text.[i];
      loop (i + 1))
  in
  loop 0;
  Buffer.contents buf

let print_issue_group (error_code, issues) =
  (* Sort issues within each group by location *)
  let sorted_issues = List.sort Merlint.Rule.Run.compare issues in
  match sorted_issues with
  | [] -> ()
  | first_issue :: _ ->
      (* Get title from the first issue *)
      let title = Merlint.Rule.Run.title first_issue in
      let issue_count = List.length sorted_issues in
      let issue_word = if issue_count = 1 then "issue" else "issues" in
      Fmt.pr "  %a %a (%d %s)@."
        (Console.Style.styled
           Console.Style.(fg Console.Color.yellow)
           Fmt.string)
        (Fmt.str "[%s]" error_code)
        (Console.Style.styled Console.Style.bold Fmt.string)
        title issue_count issue_word;

      (* Find the rule to get the hint *)
      let rule_opt =
        List.find_opt
          (fun rule -> Merlint.Rule.code rule = error_code)
          Merlint.Data.all_rules
      in
      (match rule_opt with
      | Some rule ->
          let hint = Merlint.Rule.hint rule in
          let wrapped_hint = wrap_text ~indent:2 hint in
          (* Print each line of the hint in gray *)
          String.split_on_char '\n' wrapped_hint
          |> List.iter (fun line ->
              Fmt.pr "%a@."
                (Console.Style.styled Console.Style.faint Fmt.string)
                line)
      | None -> ());

      (* Print each issue with location and description *)
      if List.length sorted_issues > 0 then
        List.iter
          (fun issue ->
            let text =
              Fmt.kstr relativize_rendered_issue "%a" Merlint.Rule.Run.pp issue
            in
            Fmt.pr "  - %s@." text)
          sorted_issues

(** Group issues by error code *)
let group_issues_by_code issues =
  List.fold_left
    (fun acc issue ->
      let error_code = Merlint.Rule.Run.code issue in
      let current =
        match List.assoc_opt error_code acc with
        | Some issues -> issues
        | None -> []
      in
      (error_code, issue :: current) :: List.remove_assoc error_code acc)
    [] issues

(* An incomplete run exits non-zero even with no findings: a caller that treats
   exit 0 as "this code is clean" would otherwise be told so by a run that
   never read part of it. *)
let print_fix_hints ?(unchecked = 0) all_issues =
  if all_issues <> [] || unchecked > 0 then exit 1

let rule_category_name code =
  match
    List.find_opt (fun r -> Merlint.Rule.code r = code) Merlint.Data.all_rules
  with
  | Some rule -> Merlint.Rule.(category_name (category rule))
  | None -> ""

module Json_report = struct
  module C = Json.Codec

  type position = { line : int; column : int }
  type location = { file : string; start : position; end_ : position }

  type issue = {
    code : string;
    title : string;
    category : string;
    message : string;
    location : location option;
  }

  type exclusion = { rule : string; file : string }

  type t = {
    project_root : string;
    files_analyzed : int;
    rules_applied : int;
    total_issues : int;
    passed : bool;
    issues : issue list;
    excluded : exclusion list;
  }

  let position line column = { line; column }
  let location file start end_ = ({ file; start; end_ } : location)

  let issue code title category message location =
    { code; title; category; message; location }

  let exclusion rule file = ({ rule; file } : exclusion)

  let v project_root files_analyzed rules_applied total_issues passed issues
      excluded =
    {
      project_root;
      files_analyzed;
      rules_applied;
      total_issues;
      passed;
      issues;
      excluded;
    }

  let position_json =
    C.Object.map position
    |> C.Object.member "line" C.int ~enc:(fun (t : position) -> t.line)
    |> C.Object.member "column" C.int ~enc:(fun (t : position) -> t.column)
    |> C.Object.seal

  let location_json =
    C.Object.map location
    |> C.Object.member "file" C.string ~enc:(fun (t : location) -> t.file)
    |> C.Object.member "start" position_json ~enc:(fun (t : location) ->
        t.start)
    |> C.Object.member "end" position_json ~enc:(fun (t : location) -> t.end_)
    |> C.Object.seal

  let issue_json =
    C.Object.map issue
    |> C.Object.member "code" C.string ~enc:(fun (t : issue) -> t.code)
    |> C.Object.member "title" C.string ~enc:(fun (t : issue) -> t.title)
    |> C.Object.member "category" C.string ~enc:(fun (t : issue) -> t.category)
    |> C.Object.member "message" C.string ~enc:(fun (t : issue) -> t.message)
    |> C.Object.member "location" (C.option location_json)
         ~enc:(fun (t : issue) -> t.location)
    |> C.Object.seal

  let exclusion_json =
    C.Object.map exclusion
    |> C.Object.member "rule" C.string ~enc:(fun (t : exclusion) -> t.rule)
    |> C.Object.member "file" C.string ~enc:(fun (t : exclusion) -> t.file)
    |> C.Object.seal

  let json =
    C.Object.map v
    |> C.Object.member "project_root" C.string ~enc:(fun (t : t) ->
        t.project_root)
    |> C.Object.member "files_analyzed" C.int ~enc:(fun (t : t) ->
        t.files_analyzed)
    |> C.Object.member "rules_applied" C.int ~enc:(fun (t : t) ->
        t.rules_applied)
    |> C.Object.member "total_issues" C.int ~enc:(fun (t : t) -> t.total_issues)
    |> C.Object.member "passed" C.bool ~enc:(fun (t : t) -> t.passed)
    |> C.Object.member "issues" (C.list issue_json) ~enc:(fun (t : t) ->
        t.issues)
    |> C.Object.member "excluded" (C.list exclusion_json) ~enc:(fun (t : t) ->
        t.excluded)
    |> C.Object.seal

  let position_of_location (pos : Merlint.Location.position) =
    position pos.line pos.col

  let location_of_merlint (loc : Merlint.Location.t) =
    let file =
      Fpath.v loc.file |> Merlint.Loc.current_dir_relative |> Fpath.to_string
    in
    location file
      (position_of_location loc.start)
      (position_of_location loc.end_)

  let issue_of_run run =
    let code = Merlint.Rule.Run.code run in
    issue code
      (Merlint.Rule.Run.title run)
      (rule_category_name code)
      (Merlint.Rule.Run.message run)
      (Option.map location_of_merlint (Merlint.Rule.Run.location run))

  let exclusion_of_engine (e : Merlint.Engine.exclusion_stats) =
    exclusion e.rule e.file

  let v ~project_root ~files_analyzed ~enabled_rule_count ~excluded issues =
    let issues =
      issues |> List.sort Merlint.Rule.Run.compare |> List.map issue_of_run
    in
    let total_issues = List.length issues in
    v project_root files_analyzed enabled_rule_count total_issues
      (total_issues = 0) issues
      (List.map exclusion_of_engine excluded)

  let print t = Fmt.pr "%s@." (Json.to_string json t)
end

let print_json_report ~project_root ~files_analyzed ~enabled_rule_count
    ~excluded issues =
  Json_report.v ~project_root ~files_analyzed ~enabled_rule_count ~excluded
    issues
  |> Json_report.print

(* Group issues by category for visual reporting *)
let group_issues_by_category all_issues =
  let all_categories =
    [
      "Code Quality";
      "Code Style";
      "Naming Conventions";
      "Documentation";
      "Project Structure";
      "Test Quality";
      "Interop Testing";
      "Code Generation";
    ]
  in
  List.map
    (fun category_name ->
      let category_issues =
        List.filter
          (fun issue ->
            let code = Merlint.Rule.Run.code issue in
            (* Find the rule to get its category *)
            match
              List.find_opt
                (fun r -> Merlint.Rule.code r = code)
                Merlint.Data.all_rules
            with
            | Some rule ->
                let category = Merlint.Rule.category rule in
                Merlint.Rule.category_name category = category_name
            | None -> false)
          all_issues
      in
      (category_name, category_issues))
    all_categories

(* Print issues grouped by category *)
let print_categorized_issues issues_by_category =
  List.iter
    (fun (category_name, issues) ->
      let total_issues = List.length issues in
      let category_passed = total_issues = 0 in

      Fmt.pr "%s %s (%d total issues)@."
        (Merlint.Report.print_color category_passed
           (Merlint.Report.print_status category_passed))
        category_name total_issues;

      (* Group by error code and print *)
      if total_issues > 0 then
        let grouped_issues = group_issues_by_code issues in
        let sorted_groups =
          List.sort (fun (a, _) (b, _) -> String.compare a b) grouped_issues
        in
        List.iter print_issue_group sorted_groups)
    issues_by_category

(* Get enabled rules based on filter *)
let enabled_rules rule_filter =
  match rule_filter with
  | Some filter ->
      List.filter
        (fun rule ->
          Merlint.Filter.is_enabled_by_code filter (Merlint.Rule.code rule))
        Merlint.Data.all_rules
  | None -> Merlint.Data.all_rules

(* Title of the rule with the given code, or the code itself if unknown. *)
let rule_title_of_code code =
  match
    List.find_opt (fun r -> Merlint.Rule.code r = code) Merlint.Data.all_rules
  with
  | Some rule -> Merlint.Rule.title rule
  | None -> code

(* Format the per-code breakdown into a single string. *)
let format_breakdown breakdown =
  if List.length breakdown <= 2 then String.concat ", " breakdown
  else
    let first_two = List.filteri (fun i _ -> i < 2) breakdown in
    Fmt.str "%s, ..." (String.concat ", " first_two)

(* Build a summary row for one category, or None when there are no issues. *)
let summary_row (category_name, issues) =
  let count = List.length issues in
  if count = 0 then None
  else
    let by_code = group_issues_by_code issues in
    let breakdown =
      List.map
        (fun (code, code_issues) ->
          let n = List.length code_issues in
          let title = rule_title_of_code code in
          Fmt.str "%d %s" n (String.lowercase_ascii title))
        by_code
    in
    let details = format_breakdown breakdown in
    Some [ category_name; Fmt.str "%d (%s)" count details ]

(* Print summary table by category *)
let print_summary_table issues_by_category =
  let rows = List.filter_map summary_row issues_by_category in
  if rows <> [] then (
    Fmt.pr "@.";
    let term_width = 80 in
    (* Account for borders and padding: 2 borders + 2 middle + 4 padding = 8 *)
    let available = term_width - 8 in
    let cat_width = min 20 (available / 4) in
    let issues_width = available - cat_width in
    let columns =
      [
        Console.Table.column ~align:`Left ~max_width:cat_width "Category";
        Console.Table.column ~align:`Left ~max_width:issues_width "Issues";
      ]
    in
    let table =
      Console.Table.of_string_rows ~border:Console.Border.rounded columns rows
    in
    Fmt.pr "%a@." Console.Table.pp table)

(* Print summary and status *)
(* A run whose typedtree-backed rules could not read an artefact examined less
   than it was asked to. Saying only "0 issues" would report that as the same
   outcome as a complete run, so the count of unchecked files goes in the
   summary line itself, where a caller reading the last line of output sees
   it. *)
let print_summary ?(unchecked = 0) all_issues enabled_rule_count =
  let total_issues = List.length all_issues in
  let complete = unchecked = 0 in
  let all_passed = total_issues = 0 && complete in
  let rule_word = if enabled_rule_count = 1 then "rule" else "rules" in

  Fmt.pr "@.Summary: %s %d total %s (applied %d %s%s)@."
    (Merlint.Report.print_color all_passed
       (Merlint.Report.print_status all_passed))
    total_issues
    (if total_issues = 1 then "issue" else "issues")
    enabled_rule_count rule_word
    (if complete then ""
     else
       Fmt.str ", %d file%s unchecked" unchecked
         (if unchecked = 1 then "" else "s"));

  if all_passed then
    Fmt.pr "%s All checks passed!@." (Merlint.Report.print_color true "✓")
  else if total_issues = 0 then
    Fmt.pr
      "%s No issues found, but %d file%s could not be checked: the .cmt/.cmti \
       was missing or out of date, so the rules that read a typedtree did not \
       run on %s. Re-run with -v to name %s.@."
      (Merlint.Report.print_color false "✗")
      unchecked
      (if unchecked = 1 then "" else "s")
      (if unchecked = 1 then "it" else "them")
      (if unchecked = 1 then "it" else "them")
  else begin
    Fmt.pr "%s Some checks failed. See details above.@."
      (Merlint.Report.print_color false "✗");
    let codes =
      List.fold_left (fun acc i -> Merlint.Rule.Run.code i :: acc) [] all_issues
      |> List.sort_uniq String.compare
    in
    let sample = match codes with [] -> "E100" | c :: _ -> c in
    Fmt.pr
      "  Run `merlint help %s` for the rule's description, hint, and good/bad \
       examples.@."
      sample
  end

let run_engine ?domain_mgr ~load_file ?profiling ~bail ~exclude
    ~include_vendored rule_filter analyze_set analyze_roots build_index
    project_root =
  match rule_filter with
  | Some filter ->
      Merlint.Engine.run ?domain_mgr ~load_file ~filter ?analyze_set
        ?analyze_roots ~index:build_index ?profiling ~bail ~exclude
        ~include_vendored project_root
  | None -> (
      match Merlint.Filter.parse "all" with
      | Ok filter ->
          Merlint.Engine.run ?domain_mgr ~load_file ~filter ?analyze_set
            ?analyze_roots ~index:build_index ?profiling ~bail ~exclude
            ~include_vendored project_root
      | Error _ ->
          {
            Merlint.Engine.issues = [];
            excluded = [];
            files_analyzed = 0;
            unchecked_files = [];
          })

let print_exclusion_stats all_excluded =
  if all_excluded <> [] then begin
    let n = List.length all_excluded in
    let by_rule = Hashtbl.create 16 in
    List.iter
      (fun (e : Merlint.Engine.exclusion_stats) ->
        let prev = try Hashtbl.find by_rule e.rule with Not_found -> 0 in
        Hashtbl.replace by_rule e.rule (prev + 1))
      all_excluded;
    Fmt.pr "@[<v>%a %d issues suppressed by merlint.toml exclusions:@,"
      Fmt.(styled `Yellow string)
      "!" n;
    Hashtbl.iter
      (fun rule count -> Fmt.pr "  [%s] %d suppressed@," rule count)
      by_rule;
    Fmt.pr "@]@."
  end

let run_analysis ?domain_mgr ~load_file ~json_output project_root analyze_set
    analyze_roots
    (build_index : ?pool:Eio.Executor_pool.t -> unit -> Project_index.t)
    rule_filter show_profile ~bail ~exclude ~include_vendored =
  let profiling_state =
    if show_profile then Some (Merlint.Profiling.v ()) else None
  in
  let files_count = Option.map List.length analyze_set in
  Log.info (fun m ->
      m "Analysing %s files"
        (match files_count with None -> "all" | Some n -> string_of_int n));
  let {
    Merlint.Engine.issues = all_issues;
    excluded = all_excluded;
    files_analyzed;
    unchecked_files;
  } =
    run_engine ?domain_mgr ~load_file ?profiling:profiling_state rule_filter
      ~bail ~exclude ~include_vendored analyze_set analyze_roots build_index
      project_root
  in
  let enabled_rules = enabled_rules rule_filter in
  let enabled_rule_count = List.length enabled_rules in
  if json_output then
    print_json_report ~project_root ~files_analyzed ~enabled_rule_count
      ~excluded:all_excluded all_issues
  else (
    (match files_analyzed with
    | 0 -> Fmt.pr "Running merlint analysis...@.@."
    | n -> Fmt.pr "Running merlint analysis...@.@.Analyzing %d files@.@." n);
    print_exclusion_stats all_excluded;

    (* Group issues by category for reporting *)
    let issues_by_category = group_issues_by_category all_issues in

    (* Process each category *)
    ignore project_root;
    print_categorized_issues issues_by_category;

    (* Print summary table *)
    print_summary_table issues_by_category;

    (* Print custom summary *)
    print_summary
      ~unchecked:(List.length unchecked_files)
      all_issues enabled_rule_count;

    (* Print profiling summary if enabled *)
    match profiling_state with
    | Some state ->
        Merlint.Profiling.print_summary state;
        Merlint.Profiling.print_rule_summary state;
        Merlint.Profiling.print_file_summary state
    | None -> ());

  print_fix_hints ~unchecked:(List.length unchecked_files) all_issues

let ensure_project_built ~path mgr =
  match Merlint.Build.ensure_project_built ~path mgr with
  | Ok () -> ()
  | Error msg ->
      Fmt.epr "Warning: %s@." msg;
      Fmt.epr "Function type analysis may not work properly.@.";
      Fmt.epr "Continuing with analysis...@."

let refresh_stale_cmt_targets ~path ~files mgr =
  match Merlint.Build.refresh_stale_cmt_targets ~path ~files mgr with
  | Ok () -> ()
  | Error msg ->
      Fmt.epr "Warning: %s@." msg;
      Fmt.epr "Some typedtree-backed rules may be skipped.@.";
      Fmt.epr "Continuing with analysis...@."

let is_ocaml_source path =
  Filename.check_suffix path ".ml" || Filename.check_suffix path ".mli"

let classify_path path =
  if not (Sys.file_exists path) then `Missing
  else if Sys.is_directory path then `Dir
  else if is_ocaml_source path then `File
  else `Other

let resolve_cli_path raw =
  let p = Fpath.v raw in
  if Fpath.is_abs p then Fpath.normalize p
  else Fpath.normalize Fpath.(v (Sys.getcwd ()) // p)

(* Narrow [analyze_set] from CLI arguments. Bare-file arguments enumerate
   the files to analyse directly; directory and no-arg invocations leave
   [analyze_set = None], and the engine walks [Project_index.source_files]
   instead. *)
let analyze_set_of_files files =
  match files with
  | [] -> None
  | _ ->
      let explicit =
        List.filter_map
          (fun p ->
            match classify_path p with
            | `File -> Some (resolve_cli_path p)
            | `Dir | `Other -> None
            | `Missing ->
                Fmt.epr "Warning: %s does not exist@." p;
                None)
          files
      in
      if explicit = [] then None else Some explicit

let analyze_roots_of_files files =
  match
    List.filter_map
      (fun p ->
        match classify_path p with
        | `Dir -> Some (resolve_cli_path p)
        | `File | `Other | `Missing -> None)
      files
  with
  | [] -> None
  | roots -> Some roots

let load_file_via_eio fs filename = Eio.Path.load Eio.Path.(fs / filename)

let project_root_of_files = function
  | file :: _ -> Merlint.Project.root file
  | [] -> Merlint.Project.root "."

(* A checkout whose dependencies resolve only inside a larger workspace is
   built there, so that is where its typedtree artefacts are and where a build
   can be asked for. Analysed on its own it has no artefact for any of its
   files, and every rule that reads a typedtree is skipped. When its
   merlint.toml names that workspace, move the whole analysis to the paths the
   workspace knows these files by: from there on this is an ordinary run
   rooted at the workspace. *)
let redirect_analysis files =
  let anchor = match files with file :: _ -> file | [] -> "." in
  match Merlint.Project.workspace_link anchor with
  | Error msg ->
      Fmt.epr "Error: %s@." msg;
      exit 1
  | Ok None -> None
  | Ok (Some { Merlint.Project.checkout; workspace; path }) ->
      let into_workspace file =
        let file = resolve_cli_path file in
        if Fpath.equal (Fpath.to_dir_path file) checkout then
          Fpath.to_string path
        else
          match Fpath.rem_prefix checkout file with
          | Some rel -> Fpath.(to_string (path // rel))
          | None -> Fpath.to_string file
      in
      let files =
        match files with
        | [] -> [ Fpath.to_string path ]
        | files -> List.map into_workspace files
      in
      Some (files, Fpath.to_string workspace)

let maybe_build_project mgr ~project_root ~analyze_set ~analyze_roots ~index
    ~build =
  if build then (
    Log.info (fun m -> m "Building project...");
    (* Freeze the analysis set before starting Dune. A source added while the
       build is running cannot have been part of that build; discovering it
       afterwards would make this run reject an artefact it never asked Dune to
       produce. The following run will include and build the new source. *)
    let frozen_index = Lazy.force index in
    let files =
      match (analyze_set, analyze_roots) with
      | Some files, None -> files
      | None, roots -> Project_index.source_files ?roots frozen_index
      | Some files, Some roots ->
          Project_index.source_files ~roots frozen_index
          |> List.rev_append files
          |> List.sort_uniq Fpath.compare
    in
    ensure_project_built ~path:project_root mgr;
    refresh_stale_cmt_targets ~path:project_root ~files mgr;
    Log.info (fun m -> m "Build done."))

let monorepo_for_index project_root =
  Fpath.(v project_root |> normalize |> rem_empty_seg)

let resolve_index_root raw =
  let p = Fpath.v raw in
  if Fpath.is_abs p then Fpath.normalize p
  else Fpath.normalize Fpath.(v (Sys.getcwd ()) // p)

let index_roots_of_files = function
  | [] -> None
  | xs -> Some (List.map resolve_index_root xs)

let build_project_index ~fs ~monorepo ?roots ?pool ?installed () =
  let t0 = Unix.gettimeofday () in
  let idx = Project_index.build ?pool ?roots ?installed ~fs ~monorepo () in
  Log.info (fun m ->
      m "Project_index.build: %.0f ms" ((Unix.gettimeofday () -. t0) *. 1000.0));
  idx

(* The installed-package roots ([_opam/lib], [_build/install]) are scanned only
   to resolve external library uses to their providing package, which only the
   dependency-hygiene rules need. When one of them runs, scan just the installed
   packages those uses reference; otherwise skip the roots entirely. *)
let installed_index_mode rule_filter =
  let dep_rule_enabled =
    match rule_filter with
    | None -> true
    | Some filter ->
        List.exists
          (Merlint.Filter.is_enabled_by_code filter)
          [ "E941"; "E943"; "E944"; "E956" ]
  in
  if dep_rule_enabled then Project_index.Referenced else Project_index.Skip

let analyze_files mgr fs domain_mgr ?(exclude_patterns = []) ?rule_filter
    ?(show_profile = false) ?(build = false) ?(bail = false)
    ?(include_vendored = false) ?(json_output = false) files =
  let load_file = load_file_via_eio fs in
  let files, project_root =
    match redirect_analysis files with
    | Some (files, workspace) -> (files, workspace)
    | None -> (files, project_root_of_files files)
  in
  Log.info (fun m -> m "Dune root: %s (cwd: %s)" project_root (Sys.getcwd ()));
  if not json_output then Fmt.pr "Dune root: %s@." project_root;
  Log.info (fun m -> m "Scanning project structure...");
  let analyze_set = analyze_set_of_files files in
  let analyze_roots = analyze_roots_of_files files in
  let monorepo = monorepo_for_index project_root in
  let index_roots = index_roots_of_files files in
  let installed = installed_index_mode rule_filter in
  let build_index ?pool () =
    build_project_index ~fs ~monorepo ?roots:index_roots ~installed ?pool ()
  in
  let lazy_index = lazy (build_index ()) in
  maybe_build_project mgr ~project_root ~analyze_set ~analyze_roots
    ~index:lazy_index ~build;
  let analysis_index ?pool () =
    if build then Lazy.force lazy_index else build_index ?pool ()
  in
  run_analysis ~domain_mgr ~load_file ~json_output project_root analyze_set
    analyze_roots analysis_index rule_filter show_profile ~bail
    ~exclude:exclude_patterns ~include_vendored

let files =
  let doc =
    "OCaml source files or directories to analyze. If none specified, analyzes \
     all .ml and .mli files in the current dune project."
  in
  Arg.(value & pos_all string [] & info [] ~docv:"FILE|DIR" ~doc)

let exclude_flag =
  let doc =
    "Exclude files matching these patterns (can be used multiple times). \
     Supports simple glob patterns with * and path matching."
  in
  Arg.(value & opt_all string [] & info [ "exclude"; "e" ] ~docv:"PATTERN" ~doc)

let rules_flag =
  let doc =
    "Filter rules to enable/disable specific checks. Simple format: --rules \
     all-E110-E205 (all except E110 and E205), --rules E300+E305 (only these \
     two), --rules all-100..199 (all except codes 100-199). No quotes needed!"
  in
  Arg.(value & opt (some string) None & info [ "rules"; "r" ] ~docv:"SPEC" ~doc)

let profile_flag =
  let doc = "Show profiling statistics for analysis operations" in
  Arg.(value & flag & info [ "profile"; "p" ] ~doc)

let bail_flag =
  let doc = "Report only the first issue in normal report order." in
  Arg.(value & flag & info [ "bail" ] ~doc)

let include_vendored_flag =
  let doc =
    "Also analyze sources under Dune $(b,(vendored_dirs ...)) subtrees, which \
     are skipped by default."
  in
  Arg.(value & flag & info [ "include-vendored" ] ~doc)

let show_config_flag =
  let doc =
    "Show the loaded configuration and exit (useful for debugging merlint.toml \
     files)"
  in
  Arg.(value & flag & info [ "show-config" ] ~doc)

let no_build_flag =
  let doc =
    "Deprecated no-op. Merlint does not build by default; pass --build to run \
     'dune build @check' before analysis."
  in
  Term.(const ignore $ Arg.(value & flag & info [ "no-build" ] ~doc))

let build_flag =
  let doc =
    "Run 'dune build @check' and refresh stale .cmt/.cmti artifacts before \
     analysis."
  in
  Arg.(value & flag & info [ "build" ] ~doc)

let show_configuration files =
  let path = match files with [] -> Sys.getcwd () | path :: _ -> path in
  let project_root = Merlint.Project.root path in
  let workspace_root = Merlint.Project.workspace_root path in
  let config_files = Merlint.Project.config_files path in
  let config = Merlint.Config.load path in
  Fmt.pr "=== Merlint Configuration ===@.";
  Fmt.pr "Project root: %s@." project_root;
  Fmt.pr "Workspace root: %s@." workspace_root;
  (match config_files with
  | [] -> Fmt.pr "Config files: (none, using defaults)@."
  | files ->
      Fmt.pr "Config files:@.";
      List.iter (fun f -> Fmt.pr "  %s@." f) files);
  Fmt.pr "@.Settings:@.";
  Fmt.pr "  max-complexity: %d@." config.max_complexity;
  Fmt.pr "  max-function-length: %d@." config.max_function_length;
  Fmt.pr "  max-nesting: %d@." config.max_nesting;
  Fmt.pr "  exempt-data-definitions: %b@." config.exempt_data_definitions;
  Fmt.pr "  max-underscores-in-name: %d@." config.max_underscores_in_name;
  Fmt.pr "  min-name-length-underscore: %d@." config.min_name_length_underscore;
  Fmt.pr "  allow-obj-magic: %b@." config.allow_obj_magic;
  Fmt.pr "  allow-str-module: %b@." config.allow_str_module;
  Fmt.pr "  allow-catch-all-exceptions: %b@." config.allow_catch_all_exceptions;
  Fmt.pr "  require-ocamlformat-file: %b@." config.require_ocamlformat_file;
  Fmt.pr "  require-mli-files: %b@." config.require_mli_files;
  Fmt.pr "@.Exclusions:@.";
  if Merlint.Rule_config.equal config.exclusions Merlint.Rule_config.empty then
    Fmt.pr "  (none)@."
  else Fmt.pr "  %a@." Merlint.Rule_config.pp config.exclusions;
  Stdlib.exit 0

let parse_rule_filter rules_spec =
  match rules_spec with
  | None -> None
  | Some spec -> (
      match Merlint.Filter.parse spec with
      | Ok filter -> Some filter
      | Error msg ->
          Log.err (fun m -> m "Invalid rules specification: %s" msg);
          Stdlib.exit 1)

let main exclude_patterns rules_spec ~show_profile ~show_config ~build ~bail
    ~include_vendored files () =
  if show_config then show_configuration files
  else
    let rule_filter = parse_rule_filter rules_spec in
    Eio_main.run @@ fun env ->
    let clock = Eio.Stdenv.clock env in
    Console_eio.run ~clock @@ fun _display ->
    let mgr = Eio.Stdenv.process_mgr env in
    let fs = Eio.Stdenv.fs env in
    let domain_mgr = Eio.Stdenv.domain_mgr env in
    let json_output = Observe.json_enabled () in
    analyze_files mgr fs domain_mgr ~exclude_patterns ?rule_filter ~show_profile
      ~build ~bail ~include_vendored ~json_output files

let analyze_term =
  let json_log_reporter ~app:_ ~base:_ () = Observe.reporter () in
  Term.(
    const (fun e r p bail c b vendored () f u ->
        main e r ~show_profile:p ~show_config:c ~build:b ~bail
          ~include_vendored:vendored f u)
    $ exclude_flag $ rules_flag $ profile_flag $ bail_flag $ show_config_flag
    $ build_flag $ include_vendored_flag $ no_build_flag $ files
    $ Observe.setup ~json_reporter:(Some json_log_reporter) "merlint")

let scan =
  let doc = "Scan OCaml code for style issues" in
  let man =
    [
      `S Manpage.s_description;
      `P
        "$(tname) scans OCaml source files and reports issues with modern \
         OCaml coding conventions.";
      `P
        "It uses Merlin to parse the OCaml AST and checks for naming \
         conventions, complexity, documentation, and code style issues.";
      `P
        "If no files or directories are specified, it scans all .ml and .mli \
         files in the current dune project (searching upward for \
         dune-project).";
      `P
        "$(tname) respects Dune's $(b,(vendored_dirs ...)) stanzas and skips \
         those vendored source subtrees automatically.";
      `P "Run $(b,merlint help config) for the configuration file format.";
    ]
  in
  let info = Cmd.info "scan" ~version:Version.string ~doc ~man in
  Cmd.v info analyze_term

let cmd =
  let doc = "Analyze OCaml code for style issues" in
  let man =
    [
      `S Manpage.s_description;
      `P
        "$(mname) scans OCaml source files and reports issues with modern \
         coding conventions: complexity, naming, documentation, style, project \
         structure, and test discipline.";
      `P
        "$(mname) respects Dune's $(b,(vendored_dirs ...)) stanzas and skips \
         those vendored source subtrees automatically.";
      `S "RULES";
      `P
        "Each issue is tagged with an error code such as $(b,E100). To see the \
         description, hint, and good/bad examples for a rule, run:";
      `Pre "  $(mname) help E100";
      `P
        "The same renderer powers the generated HTML reference and Markdown \
         style guide via $(b,merlint help --all --format=html|md -o FILE).";
      `S Manpage.s_examples;
      `P "Scan the current project:";
      `Pre "  $(mname)";
      `P "Browse rule E100:";
      `Pre "  $(mname) help E100";
      `P "Show the configuration reference:";
      `Pre "  $(mname) help config";
      `S Manpage.s_see_also;
      `P "$(mname)-scan(1), $(mname)-config(1), $(mname)-help(1)";
    ]
  in
  let info = Cmd.info "merlint" ~version:Version.string ~doc ~man in
  Cmd.group ~default:analyze_term info [ scan; Cmd_config.cmd; Cmd_help.cmd ]

(* Cmdliner's [Cmd.group] only invokes the default term when argv has zero
   positionals; with any other first positional it expects a subcommand name
   and errors otherwise. [merlint .] should run [scan] on the current
   directory, so when argv.(1) isn't a known subcommand or a help/version
   flag, splice [scan] in front. *)
let known_first_args = [ "scan"; "config"; "help" ]

let rewrite_argv argv =
  match Array.to_list argv with
  | prog :: arg :: rest
    when (not (List.mem arg known_first_args))
         && (String.length arg = 0 || arg.[0] <> '-') ->
      Array.of_list (prog :: "scan" :: arg :: rest)
  | _ -> argv

let () = Stdlib.exit (Cmd.eval ~argv:(rewrite_argv Sys.argv) cmd)

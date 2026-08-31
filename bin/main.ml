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

(* Merlint_doc.Exit_status owns the mask, its reserved-value check and the
   manual entry that publishes it; the comment there says why each bit exists.
   The status is read here and nowhere else. *)
let exit_with_status ~unchecked ~skipped ~failed all_issues =
  match
    Merlint_doc.Exit_status.of_run ~findings:(List.length all_issues) ~unchecked
      ~skipped ~failed
  with
  | 0 -> ()
  | status -> exit status

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

  type failure = {
    rule : string option;
    file : string option;
    kind : string;
    error : string;
  }

  type build_failure = { kind : string; error : string }

  type t = {
    project_root : string;
    files_analyzed : int;
    rules_applied : int;
    total_issues : int;
    unchecked : int;
    unchecked_files : string list;
    unclaimed_files : string list;
    skipped_paths : string list;
    failed_checks : failure list;
    build_failure : build_failure option;
    passed : bool;
    issues : issue list;
    excluded : exclusion list;
  }

  let position line column = { line; column }
  let location file start end_ = ({ file; start; end_ } : location)

  let issue code title category message location =
    { code; title; category; message; location }

  let exclusion rule file = ({ rule; file } : exclusion)
  let failure rule file kind error = ({ rule; file; kind; error } : failure)
  let build_failure kind error = ({ kind; error } : build_failure)

  let v project_root files_analyzed rules_applied total_issues unchecked
      unchecked_files unclaimed_files skipped_paths failed_checks build_failure
      passed issues excluded =
    {
      project_root;
      files_analyzed;
      rules_applied;
      total_issues;
      unchecked;
      unchecked_files;
      unclaimed_files;
      skipped_paths;
      failed_checks;
      build_failure;
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

  let failure_json =
    C.Object.map failure
    |> C.Object.member "rule" (C.option C.string) ~enc:(fun (t : failure) ->
        t.rule)
    |> C.Object.member "file" (C.option C.string) ~enc:(fun (t : failure) ->
        t.file)
    |> C.Object.member "kind" C.string ~enc:(fun (t : failure) -> t.kind)
    |> C.Object.member "error" C.string ~enc:(fun (t : failure) -> t.error)
    |> C.Object.seal

  let build_failure_json =
    C.Object.map build_failure
    |> C.Object.member "kind" C.string ~enc:(fun (t : build_failure) -> t.kind)
    |> C.Object.member "error" C.string ~enc:(fun (t : build_failure) ->
        t.error)
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
    |> C.Object.member "unchecked" C.int ~enc:(fun (t : t) -> t.unchecked)
    |> C.Object.member "unchecked_files" (C.list C.string) ~enc:(fun (t : t) ->
        t.unchecked_files)
    |> C.Object.member "unclaimed_files" (C.list C.string) ~enc:(fun (t : t) ->
        t.unclaimed_files)
    |> C.Object.member "skipped_paths" (C.list C.string) ~enc:(fun (t : t) ->
        t.skipped_paths)
    |> C.Object.member "failed_checks" (C.list failure_json)
         ~enc:(fun (t : t) -> t.failed_checks)
    |> C.Object.member "build_failure" (C.option build_failure_json)
         ~enc:(fun (t : t) -> t.build_failure)
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

  let report_path file =
    Fpath.v file |> Merlint.Loc.current_dir_relative |> Fpath.to_string

  let failure_of_engine (f : Merlint.Engine.failure) =
    let kind =
      match f.kind with
      | Merlint.Engine.Crashed -> "crashed"
      | Merlint.Engine.Unevaluated -> "unevaluated"
    in
    failure f.rule (Option.map report_path f.file) kind f.error

  (* A run that examined less than it was asked to reports a non-zero status for
     it, and the document says so too, so a caller reading the JSON and a caller
     reading the exit status never disagree. It names the files as well as
     counting them: a caller whose question is "what did this run not look at"
     reads the answer here instead of rediscovering it a directory at a time.
     [unchecked] counts the two sets a build or an edit fixes; [skipped_paths]
     is apart from them because nothing merlint does fixes it;
     [failed_checks] is apart from both because nothing in the tree it was
     reading caused it, and it counts checks rather than files: a [crashed]
     member is a defect in merlint, an [unevaluated] one names the fact a rule
     needed and this run's project index does not hold. The text report counts
     these and stops; this is where the whole set is named. [build_failure] is
     apart from all four: no verdict was computed at all, so its report has
     zero counts and names the failed instrument instead of putting every
     source under [unchecked_files]. [passed] is false while any of the four
     has a member, and in every refused report. *)
  let of_analysis ~project_root ~files_analyzed ~rules_applied ~unchecked_files
      ~unclaimed_files ~skipped ~failed ~excluded issues =
    let issues =
      issues |> List.sort Merlint.Rule.Run.compare |> List.map issue_of_run
    in
    let total_issues = List.length issues in
    let unchecked = List.length unchecked_files + List.length unclaimed_files in
    v project_root files_analyzed rules_applied total_issues unchecked
      (List.map report_path unchecked_files)
      (List.map report_path unclaimed_files)
      (List.map report_path skipped)
      (List.map failure_of_engine failed)
      None
      (total_issues = 0 && unchecked = 0 && skipped = [] && failed = [])
      issues
      (List.map exclusion_of_engine excluded)

  (* Every refused run reports the same document: no counts, and
     [build_failure] naming the instrument that failed. [kind] is the
     machine-readable half, so a caller tells "your tree does not build" from
     "merlint does not work" by reading a field rather than the prose. *)
  let refused ~project_root ~kind ~error =
    v project_root 0 0 0 0 [] [] [] []
      (Some (build_failure kind error))
      false [] []

  let print t = Fmt.pr "%s@." (Json.to_string json t)
end

let print_json_report ~project_root ~files_analyzed ~rules_applied
    ~unchecked_files ~unclaimed_files ~skipped ~failed ~excluded issues =
  Json_report.of_analysis ~project_root ~files_analyzed ~rules_applied
    ~unchecked_files ~unclaimed_files ~skipped ~failed ~excluded issues
  |> Json_report.print

let build_failure_kind = function
  | Merlint.Build.Contended _ -> "contended"
  | Merlint.Build.Broken _ -> "broken"
  | Merlint.Build.Unscoped _ -> "unscoped"

let print_json_refusal ~project_root reason =
  Json_report.refused ~project_root
    ~kind:(build_failure_kind reason)
    ~error:(Merlint.Build.message reason)
  |> Json_report.print

(* A refusal whose cause is merlint rather than the tree it was pointed at. It
   ends where the others end -- nothing analysed, status 4 -- because a caller
   acts on that identically: it stops and reads the text. The distinction it
   does act on is in the document, under [kind], which is the field built to
   carry it. *)
let refuse_internal ~json_output ~project_root error =
  if json_output then
    Json_report.refused ~project_root ~kind:"internal" ~error
    |> Json_report.print
  else begin
    Fmt.epr "merlint: %s@." error;
    Fmt.epr
      "merlint: nothing was analysed, because the fault is merlint's and any \
       verdict it printed would be one this defect produced.@."
  end;
  Stdlib.exit Merlint_doc.Exit_status.refused

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

(* What to do about files nothing could be read for. Nothing merlint can read
   from the tree says why an artefact is missing, so the only thing left to say
   is that merlint already tried the build -- which it does whenever a file it
   was asked to read has no artefact -- and the build itself is what needs
   looking at. *)
let unchecked_remedy ~project_root ~repaired =
  if not repaired then None
  else
    let root = Fpath.(v project_root |> normalize |> rem_empty_seg) in
    Fmt.kstr
      (fun s -> Some s)
      "  merlint ran the build for this and no artefact appeared, so the build \
       itself is what needs fixing. Run it and read what it reports:@.    dune \
       build --root %a @@check"
      Fpath.pp root

(* A run that examined less than it was asked to reports what it could not
   reach and, when the tree says why, what to do about it. A file gets here two
   ways: it was named for analysis and nothing said what to type it against,
   which a build answers, or no dune stanza claims it at all, in which case no
   rule ran on it and a build changes nothing. *)
let print_incomplete ?remedy unchecked =
  let plural = if unchecked = 1 then "" else "s" in
  let it = if unchecked = 1 then "it" else "them" in
  Fmt.pr
    "%s No issues found, but %d file%s could not be checked, so some or all of \
     the rules did not run on %s. The warnings above name %s and say why; -v \
     names every one.@."
    (Merlint.Report.print_color false "✗")
    unchecked plural it it;
  match remedy with Some remedy -> Fmt.pr "%s@." remedy | None -> ()

(* merlint has rules for .ml and .mli and for no other kind of file, so a path
   of any other kind is one it read nothing of. The report answers for the
   files it did read, and a caller reads that as the verdict over every
   argument it gave, so the paths that carried no verdict are named here.

   Named, not refused. A path that does not exist refuses the whole run because
   the caller's list is wrong and no verdict computed from a wrong list means
   anything. This list is not wrong: linting the files a change touched names
   dune stanzas, cram transcripts and shell scripts beside the sources, and
   refusing that would leave the caller nothing to run. So the run answers for
   what it can read and says, in the summary and in the status, that it read
   less than it was given. *)
let print_skipped skipped =
  let n = List.length skipped in
  Fmt.pr
    "%s merlint reads .ml and .mli only, so nothing above is a verdict on %d \
     path%s it was given:@."
    (Merlint.Report.print_color false "✗")
    n
    (if n = 1 then "" else "s");
  List.iter (fun path -> Fmt.pr "    %s@." path) skipped

(* A check that raised did not run, and what it returned is what a check that
   ran and found nothing returns. The difference between those two is the whole
   of what a caller reading "0 issues" is entitled to know, so the summary says
   which of them this was. The engine's warning already names each one, and
   naming them twice would leave two lists to disagree. *)
let print_crashed failures =
  let n = List.length failures in
  Fmt.pr
    "%s %d check%s crashed, so %s did not run and nothing above answers for \
     what %s would have found. The warnings above name %s; --json carries them \
     too. This is a defect in merlint, not in the code it was reading.@."
    (Merlint.Report.print_color false "✗")
    n
    (if n = 1 then "" else "s")
    (if n = 1 then "it" else "they")
    (if n = 1 then "it" else "they")
    (if n = 1 then "it" else "them")

(* A rule that could not evaluate is the third way an empty finding list is
   produced, beside a rule that found nothing and a rule that crashed. The
   summary counts it and the exit status carries it, and that is all it gets:
   the count is what a reader needs, and --json names the rule and the fact it
   could not resolve for a reader who wants more.

   Counted by rule, not by question. One rule that could not resolve forty
   names is one rule this run did not check, and a count of forty would read as
   forty rules. Deduplication is over the rule code, so a failure carrying no
   code still counts as one. *)
let rules_unchecked failures =
  List.map (fun (f : Merlint.Engine.failure) -> f.rule) failures
  |> List.sort_uniq (Option.compare String.compare)
  |> List.length

(* What the summary line adds when the run answered for less than it was given.
   The four reasons are counted apart because they are fixed apart: an
   unchecked file is one merlint was going to read and could not, which a build
   or an edit answers; a skipped path is one it has no rule for, which only
   dropping it from the arguments answers; a crashed check is a defect in
   merlint, which only merlint answers; and a rule that was not checked needed a
   fact the project index does not hold, which widening the run or building the
   tree answers. *)
let incomplete_clauses ~unchecked ~skipped ~crashed ~unevaluated =
  let clause n singular plural =
    if n = 0 then []
    else [ Fmt.str "%d %s" n (if n = 1 then singular else plural) ]
  in
  clause unchecked "file unchecked" "files unchecked"
  @ clause skipped "path skipped" "paths skipped"
  @ clause crashed "check crashed" "checks crashed"
  @ clause unevaluated "rule not checked" "rules not checked"

(* Print summary and status *)
(* A run whose typedtree-backed rules could not read an artefact, or that was
   handed a path it has no rule for, examined less than it was asked to. Saying
   only "0 issues" would report that as the same outcome as a complete run, so
   what it did not answer for goes in the summary line itself, where a caller
   reading the last line of output sees it. *)
let print_summary ?(unchecked = 0) ?(skipped = []) ?(failed = []) ?remedy
    all_issues rules_applied =
  let total_issues = List.length all_issues in
  let crashed, unevaluated =
    List.partition
      (fun (f : Merlint.Engine.failure) -> f.kind = Merlint.Engine.Crashed)
      failed
  in
  let clauses =
    incomplete_clauses ~unchecked ~skipped:(List.length skipped)
      ~crashed:(List.length crashed)
      ~unevaluated:(rules_unchecked unevaluated)
  in
  let all_passed = total_issues = 0 && clauses = [] in
  let rule_word = if rules_applied = 1 then "rule" else "rules" in

  Fmt.pr "@.Summary: %s %d total %s (applied %d %s%s)@."
    (Merlint.Report.print_color all_passed
       (Merlint.Report.print_status all_passed))
    total_issues
    (if total_issues = 1 then "issue" else "issues")
    rules_applied rule_word
    (match clauses with
    | [] -> ""
    | clauses -> ", " ^ String.concat ", " clauses);

  if skipped <> [] then print_skipped skipped;
  if crashed <> [] then print_crashed crashed;
  if all_passed then
    Fmt.pr "%s All checks passed!@." (Merlint.Report.print_color true "✓")
  else if total_issues = 0 then (
    if unchecked > 0 then print_incomplete ?remedy unchecked)
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

let run_engine ?domain_mgr ~load_file ?profiling ~json_output ~bail ~exclude
    ~include_vendored ~index_is_partial rule_filter analyze_set analyze_roots
    build_index project_root =
  match rule_filter with
  | Some filter ->
      Merlint.Engine.run ?domain_mgr ~load_file ~filter ?analyze_set
        ?analyze_roots ~index:build_index ~index_is_partial ?profiling ~bail
        ~exclude ~include_vendored project_root
  | None -> (
      match Merlint.Filter.parse "all" with
      | Ok filter ->
          Merlint.Engine.run ?domain_mgr ~load_file ~filter ?analyze_set
            ?analyze_roots ~index:build_index ~index_is_partial ?profiling ~bail
            ~exclude ~include_vendored project_root
      | Error msg ->
          (* An empty result here would report a run that examined nothing as a
             clean one. The filter is merlint's own literal, so a parse failure
             is a defect in merlint and it says so rather than passing. *)
          Fmt.kstr
            (refuse_internal ~json_output ~project_root)
            "the default rule filter does not parse: %s" msg)

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

(* The human-readable report: the file count, the findings by category, the
   summary line, and the profiling tables when asked for.

   The count leads every run, zero included. It used to be omitted at zero, so
   the only way to tell a verdict over nothing from a verdict over the tree was
   to notice a line that was not there, and a reader who did not know to look
   read "All checks passed" as the answer it appears to be. *)
let print_text_report ~project_root ~files_analyzed ~rules_applied ~unchecked
    ~skipped ~failed ~repaired ~excluded ~profiling issues =
  Fmt.pr "Running merlint analysis...@.@.Analyzing %d files@.@." files_analyzed;
  print_exclusion_stats excluded;
  let issues_by_category = group_issues_by_category issues in
  print_categorized_issues issues_by_category;
  print_summary_table issues_by_category;
  print_summary ~unchecked ~skipped ~failed
    ?remedy:(unchecked_remedy ~project_root ~repaired)
    issues rules_applied;
  match profiling with
  | Some state ->
      Merlint.Profiling.print_summary state;
      Merlint.Profiling.print_rule_summary state;
      Merlint.Profiling.print_file_summary state
  | None -> ()

let run_analysis ?domain_mgr ~load_file ~json_output ~repair ~skipped
    ~index_is_partial project_root analyze_set analyze_roots
    (build_index : ?pool:Eio.Executor_pool.t -> unit -> Project_index.t)
    rule_filter show_profile ~bail ~exclude ~include_vendored =
  let profiling_state =
    if show_profile then Some (Merlint.Profiling.v ()) else None
  in
  let files_count = Option.map List.length analyze_set in
  Log.info (fun m ->
      m "Analysing %s files"
        (match files_count with None -> "all" | Some n -> string_of_int n));
  let analyse () =
    run_engine ?domain_mgr ~load_file ?profiling:profiling_state ~json_output
      rule_filter ~bail ~exclude ~include_vendored ~index_is_partial analyze_set
      analyze_roots build_index project_root
  in
  let result = analyse () in
  let repaired, result =
    match repair ~project_root result.Merlint.Engine.unresolved_files with
    | false -> (false, result)
    | true -> (true, analyse ())
  in
  let {
    Merlint.Engine.issues = all_issues;
    excluded = all_excluded;
    files_analyzed;
    rules_applied;
    unresolved_files;
    uncompilable_files;
    unclaimed_files;
    failed;
  } =
    result
  in
  (* One number, three reasons. A file nothing said what to type against, one
     the compiler refused, and one no stanza compiles are all files this run
     says nothing about, and a summary that counted only some of them would
     report a gap as a clean run. *)
  let unchecked_files = unresolved_files @ uncompilable_files in
  let unchecked = List.length unchecked_files + List.length unclaimed_files in
  if json_output then
    print_json_report ~project_root ~files_analyzed ~rules_applied
      ~unchecked_files ~unclaimed_files ~skipped ~failed ~excluded:all_excluded
      all_issues
  else
    print_text_report ~project_root ~files_analyzed ~rules_applied ~unchecked
      ~skipped ~failed ~repaired ~excluded:all_excluded
      ~profiling:profiling_state all_issues;
  exit_with_status ~unchecked ~skipped:(List.length skipped)
    ~failed:(List.length failed) all_issues

(* merlint asked dune for the artefacts its typedtree-backed rules read, and did
   not get them. What it used to print was a warning, then "Function type
   analysis may not work properly", then "Continuing with analysis..." -- which
   is the sentence "this verdict was computed without the artefacts it rests
   on", written in a register nobody re-reads. It was read as advisory: a
   pre-commit hook over 233 files printed "All checks passed!" and exited 0 on a
   build that never ran, while another session held the dune root.

   There is no continuing. A run that could not build cannot tell a clean tree
   from an untypechecked one, and either answer it printed would be a guess. So
   the whole run is refused, the way a path that does not exist is refused: no
   partial verdict is reported, and no number is produced that a caller could
   read as one.

   The two causes differ in what merlint does before giving up, never in where
   it ends up. A build that could not start because another dune holds the root
   is waited on -- bounded, and saying each time what it is waiting for and for
   how long, because a silent wait reads exactly like a hung process. A project
   that does not compile is refused at once, with what dune said about it.
   Neither ends in green: a busy tree stays committable by costing wall time,
   not by buying a pass. *)
let build_attempts = 6
let build_wait = 10.0

let refuse_unbuilt ~json_output ~project_root reason =
  if json_output then print_json_refusal ~project_root reason
  else begin
    Fmt.epr "merlint: %s@." (Merlint.Build.message reason);
    Fmt.epr
      "merlint: nothing was analysed, because a verdict computed without the \
       artefacts its rules read is not a verdict about this code.@."
  end;
  Stdlib.exit Merlint_doc.Exit_status.refused

let ensure_project_built ~json_output ~clock ~root ~scopes ~targets mgr =
  let started = Eio.Time.now clock in
  let rec attempt n =
    match Merlint.Build.ensure_project_built ~root ~scopes ~targets mgr with
    | Ok () -> ()
    | Error (Merlint.Build.Contended _ as reason) ->
        if n >= build_attempts then
          refuse_unbuilt ~json_output ~project_root:(Fpath.to_string root)
            reason
        else begin
          Fmt.epr
            "merlint: another dune session holds %a, so the build has not \
             started. Waiting %gs and trying again (attempt %d of %d, %.0fs so \
             far).@."
            Fpath.pp root build_wait (n + 1) build_attempts
            (Eio.Time.now clock -. started);
          Eio.Time.sleep clock build_wait;
          attempt (n + 1)
        end
    | Error reason ->
        refuse_unbuilt ~json_output ~project_root:(Fpath.to_string root) reason
  in
  attempt 1

(* A file nothing could say what to type against is a file the typedtree-backed
   rules did not run on, and one [dune build] is what produces the artefact
   they read. Merlint runs that build itself and looks again: the condition is
   not one the caller created, and repairing it costs a scoped build where
   refusing costs the caller the same build plus a round trip. Refusal is what
   is left when the build changes nothing, and the summary then says so.

   It runs after a pass rather than before one, so it fires on the files a run
   really failed to read rather than on every artefact that looks out of date.
   An artefact that no longer describes its source is not one of these: the
   source is typechecked in its place and every rule still runs on it, so
   building for that would spend a build to learn nothing.

   Once per run. A run that warmed the build already had its build, and a
   second identical one produces the same artefacts it just produced. *)
let repair_unresolved ~built ~json_output ~clock ~index mgr ~project_root files
    =
  match files with
  | [] -> false
  | _ :: _ when built -> false
  | files ->
      let n = List.length files in
      if n = 1 then
        Fmt.epr "Building the file above, then analysing it again.@."
      else Fmt.epr "Building the %d files above, then analysing them again.@." n;
      let targets, scopes =
        List.fold_left
          (fun (targets, scopes) file ->
            let file = Fpath.v file in
            let file_targets =
              Project_index.executable_targets_of_source (index ()) file
            in
            (List.rev_append file_targets targets, Fpath.parent file :: scopes))
          ([], []) files
      in
      let targets = List.sort_uniq Fpath.compare targets in
      let scopes = List.sort_uniq Fpath.compare scopes in
      ensure_project_built ~json_output ~clock ~root:(Fpath.v project_root)
        ~scopes ~targets mgr;
      true

let is_ocaml_source path =
  Filename.check_suffix path ".ml" || Filename.check_suffix path ".mli"

let classify_path path =
  if not (Sys.file_exists path) then `Missing
  else if Sys.is_directory path then `Dir
  else if is_ocaml_source path then `File
  else `Other

(* A path merlint cannot find is a path it read nothing of. Reporting the rest
   of the run and leaving that one out ends in "All checks passed" over a file
   nobody looked at, which is the sentence a caller acts on. The whole run is
   refused instead, and a missing path beside paths that are there refuses just
   the same: the summary is one verdict over every argument, so a partial run
   carries the same false reading, and it is the caller's list that has to be
   fixed before any of it means anything. *)
let missing_paths files =
  List.filter
    (fun path ->
      match classify_path path with
      | `Missing -> true
      | `Dir | `File | `Other -> false)
    files

(* A path that is there, is not a directory and is not OCaml source. merlint
   has no rule that reads one, so it is a path this run said nothing about, and
   the summary names it rather than answering for it with the files it did
   read. Reported where it is asked for -- the arguments -- and not inside the
   walk of a directory argument, where a file of another kind is not something
   the caller asked about at all. *)
let skipped_paths files =
  List.filter
    (fun path ->
      match classify_path path with
      | `Other -> true
      | `Dir | `File | `Missing -> false)
    files

let refuse_missing_paths files =
  match missing_paths files with
  | [] -> ()
  | missing ->
      List.iter
        (fun path -> Fmt.epr "merlint: %s: no such file or directory@." path)
        missing;
      Fmt.epr
        "merlint: nothing was analysed, because a run that skipped %s would \
         report the files it did read as the whole answer.@."
        (if List.length missing = 1 then "it" else "them");
      Stdlib.exit Merlint_doc.Exit_status.refused

let resolve_cli_path raw =
  let p = Fpath.v raw in
  if Fpath.is_abs p then Fpath.normalize p
  else Fpath.normalize Fpath.(v (Sys.getcwd ()) // p)

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

(* Narrow [analyze_set] from CLI arguments. Bare-file arguments enumerate the
   files to analyse directly; a directory argument leaves [analyze_set = None]
   and rides in [analyze_roots], which the engine expands; no argument at all
   leaves both empty and the engine walks [Project_index.source_files].

   Arguments that name only paths merlint has no rule for are the fourth case,
   and they enumerate the empty set rather than falling back to [None].
   Falling back put the run back on the whole index: [merlint notes.txt]
   answered with a verdict over every source in the project the path resolved a
   root from, under a command that named one file and no source at all. That is
   the reading a path naming nothing is refused for, arriving from a path that
   is there. *)
let analyze_set_of_files files =
  match files with
  | [] -> None
  | _ -> (
      (* Asked again of the paths as they will be read, so a file that goes
         away between the command line and here refuses too. *)
      refuse_missing_paths files;
      let explicit =
        List.filter_map
          (fun p ->
            match classify_path p with
            | `File -> Some (resolve_cli_path p)
            | `Dir | `Other | `Missing -> None)
          files
      in
      match (explicit, analyze_roots_of_files files) with
      | [], Some _ -> None
      | explicit, _ -> Some explicit)

(* The directories whose [check] alias the [--build] warm-up must build. A
   directory argument is its own scope; a file argument is scoped by the
   directory holding it, which is the directory whose alias compiles it. With
   nothing to scope to the run analyses the whole project, and the warm-up
   builds the whole project. *)
let build_scopes_of_files files =
  List.filter_map
    (fun p ->
      match classify_path p with
      | `Dir -> Some (resolve_cli_path p)
      | `File -> Some (Fpath.parent (resolve_cli_path p))
      | `Other | `Missing -> None)
    files

(* A path outside the dune root is a path merlint will not read: every rule
   resolves its sources under that root, so nothing this run does answers for
   it. It reached the engine, which resolves it with [Project_index.Path.under]
   and raises, and the run ended in "merlint: internal error, uncaught
   exception" over an argument merlint had parsed perfectly and simply could
   not act on -- reported as a defect in merlint, and as status 125, which
   timeout(1) also spends.

   Refused here instead, where the root has just been chosen, because that is
   the first point that knows both halves. The root is named as well as the
   path: the answer is a pair, and a caller who sees only the path it gave will
   look for the fault in the path. *)
let refuse_paths_outside_root ~project_root files =
  let root = Project_index.Path.v project_root in
  let outside =
    List.filter_map
      (fun path ->
        let path = Project_index.Path.v path in
        if Project_index.Path.is_descendant ~ancestor:root path then None
        else Some path)
      files
  in
  match outside with
  | [] -> ()
  | outside ->
      (* The resolved path, not the argument as written: a relative one is
         refused for where it landed, and a caller cannot check that against a
         root without seeing both sides resolved the same way. *)
      List.iter
        (fun path ->
          Fmt.epr "merlint: %s is outside the dune root %s@."
            (Project_index.Path.to_string path)
            project_root)
        outside;
      Fmt.epr
        "merlint: nothing was analysed, because no rule reads a source from \
         outside the root the run resolved.@.";
      Stdlib.exit Merlint_doc.Exit_status.refused

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
   rooted at the workspace.

   A declaration that does not apply here -- what a second working tree of the
   checkout sees, since no workspace reaches it -- is a note, not a refusal.
   The run continues where it stands: a tree that builds where it is has its
   artefacts there and is checked normally, and one that does not is told so by
   the summary, which is the same answer it would give with no declaration at
   all. *)
let redirect_analysis files =
  let anchor = match files with file :: _ -> file | [] -> "." in
  match Merlint.Project.workspace_link anchor with
  | Error msg ->
      Fmt.epr "Note: %s@." msg;
      Fmt.epr "Analysing this tree where it stands.@.";
      None
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

let maybe_build_project mgr ~json_output ~clock ~project_root ~analyze_roots
    ~build_scopes ~index ~build =
  if build then (
    Log.info (fun m -> m "Building project...");
    (* Freeze the analysis set before starting Dune. A source added while the
       build is running cannot have been part of that build; discovering it
       afterwards would make this run analyse a file the build never saw. The
       following run will include and build the new source. Walking the sources
       is what freezes them: the index scans on demand, so forcing it alone
       settles nothing. *)
    let frozen_index = Lazy.force index in
    ignore
      (Project_index.source_files ?roots:analyze_roots frozen_index
        : Fpath.t list);
    ensure_project_built ~json_output ~clock ~root:(Fpath.v project_root)
      ~scopes:build_scopes ~targets:[] mgr;
    Log.info (fun m -> m "Build done."))

let monorepo_for_index project_root =
  Fpath.(v project_root |> normalize |> rem_empty_seg)

let resolve_index_root raw =
  let p = Fpath.v raw in
  if Fpath.is_abs p then Fpath.normalize p
  else Fpath.normalize Fpath.(v (Sys.getcwd ()) // p)

(* [root] covers [monorepo] when it is that directory or one above it: the scan
   it selects then reaches every package. Both sides lose a trailing empty
   segment first, because [.] resolves to a directory path and [monorepo] does
   not, and comparing the two as written answers "different" for one directory.
*)
let root_covers ~monorepo root =
  let root = normalize_fpath root and monorepo = normalize_fpath monorepo in
  Fpath.equal root monorepo || Fpath.is_prefix root monorepo

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

let analyze_files mgr clock fs domain_mgr ?(exclude_patterns = []) ?rule_filter
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
  refuse_paths_outside_root ~project_root files;
  Log.info (fun m -> m "Scanning project structure...");
  let analyze_set = analyze_set_of_files files in
  let analyze_roots = analyze_roots_of_files files in
  let skipped = skipped_paths files in
  let build_scopes = build_scopes_of_files files in
  let monorepo = monorepo_for_index project_root in
  let index_roots = index_roots_of_files files in
  (* Whether the index this run builds covers the whole source tree. A root
     that is [monorepo] itself, or an ancestor of it, narrows nothing; anything
     below it leaves packages unscanned, and a name they provide then resolves
     to nothing exactly as a name nobody provides does. The caller that narrows
     the scan is the only place that knows it did, so the fact is derived here,
     once, and threaded down rather than re-derived from a directory listing by
     whoever needs it. *)
  let index_is_partial =
    match index_roots with
    | None -> false
    | Some roots -> not (List.exists (root_covers ~monorepo) roots)
  in
  let installed = installed_index_mode rule_filter in
  let index_cache = ref None in
  let build_index ?pool () =
    match !index_cache with
    | Some index -> index
    | None ->
        let index =
          build_project_index ~fs ~monorepo ?roots:index_roots ~installed ?pool
            ()
        in
        index_cache := Some index;
        index
  in
  let lazy_index = lazy (build_index ()) in
  maybe_build_project mgr ~json_output ~clock ~project_root ~analyze_roots
    ~build_scopes ~index:lazy_index ~build;
  let analysis_index ?pool () =
    if build then Lazy.force lazy_index else build_index ?pool ()
  in
  run_analysis ~domain_mgr ~load_file ~json_output
    ~repair:
      (repair_unresolved ~built:build ~json_output ~clock
         ~index:(fun () -> build_index ())
         mgr)
    ~skipped ~index_is_partial project_root analyze_set analyze_roots
    analysis_index rule_filter show_profile ~bail ~exclude:exclude_patterns
    ~include_vendored

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

let build_flag =
  let doc =
    "Run 'dune build @check' and refresh stale .cmt/.cmti artifacts before \
     analysis."
  in
  Arg.(value & flag & info [ "build" ] ~doc)

(* Load the merlint.toml governing this run before anything else does, so a
   file merlint refuses -- an unknown key, malformed TOML -- ends the run as
   the user error it is. Left to the first rule that happens to read the
   config, the same refusal surfaces as an uncaught exception and reads as a
   merlint bug. *)
let check_configuration files =
  let path = match files with [] -> Sys.getcwd () | path :: _ -> path in
  match Merlint.Config.load path with
  | _ -> ()
  | exception Failure msg ->
      (* The message already opens with "merlint config: <file>:". *)
      Fmt.epr "%s@." msg;
      (* Refused, not a finding: the run stopped before it read a source, so
         the status that means "the code merlint read has issues" would be
         reporting on code nothing looked at. *)
      Stdlib.exit Merlint_doc.Exit_status.refused

let show_configuration files =
  let path = match files with [] -> Sys.getcwd () | path :: _ -> path in
  let project_root = Merlint.Project.root path in
  let config_files = Merlint.Project.config_files path in
  let config = Merlint.Config.load path in
  Fmt.pr "=== Merlint Configuration ===@.";
  Fmt.pr "Dune root: %s@." project_root;
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
          (* Same refusal: no rule was selected, so no rule ran. *)
          Stdlib.exit Merlint_doc.Exit_status.refused)

let main exclude_patterns rules_spec ~show_profile ~show_config ~build ~bail
    ~include_vendored files () =
  check_configuration files;
  refuse_missing_paths files;
  if show_config then show_configuration files
  else
    let rule_filter = parse_rule_filter rules_spec in
    let json_output = Observe.json_enabled () in
    (* The display owns whichever stream it is given, and log events are routed
       into it, so under --json stdout has to belong to the document alone. *)
    let ppf = if json_output then Fmt.stderr else Fmt.stdout in
    Eio_main.run @@ fun env ->
    let clock = Eio.Stdenv.clock env in
    Console_eio.run ~clock ~ppf @@ fun _display ->
    let mgr = Eio.Stdenv.process_mgr env in
    let fs = Eio.Stdenv.fs env in
    let domain_mgr = Eio.Stdenv.domain_mgr env in
    analyze_files mgr clock fs domain_mgr ~exclude_patterns ?rule_filter
      ~show_profile ~build ~bail ~include_vendored ~json_output files

let analyze_term =
  let json_log_reporter ~app:_ ~base:_ () = Observe.reporter () in
  Term.(
    const (fun e r p bail c b vendored f u ->
        main e r ~show_profile:p ~show_config:c ~build:b ~bail
          ~include_vendored:vendored f u)
    $ exclude_flag $ rules_flag $ profile_flag $ bail_flag $ show_config_flag
    $ build_flag $ include_vendored_flag $ files
    $ Observe.setup ~json_reporter:(Some json_log_reporter) "merlint")

let exits = Merlint_doc.Exit_status.exits

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
  let info = Cmd.info "scan" ~version:Version.string ~doc ~man ~exits in
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
  let info = Cmd.info "merlint" ~version:Version.string ~doc ~man ~exits in
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

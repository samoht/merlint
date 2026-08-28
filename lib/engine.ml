(** Linting engine *)

let src = Logs.Src.create "merlint.engine" ~doc:"Linting engine"

module Log = (val Logs.src_log src : Logs.LOG)
module T = Ocaml_typing.Typedtree
module Tast_iterator = Ocaml_typing.Tast_iterator

type exclusion_stats = { rule : string; file : string }
type incomplete = Crashed | Unevaluated

type failure = {
  rule : string option;
  file : string option;
  kind : incomplete;
  error : string;
}

type result = {
  issues : Rule.Run.result list;
  excluded : exclusion_stats list;
  files_analyzed : int;
  rules_applied : int;
  unresolved_files : string list;
  uncompilable_files : string list;
  unclaimed_files : string list;
  failed : failure list;
}

(* What one unit of work produced: one analysed file, or one project-rule job.
   [applied] is the codes of the rules that actually ran over that unit, which
   is what the run's rule count is summed from. A rule the filter enabled and
   nothing ran -- no file to run it on, no unit to enumerate, no typedtree for
   the pass it belongs to -- did not apply to this run, and counting it would
   report a rule set that shrank as one that did not. *)
type outcome = {
  found : Rule.Run.result list;
  dropped : exclusion_stats list;
  applied : string list;
  failed : failure list;
}

let no_outcome = { found = []; dropped = []; applied = []; failed = [] }

(* What a rule that raised leaves behind. The exception's own text is what the
   report shows; the backtrace goes to the debug log, because which traversal
   overflowed is the first question asked of a crash and reproducing it to find
   out is the record this should have left. It is only recorded when the
   program was started with backtraces on ([OCAMLRUNPARAM=b]), which costs
   nothing to the runs that are not debugging one. *)
let failure_of_exn ?rule ?file exn =
  let error = Printexc.to_string exn in
  let backtrace = Printexc.get_backtrace () in
  Log.debug (fun m ->
      m "%s raised %s:@\n%s"
        (match rule with Some code -> code | None -> "file analysis")
        error backtrace);
  { rule; file; kind = Crashed; error }

(* A rule that consulted the index for a fact it does not hold ran to the end
   and still could not decide, so it comes back beside the crashes rather than
   beside the findings: same shape of gap, different remedy. It stays in
   [applied] -- unlike a crash -- because the rule did run, and over most of
   what it was given it decided; what it could not decide is named here. *)
let unevaluated_of (rule, question) =
  { rule = Some rule; file = None; kind = Unevaluated; error = question }

(* A bounded sample: naming every file of a whole-repo run buries the message
   the warning is carrying. *)
let sample_limit = 10

(* The cap is a default, not a ceiling. A run whose whole blind spot is the
   answer -- enumerating what a repo-wide scan could not look at -- asks for
   more detail, and that is what raising the log level means; the JSON document
   carries the same sets in full whatever the level. Without this a caller had
   to rediscover the rest by hand, one directory at a time. *)
let names_every_file () =
  match Logs.level () with Some (Logs.Info | Logs.Debug) -> true | _ -> false

let pp_sample ppf files =
  let sample =
    if names_every_file () then files
    else List.filteri (fun i _ -> i < sample_limit) files
  in
  List.iter (fun file -> Fmt.pf ppf "@,%s" file) sample;
  let extra = List.length files - List.length sample in
  if extra > 0 then
    Fmt.pf ppf
      "@,... and %d more (-v names every one; --json carries the whole set)"
      extra

(* Membership over a set of paths, compared after normalisation: the backend
   names a file as it was handed it and the index as it walked to it, and the
   two spell the same file differently. *)
let path_mem paths =
  let norm s = Fpath.(v s |> normalize |> to_string) in
  let tbl = Hashtbl.create 64 in
  List.iter (fun p -> Hashtbl.replace tbl (norm (Fpath.to_string p)) ()) paths;
  fun f -> Hashtbl.mem tbl (norm f)

(* A file whose artefact no longer describes it is typechecked instead, so the
   only files a run cannot look at are the ones nothing could say what to type
   against. Those split two ways:
   - Missing: the build system knows no stanza that compiles the file, for a
     stanza the host does build -- it has simply never been built, and one
     [dune build] fixes it.
   - Unavailable: the file belongs to a platform- or config-gated stanza the
     host does not build, so the build system has nothing to say about it and
     never will here -- not the user's to fix.
   Only Missing warrants the "run dune build" warning.

   The question is asked of [analyzed] alone. A project rule reads sources well
   outside the files a run was asked to analyse -- E610's reference scan reads
   every library source in the project -- and one of those it cannot read
   weakens that rule's evidence, which the rule reports in its own finding. It
   cannot leave this run incomplete: no rule of this run was going to examine
   the file.

   [unclaimed] is subtracted, so the two sets stay disjoint and one file is one
   unchecked file. It is also the right answer on its own terms: this warning
   sends the reader to [dune build], and no build produces an artefact for a
   file no stanza compiles. *)
let warn_unresolved ~index ~analyzed ~unclaimed stats =
  let in_scope = path_mem analyzed in
  let is_unclaimed = path_mem unclaimed in
  let is_gated = path_mem (Project_index.gated_source_files index) in
  let _unavailable, missing =
    List.filter
      (fun f -> in_scope f && not (is_unclaimed f))
      stats.Merlin.unresolved_files
    |> List.partition is_gated
  in
  (if missing <> [] then
     let n = List.length missing in
     Log.warn (fun m ->
         m
           "@[<v>%d file%s no typedtree: no build artefact describes %s and \
            the build system names no stanza that compiles %s, so nothing says \
            what to type %s against and the rules that read a typedtree were \
            skipped.%a@]"
           n
           (if n = 1 then " has" else "s have")
           (if n = 1 then "it" else "them")
           (if n = 1 then "it" else "them")
           (if n = 1 then "it" else "them")
           pp_sample missing));
  missing

(* The other way a run can be left without a typedtree for a file it was asked
   to analyse: the compiler read the source in full and refused it. That is not
   the warning above -- [dune build] is what the user would be sent to there,
   and here it reaches the same error -- so it gets its own, and says the one
   thing that does clear it. Asked of [analyzed] alone, for the same reason. *)
let warn_uncompilable ~analyzed ~unclaimed stats =
  let in_scope = path_mem analyzed in
  let is_unclaimed = path_mem unclaimed in
  let broken =
    List.filter
      (fun f -> in_scope f && not (is_unclaimed f))
      stats.Merlin.uncompilable_files
  in
  (if broken <> [] then
     let n = List.length broken in
     Log.warn (fun m ->
         m
           "@[<v>%d file%s not compile, so the compiler left only the part of \
            the unit it typed before the error and the rules that read a \
            typedtree were skipped. Fix the compile error%s; no build produces \
            an artefact for %s until then.%a@]"
           n
           (if n = 1 then " does" else "s do")
           (if n = 1 then "" else "s")
           (if n = 1 then "it" else "them")
           pp_sample broken));
  broken

(* The third way a run can be incomplete, and the only one that leaves no trace
   in what it did: a source file no dune stanza claims is never analysed at all,
   so no rule reports on it and no artefact is looked for. Left silent, the run
   reports the verdict of the files it happened to reach as the verdict of the
   directory it was pointed at. Naming them is what makes "Analyzing N files"
   add up against the tree.

   The first two explanations put the fault in the tree, and for three of the
   four packages this blocked in one week the fault was here: a stanza did name
   the file and the project index could not read the shape it was written in. A
   message offering only the first two sends a reader hunting a defect in a dune
   file that is correct, so it names the third and says how to tell them apart --
   what the index sees for the package, against what the dune file says. *)
let warn_unclaimed unclaimed =
  (if unclaimed <> [] then
     let n = List.length unclaimed in
     let it = if n = 1 then "it" else "them" in
     let belongs =
       if n = 1 then "it no longer belongs" else "they no longer belong"
     in
     Log.warn (fun m ->
         m
           "@[<v>%d file%s claimed by no dune stanza, so nothing compiles %s \
            and no rule examined %s. Three ways that happens: no stanza names \
            %s (a [(modules ...)] spec may be excluding %s); %s in the tree; \
            or a stanza does name %s and merlint's project index could not \
            read that stanza, which is a defect in merlint and not one of \
            yours. Check which with [dune exec -- project-index stanzas -p \
            <dir>] and [dune exec -- project-index libraries -p <dir>], where \
            <dir> is the package directory a named file sits under: a stanza \
            that is in the dune file and in neither listing is the third.%a@]"
           n
           (if n = 1 then " is" else "s are")
           it it it it belongs it pp_sample unclaimed));
  unclaimed

(* The fourth way a run can be incomplete, and the only one that is a defect in
   merlint rather than in the tree it was reading: a rule's body raised. What a
   rule that crashed returns is the empty list, which is what a rule that ran
   and found nothing returns, so the run carried on and reported the findings of
   the rules that survived as the findings of the whole set. Five rules raised
   [Stack_overflow] on one 129-line file and the run still printed a pass.

   One producer for this fact: the crashes are collected and named here, at the
   end of the run, rather than logged where they are caught, so the set the
   summary counts and the set the reader is shown cannot differ. *)
let failure_line failure =
  let what =
    match failure.rule with Some code -> code | None -> "whole-file analysis"
  in
  let where =
    match failure.file with Some file -> " on " ^ file | None -> ""
  in
  Fmt.str "%s%s: %s" what where failure.error

let warn_crashed crashed =
  if crashed <> [] then
    let n = List.length crashed in
    let they = if n = 1 then "it" else "they" in
    Log.warn (fun m ->
        m
          "@[<v>%d check%s raised, so %s never finished and this run's \
           findings are short by whatever %s would have reported. That is a \
           defect in merlint, not in the code it was reading; [OCAMLRUNPARAM=b \
           merlint -vv] logs the backtrace.%a@]"
          n
          (if n = 1 then "" else "s")
          they they pp_sample
          (List.map failure_line crashed))

(* A rule that could not evaluate is not warned about. The summary counts it
   and the exit status carries it, and --json names the rule and the question.
   A paragraph here would say a third time what those two already say. *)
let warn_failed failed =
  warn_crashed (List.filter (fun f -> f.kind = Crashed) failed);
  failed

let log_fs_stats () =
  let s = Fs.stats () in
  if
    s.readdirs + s.is_directory_checks + s.file_exists_checks + s.file_opens > 0
  then
    Log.info (fun m ->
        m "FS stats: readdirs=%d is_directory=%d file_exists=%d file_opens=%d"
          s.readdirs s.is_directory_checks s.file_exists_checks s.file_opens)

let log_backend_stats ~index ~analyzed ~unclaimed backend =
  let s = Merlin.stats backend in
  Log.info (fun m ->
      m
        "Merlin stats: cmt_hits=%d cmt_misses=%d cmt_reads=%d typechecks=%d \
         source_parses=%d"
        s.cmt_hits s.cmt_misses s.cmt_reads s.typechecks s.source_parses);
  (* Typechecking a file costs about ten times an artefact read, so a run that
     did many of them was working from a tree nobody had built. Worth saying,
     but not a warning: the files were examined. *)
  (match s.recovered_files with
  | [] -> ()
  | recovered ->
      Log.info (fun m ->
          m "Typechecked %d file%s whose build artefact did not describe %s"
            (List.length recovered)
            (if List.length recovered = 1 then "" else "s")
            (if List.length recovered = 1 then "it" else "them")));
  ( warn_unresolved ~index ~analyzed ~unclaimed s,
    warn_uncompilable ~analyzed ~unclaimed s )

(* The whole-repo index builders are meant to run a handful of times per
   analysis (roughly once per project rule). A count orders of magnitude higher
   means one is being recomputed inside a per-file or per-stanza loop. *)
let log_index_stats index =
  match Project_index.scan_stats index with
  | [] -> ()
  | stats ->
      Log.info (fun m ->
          m "Project-index scans: %a"
            Fmt.(list ~sep:(any ", ") (pair ~sep:(any "=") string int))
            stats)

let run_file_rule ?profiling ctx rule =
  let code = Rule.code rule in
  let filename = Context.filename ctx in
  Log.debug (fun m -> m "Running rule %s on %s" code filename);
  let start_time = Unix.gettimeofday () in
  let res =
    try
      Ok
        (Probe_events.file_rule ~rule:code ~file:filename (fun () ->
             Rule.Run.file rule ctx))
    with exn -> Error (failure_of_exn ~rule:code ~file:filename exn)
  in
  let duration = Unix.gettimeofday () -. start_time in
  (match profiling with
  | Some prof ->
      Profiling.add_timing prof
        {
          operation = Profiling.File_rule { rule_code = code; filename };
          duration;
        }
  | None -> ());
  res

let run_project_job ?profiling job =
  let code = Rule.Run.project_job_code job in
  Log.debug (fun m -> m "Running project rule job %s" code);
  let start_time = Unix.gettimeofday () in
  let res =
    try
      Ok
        (Probe_events.project_rule ~rule:code (fun () ->
             Rule.Run.project_job job))
    with exn -> Error (failure_of_exn ~rule:code exn)
  in
  let duration = Unix.gettimeofday () -. start_time in
  (match profiling with
  | Some prof ->
      Profiling.add_timing prof
        { operation = Profiling.Project_rule code; duration }
  | None -> ());
  res

let merlin_op ?profiling filename f =
  let start = Unix.gettimeofday () in
  let r = f () in
  let duration = Unix.gettimeofday () -. start in
  (match profiling with
  | Some prof ->
      Profiling.add_timing prof
        { operation = Profiling.Merlin filename; duration }
  | None -> ());
  r

let file_view ?profiling ~load_file ~backend filename =
  let source_filename = Context.string_of_path filename in
  let content = lazy (load_file source_filename) in
  let source = Merlin.Source.v ~file:source_filename ~content in
  let typedtree () =
    (* Only OCaml units have a typedtree. A grammar/lexer source (.mly/.mll) or
       any other non-.ml/.mli file has no .cmt of its own -- the generated .ml
       does -- so don't probe for one (which would be a spurious cmt miss). *)
    if not (File_kind.is_ml_or_mli source_filename) then Ok None
    else
      merlin_op ?profiling source_filename (fun () ->
          Merlin.typedtree backend ~source)
  in
  File_view.v ~filename:source_filename ~content ~typedtree ()

let setup_analysis ~filter ~analyze_set ~index ~index_is_partial ~file_view
    project_root =
  (* Resolve a relative root (e.g. ".") against the cwd: the analyze_set paths
     derive from it via [Context.path_under], and [Context.project] requires
     those to be absolute so the file-view cache keys canonicalize. *)
  let project_root_path =
    if Filename.is_relative project_root then
      Context.path (Filename.concat (Sys.getcwd ()) project_root)
    else Context.path project_root
  in
  let project_root = Context.string_of_path project_root_path in
  let config = Config.load project_root in
  let analyze_set =
    List.map
      (fun file ->
        Context.path_under ~root:project_root_path (Fpath.to_string file))
      analyze_set
  in
  let project_ctx =
    Context.project ~config ~project_root:project_root_path ~analyze_set ~index
      ~index_is_partial ~file_view ()
  in
  let enabled_rules =
    Data.all_rules
    |> List.filter (fun rule ->
        Filter.is_enabled_by_code filter (Rule.code rule))
  in
  (config, project_ctx, enabled_rules)

let config_lookup () =
  let cache = Hashtbl.create 32 in
  fun file ->
    let dir = if Sys.file_exists file then Filename.dirname file else file in
    match Hashtbl.find_opt cache dir with
    | Some c -> c
    | None ->
        let c = Config.for_file file in
        Hashtbl.add cache dir c;
        c

(* Decide a finding's fate against the file's exclusions: [skip] drops it, and
   [count] (only when skipped) marks it a suppressed finding for the stats. A
   wholesale ["*"] (vendored-tree) exclusion is a "do not lint" directive, so it
   skips but does not count. *)
let exclusion_decision exclusions ~code ~file =
  let skip = Rule_config.should_exclude exclusions ~rule:code ~file in
  let count = skip && not (Rule_config.is_wildcard_excluded exclusions ~file) in
  (skip, count)

(* Per-rule excluded-accumulator pattern: each rule produces its own
   excluded list, and the caller flattens at the end. Avoids a shared ref
   when project rules run in parallel domains. *)
let split_excluded ~config_for ~code issues =
  let excluded = ref [] in
  let kept =
    List.filter
      (fun r ->
        match Rule.Run.location r with
        | None -> true
        | Some loc ->
            let file = loc.Location.file in
            let cfg : Config.t = config_for file in
            let skip, count = exclusion_decision cfg.exclusions ~code ~file in
            if count then excluded := { rule = code; file } :: !excluded;
            not skip)
      issues
  in
  (kept, List.rev !excluded)

let run_one_project_job ?profiling ~config_for job =
  let code = Rule.Run.project_job_code job in
  match run_project_job ?profiling job with
  | Error failure -> { no_outcome with failed = [ failure ] }
  | Ok issues ->
      let found, dropped = split_excluded ~config_for ~code issues in
      { found; dropped; applied = [ code ]; failed = [] }

let pass_iterator passes =
  let on_attribute = List.filter_map Rule.Run.pass_attribute passes in
  let on_expr = List.filter_map Rule.Run.pass_expr passes in
  let on_value_binding = List.filter_map Rule.Run.pass_value_binding passes in
  let dispatch_attribute attr = List.iter (fun f -> f attr) on_attribute in
  let dispatch_expr expr = List.iter (fun f -> f expr) on_expr in
  let dispatch_value_binding vb = List.iter (fun f -> f vb) on_value_binding in
  {
    Tast_iterator.default_iterator with
    attribute =
      (fun this attr ->
        dispatch_attribute attr;
        Tast_iterator.default_iterator.attribute this attr);
    expr =
      (fun this expr ->
        dispatch_expr expr;
        Tast_iterator.default_iterator.expr this expr);
    value_binding =
      (fun this value_binding ->
        dispatch_value_binding value_binding;
        Tast_iterator.default_iterator.value_binding this value_binding);
  }

(* [passes] pairs each active pass with the code of the rule it belongs to. A
   pass runs over a typedtree or not at all, so a file without one is a file
   none of these rules examined: they are reported as not applied rather than
   as having found nothing. *)
let run_passes passes ctx =
  match passes with
  | [] -> ([], [])
  | _ -> (
      match File_view.typedtree (Context.view ctx) with
      | None -> ([], [])
      | Some tree ->
          let actives = List.map snd passes in
          let on_structure_item =
            List.filter_map Rule.Run.pass_structure_item actives
          in
          let on_signature_item =
            List.filter_map Rule.Run.pass_signature_item actives
          in
          let dispatch_structure_item item =
            List.iter (fun f -> f item) on_structure_item
          in
          let dispatch_signature_item item =
            List.iter (fun f -> f item) on_signature_item
          in
          let iterator = pass_iterator actives in
          (match tree with
          | `Implementation structure ->
              List.iter dispatch_structure_item structure.T.str_items;
              iterator.structure iterator structure
          | `Interface signature ->
              List.iter dispatch_signature_item signature.T.sig_items;
              iterator.signature iterator signature);
          (List.concat_map Rule.Run.pass_finish actives, List.map fst passes))

let run_project_rules ?pool ?profiling enabled_rules project_ctx =
  let config_for = config_lookup () in
  let rules = List.filter Rule.is_project_scoped enabled_rules in
  let jobs =
    List.concat_map (fun rule -> Rule.Run.project_jobs rule project_ctx) rules
  in
  let run = run_one_project_job ?profiling ~config_for in
  Probe_events.project_rules ~rules:(List.length rules) ~jobs:(List.length jobs)
  @@ fun () ->
  let results =
    match pool with
    | None -> List.map run jobs
    | Some pool -> Fs.parallel_map pool jobs run
  in
  {
    found = List.concat_map (fun o -> o.found) results;
    dropped = List.concat_map (fun o -> o.dropped) results;
    applied = List.concat_map (fun o -> o.applied) results;
    failed = List.concat_map (fun o -> o.failed) results;
  }

(* Every file-scoped rule this run enables, over one file: the shared typedtree
   pass first, then the rules that read the file on their own. The codes come
   back beside the findings, because a rule that ran and found nothing and a
   rule that never ran are the same empty list. A rule that raised is the third
   member of that set and reads the same as the other two, so it comes back
   under its own name and out of the applied codes: it did not apply to this
   file, and counting it would report a check that never finished as one that
   passed. *)
let run_file_scoped_rules ?profiling ~file_rules ~pass_rules file_ctx =
  let active_passes =
    List.filter_map
      (fun rule ->
        Option.map
          (fun pass -> (Rule.code rule, pass))
          (Rule.Run.pass rule file_ctx))
      pass_rules
  in
  let shared_results, passes_applied = run_passes active_passes file_ctx in
  let direct =
    List.map
      (fun rule -> (Rule.code rule, run_file_rule ?profiling file_ctx rule))
      file_rules
  in
  let found_of (_, res) = match res with Ok found -> found | Error _ -> [] in
  let applied_of (code, res) =
    match res with Ok _ -> Some code | Error _ -> None
  in
  let failed_of (_, res) =
    match res with Ok _ -> None | Error failure -> Some failure
  in
  ( shared_results @ List.concat_map found_of direct,
    passes_applied @ List.filter_map applied_of direct,
    List.filter_map failed_of direct )

let analyze_single_file ?profiling ~project_ctx ~config_for ~project_root:_
    ~file_rules ~pass_rules filepath =
  let filename = Context.resolve project_ctx filepath in
  let filename_s = Context.string_of_path filename in
  let config = config_for filename_s in
  let excluded_acc = ref [] in
  let outcome =
    Probe_events.file_analysis ~file:filename_s
      ~file_rules:(List.length file_rules) ~pass_rules:(List.length pass_rules)
    @@ fun () ->
    try
      ignore profiling;
      let view = Context.file_view project_ctx filename in
      let file_ctx =
        Context.file_with_view ~filename ~config
          ~project_root:(Context.project_root project_ctx)
          ~view
          ~analyze_set:(Context.analyze_set project_ctx)
          ~selected_file:project_ctx.Context.in_analyze_set
          ~project_index:(Some (Context.index project_ctx))
          ~load_content:(fun () -> Context.file_content project_ctx filename)
      in
      let all_results, applied, failed =
        run_file_scoped_rules ?profiling ~file_rules ~pass_rules file_ctx
      in
      let found =
        List.filter
          (fun r ->
            let code = Rule.Run.code r in
            let skip, count =
              exclusion_decision config.exclusions ~code ~file:filename_s
            in
            if count then
              excluded_acc :=
                { rule = code; file = filename_s } :: !excluded_acc;
            not skip)
          all_results
      in
      { found; dropped = []; applied; failed }
    with exn ->
      { no_outcome with failed = [ failure_of_exn ~file:filename_s exn ] }
  in
  { outcome with dropped = List.rev !excluded_acc }

(** Walk [files] in parallel across [domain_mgr]'s executor pool. Each file is
    its own work unit; the pool decides how to spread them across domains. The
    earlier per-package grouping protected a process-global compiler-libs state
    that [typedtree_from_cmt] hasn't touched since the [with_cmt_state] wrap was
    removed -- cmt loading is now pure [Marshal.from_channel] and safe to call
    concurrently from any domain. *)
let analyze_files ?pool ~project_ctx ~project_root ~file_rules ~pass_rules
    ?profiling files =
  match (file_rules, pass_rules) with
  | [], [] -> []
  | _ -> (
      let config_for = config_lookup () in
      let analyse filepath =
        analyze_single_file ?profiling ~project_ctx ~config_for ~project_root
          ~file_rules ~pass_rules filepath
      in
      match pool with
      | None -> List.map analyse files
      | Some pool -> Fs.parallel_map pool files analyse)

(* Vendored paths come from the root dune metadata. The library-owner check
   keeps the package-level query useful for files resolved through the index. *)
let file_is_vendored index file =
  Project_index.is_vendored_path index file
  ||
  match Project_index.libraries_of_file index file with
  | [] -> false
  | libs -> List.for_all Project_index.Library.is_vendored libs

let drop_vendored_files index files =
  List.filter (fun f -> not (file_is_vendored index f)) files

let analysis_files ?analyze_set ?analyze_roots ?(include_vendored = false) index
    =
  let raw =
    match (analyze_set, analyze_roots) with
    | Some files, None -> files
    | None, roots -> Project_index.source_files ~include_vendored ?roots index
    | Some files, Some roots ->
        Project_index.source_files ~include_vendored ~roots index
        |> List.rev_append files
        |> List.sort_uniq Fpath.compare
  in
  if include_vendored then raw else drop_vendored_files index raw

(* CLI [--exclude PATTERN] drops files matching any glob from the analysis,
   using the same matcher as [merlint.toml] exclusions. Patterns are matched
   against both the file's path relative to [project_root] (so [vendor/**]
   works regardless of cwd) and the raw path. *)
let drop_excluded_files ~project_root ~exclude files =
  match exclude with
  | [] -> files
  | patterns ->
      let root = Fpath.v project_root in
      let excluded file =
        let raw = Fpath.to_string file in
        let rel =
          match Fpath.relativize ~root file with
          | Some r -> Fpath.to_string r
          | None -> raw
        in
        List.exists
          (fun p ->
            Rule_config.matches_pattern p rel
            || Rule_config.matches_pattern p raw)
          patterns
      in
      List.filter (fun f -> not (excluded f)) files

(* The source files the run was pointed at that no dune stanza claims, so
   [analysis_files] handed them to rules that had nothing to type them against
   and no stanza to place them in. They arrive two ways, and both are the
   caller's own question: a directory argument brings the sources under it that
   nothing compiles, and a file argument brings itself.

   The second used to answer nothing at all, on the grounds that an explicit
   [analyze_set] is the caller's accounting of what it wants looked at. That
   holds for a file the caller did not name -- which is why a directory's
   orphans stay out of a file-scoped run -- and inverts for one it did: naming
   a file no stanza compiles is exactly the case the caller is owed an answer
   about, and answering nothing reported it as a clean pass over a file no rule
   could examine. Membership is asked including vendored sources, because a
   vendored file is claimed by a stanza whether or not this run analyses it.

   The same exclusion globs apply, so a path the user asked to skip is not then
   reported as skipped. *)
let unclaimed_files ~project_root ~exclude ~include_vendored ~analyze_set
    ~analyze_roots index =
  let named =
    match analyze_set with
    | None -> []
    | Some files ->
        List.filter
          (fun file ->
            not
              (Project_index.mem_source_file ~include_vendored:true index file))
          files
  in
  let walked =
    match (analyze_set, analyze_roots) with
    | Some _, None -> []
    | (None | Some _), roots ->
        Project_index.unclaimed_source_files ~include_vendored ?roots index
  in
  List.rev_append named walked
  |> List.sort_uniq Fpath.compare
  |> drop_excluded_files ~project_root ~exclude
  |> List.map Fpath.to_string

let run_enabled_rules ?pool ?profiling ~project_ctx ~project_root ~enabled_rules
    analyze_set =
  let file_rules = List.filter Rule.is_direct_file_scoped enabled_rules in
  let pass_rules = List.filter Rule.uses_pass enabled_rules in
  Eio.Switch.run @@ fun sw ->
  let project_promise, project_resolver = Eio.Promise.create () in
  let file_promise, file_resolver = Eio.Promise.create () in
  Eio.Fiber.fork ~sw (fun () ->
      run_project_rules ?pool ?profiling enabled_rules project_ctx
      |> Eio.Promise.resolve project_resolver);
  Eio.Fiber.fork ~sw (fun () ->
      analyze_files ?pool ~project_ctx ~project_root ~file_rules ~pass_rules
        ?profiling analyze_set
      |> Eio.Promise.resolve file_resolver);
  (Eio.Promise.await project_promise, Eio.Promise.await file_promise)

let build_result ?(bail = false) ?(unresolved_files = [])
    ?(uncompilable_files = []) ?(unclaimed_files = []) ?(unevaluated = [])
    project file_outcomes files_analyzed =
  let outcomes = project :: file_outcomes in
  let issues =
    List.sort Rule.Run.compare (List.concat_map (fun o -> o.found) outcomes)
  in
  let issues =
    if bail then match issues with [] -> [] | issue :: _ -> [ issue ]
    else issues
  in
  let applied =
    List.concat_map (fun o -> o.applied) outcomes
    |> List.sort_uniq String.compare
  in
  {
    issues;
    excluded = List.concat_map (fun o -> o.dropped) outcomes;
    files_analyzed;
    rules_applied = List.length applied;
    unresolved_files;
    uncompilable_files;
    unclaimed_files;
    failed =
      warn_failed
        (List.concat_map (fun o -> o.failed) outcomes
        @ List.map unevaluated_of unevaluated);
  }

(* One whole analysis pass over [backend], optionally on [pool]. It returns the
   finished result, so the caller is left holding the backend's lifetime and
   nothing else. [requested_set] is the caller's [?analyze_set] as given, which
   the derived file set below shadows and the unclaimed accounting still needs.
*)
let analyse ?pool ?profiling ?bail ~load_file ~filter ~requested_set
    ~analyze_roots ~index ~index_is_partial ~exclude ~include_vendored ~backend
    project_root =
  let idx = lazy (index ?pool ()) in
  let idx_value = Lazy.force idx in
  let analyze_set =
    analysis_files ?analyze_set:requested_set ?analyze_roots ~include_vendored
      idx_value
    |> drop_excluded_files ~project_root ~exclude
  in
  let file_view = file_view ?profiling ~load_file ~backend in
  let _config, project_ctx, enabled_rules =
    setup_analysis ~filter ~analyze_set ~index:idx ~index_is_partial ~file_view
      project_root
  in
  Fs.reset_stats ();
  let files_analyzed = List.length analyze_set in
  let project_results, file_results =
    Probe_events.analysis ~project_root ~files:files_analyzed
      ~rules:(List.length enabled_rules)
    @@ fun () ->
    run_enabled_rules ?pool ?profiling ~project_ctx ~project_root ~enabled_rules
      analyze_set
  in
  log_index_stats idx_value;
  (* Unclaimed first: a file no stanza compiles is that set's to report, and
     subtracting it here is what keeps one file from counting as two unchecked
     ones and from sending the caller to a build that cannot help it. *)
  let unclaimed_files =
    warn_unclaimed
      (unclaimed_files ~project_root ~exclude ~include_vendored
         ~analyze_set:requested_set ~analyze_roots idx_value)
  in
  let unresolved_files, uncompilable_files =
    log_backend_stats ~index:idx_value ~analyzed:analyze_set
      ~unclaimed:(List.map Fpath.v unclaimed_files)
      backend
  in
  build_result ?bail ~unresolved_files ~uncompilable_files ~unclaimed_files
    ~unevaluated:(Context.unevaluated_questions project_ctx)
    project_results file_results files_analyzed

let run ?domain_mgr ~load_file ~filter ?analyze_set ?analyze_roots ~index
    ?(index_is_partial = false) ?profiling ?bail ?(exclude = [])
    ?(include_vendored = false) project_root =
  Log.info (fun m -> m "Starting analysis of %s" project_root);
  let backend = Merlin.v ~root_dir:project_root () in
  let analyse ?pool () =
    analyse ?pool ?profiling ?bail ~load_file ~filter ~requested_set:analyze_set
      ~analyze_roots ~index ~index_is_partial ~exclude ~include_vendored
      ~backend project_root
  in
  Fun.protect
    ~finally:(fun () ->
      log_fs_stats ();
      Merlin.close backend)
    (fun () ->
      match domain_mgr with
      | None -> analyse ()
      | Some dm -> Fs.with_pool dm (fun pool -> analyse ~pool ()))

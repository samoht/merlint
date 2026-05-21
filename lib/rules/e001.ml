(** E001: High Cyclomatic Complexity *)

type payload = { name : string; complexity : int; threshold : int }
(** Payload for complexity issues *)

type config = { max_complexity : int }

let src = Logs.Src.create "merlint.e001" ~doc:"E001 rule"

module Log = (val Logs.src_log src : Logs.LOG)

let check (ctx : Context.file) =
  let config = { max_complexity = ctx.Context.config.max_complexity } in
  let functions =
    Context.values ctx |> List.filter (fun v -> v.Function_metrics.is_function)
  in

  Log.debug (fun m -> m "E001: Found %d functions" (List.length functions));

  if File.is_test_file_path (Context.project_relative_file ctx) then []
  else
    List.filter_map
      (fun ({ name; loc; complexity; complexity_breakdown; _ } :
             Function_metrics.value) ->
        let pure_boolean_predicate =
          complexity_breakdown.total = complexity_breakdown.boolean_operators
        in
        if complexity > config.max_complexity then
          if pure_boolean_predicate then None
          else
            let loc = Loc.of_typed ~filename:(Context.filename ctx) loc in
            Some
              (Issue.v ~loc
                 { name; complexity; threshold = config.max_complexity })
        else None)
      functions

let pp ppf { name; complexity; threshold } =
  Fmt.pf ppf "Function '%s' has cyclomatic complexity of %d (threshold: %d)"
    name complexity threshold

let rule =
  Rule.v ~code:"E001" ~title:"High Cyclomatic Complexity" ~category:Complexity
    ~hint:
      "High cyclomatic complexity makes code harder to understand and test. \
       Consider breaking complex functions into smaller, more focused \
       functions. Each function should ideally do one thing well."
    ~examples:
      [ Example.bad Examples.E001.bad_ml; Example.good Examples.E001.good_ml ]
    ~pp (File check)

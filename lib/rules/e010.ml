(** E010: Deep Nesting *)

type config = { max_nesting : int }
type payload = { name : string; depth : int; threshold : int }

let check (ctx : Context.file) =
  let config = { max_nesting = ctx.config.max_nesting } in
  if File.is_test (Context.project_relative_file ctx) then []
  else
    List.filter_map
      (fun ({ name; loc; nesting = depth; is_function; _ } :
             Function_metrics.value) ->
        if is_function && depth > config.max_nesting then
          let loc = Loc.of_typed ~filename:(Context.filename ctx) loc in
          Some (Issue.v ~loc { name; depth; threshold = config.max_nesting })
        else None)
      (Context.values ctx)
    |> List.sort Issue.compare

let pp ppf { name; depth; threshold } =
  Fmt.pf ppf "Function '%s' has nesting depth of %d (threshold: %d)" name depth
    threshold

let rule =
  Rule.v ~code:"E010" ~title:"Deep Nesting" ~category:Complexity
    ~hint:
      "This issue means your code has too many nested conditions making it \
       hard to follow. Fix it by extracting nested logic into helper \
       functions, using early returns to reduce nesting, or combining \
       conditions when appropriate. Aim for maximum nesting depth of 4."
    ~examples:
      [ Example.bad Examples.E010.bad_ml; Example.good Examples.E010.good_ml ]
    ~pp (File check)

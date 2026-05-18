(** E010: Deep Nesting *)

type config = { max_nesting : int }
type payload = { name : string; depth : int; threshold : int }

let check (ctx : Context.file) =
  let config = { max_nesting = ctx.config.max_nesting } in
  let item_loc name =
    File_view.items (Context.view ctx)
    |> List.find_map (fun item ->
        if
          File_view.Item.kind item = File_view.Item.Value
          && File_view.Item.name item = name
        then Some (File_view.Item.loc item)
        else None)
    |> Option.value
         ~default:
           (Location.v ~file:ctx.filename ~start_line:1 ~start_col:0 ~end_line:1
              ~end_col:0)
  in

  if File.is_test_file ctx.filename then []
  else
    List.filter_map
      (fun ({ name; nesting = depth; is_function; _ } : Function_metrics.value)
         ->
        if is_function && depth > config.max_nesting then
          Some
            (Issue.v ~loc:(item_loc name)
               { name; depth; threshold = config.max_nesting })
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

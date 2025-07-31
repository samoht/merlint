(** E010: Deep Nesting *)

type config = { max_nesting : int }
type payload = { name : string; depth : int; threshold : int }

let check (ctx : Context.file) =
  let config = { max_nesting = ctx.config.max_nesting } in
  let ast = Context.ast ctx in

  (* Analyze each function in the AST *)
  List.filter_map
    (fun (name, expr) ->
      (* Calculate nesting depth using visitor pattern *)
      let depth = Ast.Nesting.depth expr in

      if depth > config.max_nesting then
        (* Create a dummy location for now - we'll improve this later *)
        let loc =
          Location.v ~file:ctx.filename ~start_line:1 ~start_col:0 ~end_line:1
            ~end_col:0
        in
        Some (Issue.v ~loc { name; depth; threshold = config.max_nesting })
      else None)
    ast.functions

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

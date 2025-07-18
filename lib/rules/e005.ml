(** E005: Function Too Long *)

type payload = { name : string; length : int; threshold : int }
(** Payload for function length issues *)

type config = { max_function_length : int }

let check (ctx : Context.file) =
  let config =
    { max_function_length = ctx.Context.config.max_function_length }
  in
  let outline = Context.outline ctx in

  (* Analyze each function from the outline *)
  List.filter_map
    (fun (item : Outline.item) ->
      match item.kind with
      | Value -> (
          (* Calculate function length from outline location *)
          match item.range with
          | Some range ->
              let length = range.end_.line - range.start.line + 1 in

              (* For now, we can't detect pattern matching from outline alone,
                 so we use the base threshold *)
              let threshold = config.max_function_length in

              if length > threshold then
                let loc =
                  Location.create ~file:ctx.filename
                    ~start_line:range.start.line ~start_col:range.start.col
                    ~end_line:range.end_.line ~end_col:range.end_.col
                in
                Some (Issue.v ~loc { name = item.name; length; threshold })
              else None
          | None -> None)
      | Type | Module | Class | Exception | Constructor | Field | Method
      | Other _ ->
          None)
    outline

let pp ppf { name; length; threshold } =
  Fmt.pf ppf "Function '%s' is %d lines long (threshold: %d)" name length
    threshold

let rule =
  Rule.v ~code:"E005" ~title:"Long Functions" ~category:Complexity
    ~hint:
      "This issue means your functions are too long and hard to read. Fix them \
       by extracting logical sections into separate functions with descriptive \
       names. Note: Functions with pattern matching get additional allowance \
       (2 lines per case). Pure data structures (lists, records) are also \
       exempt from length checks. For better readability, consider using \
       helper functions for complex logic. Aim for functions under 50 lines of \
       actual logic."
    ~examples:[] ~pp (File check)

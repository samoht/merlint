(** E350: Boolean Blindness - functions with 2+ boolean parameters *)

type payload = { function_name : string; bool_count : int; signature : string }
(** Payload for boolean blindness issues *)

(** Parse function signature to extract parameter types Handles nested
    parentheses and arrow types properly *)
let parse_params sig_str =
  let len = String.length sig_str in
  let rec skip_whitespace i =
    if i >= len then i
    else
      match sig_str.[i] with
      | ' ' | '\n' | '\t' -> skip_whitespace (i + 1)
      | _ -> i
  in

  (* Find matching closing paren, handling nesting *)
  let rec find_close_paren i depth =
    if i >= len then i
    else
      match sig_str.[i] with
      | '(' -> find_close_paren (i + 1) (depth + 1)
      | ')' -> if depth = 1 then i else find_close_paren (i + 1) (depth - 1)
      | _ -> find_close_paren (i + 1) depth
  in

  (* Extract one parameter, returns (param_type, is_labeled, next_pos) *)
  let extract_param i =
    let i = skip_whitespace i in
    if i >= len then None
    else
      (* Check for label: or ?label: *)
      let is_labeled, start =
        let rec check_label j =
          if j >= len then (false, i)
          else
            match sig_str.[j] with
            | ':' -> (true, j + 1) (* Found label *)
            | 'a' .. 'z' | 'A' .. 'Z' | '_' | '0' .. '9' | '?' ->
                check_label (j + 1)
            | _ -> (false, i)
          (* Not a label *)
        in
        check_label i
      in

      let start = skip_whitespace start in
      if start >= len then None
      else
        (* Parse the type *)
        match sig_str.[start] with
        | '(' ->
            (* Parenthesized type - find matching close paren *)
            let close = find_close_paren (start + 1) 1 in
            let param_type = String.sub sig_str start (close - start + 1) in
            (* Find the -> after this param *)
            let rec find_arrow j =
              let j = skip_whitespace j in
              if j + 1 < len && sig_str.[j] = '-' && sig_str.[j + 1] = '>' then
                Some (param_type, is_labeled, j + 2)
              else if j >= len then None
              else find_arrow (j + 1)
            in
            find_arrow (close + 1)
        | _ ->
            (* Non-parenthesized type - read until -> or end *)
            let rec find_end j =
              if j + 1 >= len then len
              else if sig_str.[j] = '-' && sig_str.[j + 1] = '>' then j
              else find_end (j + 1)
            in
            let end_pos = find_end start in
            let param_type =
              String.sub sig_str start (end_pos - start) |> String.trim
            in
            if end_pos >= len then Some (param_type, is_labeled, len)
            else Some (param_type, is_labeled, end_pos + 2)
  in

  (* Collect all parameters *)
  let rec collect_params i acc =
    match extract_param i with
    | None -> List.rev acc
    | Some (param_type, is_labeled, next_pos) ->
        collect_params next_pos ((param_type, is_labeled) :: acc)
  in
  collect_params 0 []

(** Count unlabeled boolean parameters in a function signature *)
let count_unlabeled_bool_params type_sig =
  let params = parse_params type_sig in
  (* Drop the last one as it's the return type *)
  let params =
    match List.rev params with _ :: rest -> List.rev rest | [] -> []
  in
  (* Count unlabeled bool params *)
  List.fold_left
    (fun count (param_type, is_labeled) ->
      if (not is_labeled) && String.trim param_type = "bool" then count + 1
      else count)
    0 params

(** Check for boolean blindness in function signatures *)
let check_boolean_blindness ~filename ~outline =
  match outline with
  | None -> []
  | Some items ->
      List.filter_map
        (fun (item : Outline.item) ->
          match (item.kind, item.type_sig) with
          | Outline.Value, Some sig_str when Outline.is_function_type sig_str ->
              let bool_count = count_unlabeled_bool_params sig_str in
              if bool_count >= 2 then
                match Outline.location filename item with
                | Some loc ->
                    Some
                      (Issue.v ~loc
                         {
                           function_name = item.name;
                           bool_count;
                           signature = sig_str;
                         })
                | None -> None
              else None
          | _ -> None)
        items

(** Main check function *)
let check ctx =
  let outline_data = Context.outline ctx in
  let filename = ctx.Context.filename in
  check_boolean_blindness ~filename ~outline:(Some outline_data)

let pp ppf { function_name; bool_count; signature = _ } =
  Fmt.pf ppf
    "Function '%s' has %d boolean parameters - consider using a variant type \
     or record for clarity"
    function_name bool_count

let rule =
  Rule.v ~code:"E350" ~title:"Boolean Blindness" ~category:Rule.Security_safety
    ~hint:
      "Functions with multiple boolean parameters are hard to use correctly. \
       It's easy to mix up the order of arguments at call sites. Consider \
       using variant types, labeled arguments, or a configuration record \
       instead."
    ~examples:
      [
        {
          is_good = false;
          code =
            {|(* BAD - Boolean blindness *)
let create_widget visible bordered = ...
let w = create_widget true false  (* What does this mean? *)|};
        };
        {
          is_good = true;
          code =
            {|(* GOOD - Explicit variants *)
type visibility = Visible | Hidden
type border = With_border | Without_border
let create_widget ~visibility ~border = ...
let w = create_widget ~visibility:Visible ~border:Without_border|};
        };
      ]
    ~pp (File check)

(** E350: Boolean Blindness - functions with 2+ boolean parameters *)

type payload = { function_name : string; bool_count : int; signature : string }
(** Payload for boolean blindness issues *)

(** Count boolean parameters in a function signature *)
let count_bool_params type_sig =
  (* Count occurrences of "bool" in the signature, excluding the return type *)
  let parts = String.split_on_char '>' type_sig in
  let param_part =
    match List.rev parts with
    | [] -> type_sig
    | return_type :: rest ->
        ignore return_type;
        String.concat ">" (List.rev rest)
  in
  (* Use the traverse helper to count "bool" occurrences *)
  Outline.count_parameters param_part "bool"

(** Check for boolean blindness in function signatures *)
let check_boolean_blindness ~filename ~outline =
  match outline with
  | None -> []
  | Some items ->
      List.filter_map
        (fun (item : Outline.item) ->
          match (item.kind, item.type_sig) with
          | Outline.Value, Some sig_str when Outline.is_function_type sig_str ->
              let bool_count = count_bool_params sig_str in
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
  let filename = ctx.filename in
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

(** E350: Boolean Blindness - functions with 2+ boolean parameters *)

type payload = { function_name : string; bool_count : int }

let is_bool (ct : Parsetree.core_type) =
  match ct.ptyp_desc with
  | Ptyp_constr ({ txt = Lident "bool"; _ }, []) -> true
  | _ -> false

let check ctx =
  let outline_data = Context.outline ctx in
  let filename = ctx.Context.filename in
  List.filter_map
    (fun (item : Outline.item) ->
      match item.kind with
      | Outline.Value when Outline.is_function_type item ->
          let bool_count = Outline.count_parameters item ~matches:is_bool in
          if bool_count >= 2 then
            match Outline.location filename item with
            | Some loc ->
                Some (Issue.v ~loc { function_name = item.name; bool_count })
            | None -> None
          else None
      | _ -> None)
    outline_data

let pp ppf { function_name; bool_count } =
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

module T = Ocaml_typing.Typedtree

type t = { loc : Location.t; name : string option; empty : bool }

let rec is_empty_list (expr : T.expression) =
  match expr.exp_desc with
  | Texp_construct (lid, _, []) ->
      Ocaml_parsing.Longident.flatten lid.txt = [ "[]" ]
  | Texp_open (_, inner) -> is_empty_list inner
  | _ -> false

let string_constant (expr : T.expression) =
  match expr.exp_desc with
  | Texp_constant (Ocaml_parsing.Asttypes.Const_string (s, _, _)) -> Some s
  | _ -> None

let suite_binding ~filename (vb : T.value_binding) =
  match vb.vb_pat.pat_desc with
  | Tpat_var (_, name, _) when name.txt = "suite" -> (
      match vb.vb_expr.exp_desc with
      | Texp_tuple [ (None, name_expr); (None, list_expr) ] ->
          Some
            {
              loc = Loc.of_typed ~filename vb.vb_loc;
              name = string_constant name_expr;
              empty = is_empty_list list_expr;
            }
      | _ -> None)
  | _ -> None

let of_view ~filename view =
  match File_view.typedtree view with
  | Some (`Implementation structure) ->
      List.filter_map
        (fun (item : T.structure_item) ->
          match item.str_desc with
          | Tstr_value (_, bindings) ->
              List.find_map (suite_binding ~filename) bindings
          | _ -> None)
        structure.str_items
  | Some (`Interface _) | None -> []

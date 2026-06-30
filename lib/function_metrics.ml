module T = Ocaml_typing.Typedtree
module Typed_ident = Ocaml_typing.Ident
module Typed_path = Ocaml_typing.Path

type complexity = {
  total : int;
  if_then_else : int;
  matches : int;
  try_handlers : int;
  boolean_operators : int;
  loops : int;
}

type value = {
  name : string;
  loc : Ocaml_parsing.Location.t;
  is_function : bool;
  complexity : int;
  complexity_breakdown : complexity;
  nesting : int;
  match_cases : int;
  trailing_record_fields : int;
  pure_data : bool;
}

let empty =
  {
    total = 0;
    if_then_else = 0;
    matches = 0;
    try_handlers = 0;
    boolean_operators = 0;
    loops = 0;
  }

let merge a b =
  {
    total = a.total + b.total;
    if_then_else = a.if_then_else + b.if_then_else;
    matches = a.matches + b.matches;
    try_handlers = a.try_handlers + b.try_handlers;
    boolean_operators = a.boolean_operators + b.boolean_operators;
    loops = a.loops + b.loops;
  }

let decision ?(if_then_else = 0) ?(matches = 0) ?(try_handlers = 0)
    ?(boolean_operators = 0) ?(loops = 0) total =
  { total; if_then_else; matches; try_handlers; boolean_operators; loops }

let sum xs = List.fold_left merge empty xs

let max_by_total xs =
  List.fold_left (fun acc x -> if x.total > acc.total then x else acc) empty xs

let clean_name_part s =
  match String.index_opt s '!' with None -> s | Some i -> String.sub s 0 i

let path_parts path =
  match Typed_path.flatten path with
  | `Ok (base, suffix) ->
      List.map clean_name_part (Typed_ident.name base :: suffix)
  | `Contains_apply ->
      Typed_path.name path |> String.split_on_char '.'
      |> List.filter (fun s -> s <> "")
      |> List.map clean_name_part

let rec callee_parts expr =
  match expr.T.exp_desc with
  | Texp_ident (path, _, _) -> Some (path_parts path)
  | Texp_apply (fn, _) -> callee_parts fn
  | Texp_struct_item (_, inner) -> callee_parts inner
  | _ -> None

let is_boolean_operator expr =
  match callee_parts expr with
  | Some [ "Stdlib"; "&&" ]
  | Some [ "Stdlib"; "||" ]
  | Some [ "&&" ]
  | Some [ "||" ] ->
      true
  | _ -> false

let rec is_function_expr expr =
  match expr.T.exp_desc with
  | Texp_function _ -> true
  | Texp_struct_item (_, inner) -> is_function_expr inner
  | _ -> false

let rec analyze_expr expr =
  match expr.T.exp_desc with
  | Texp_ifthenelse (cond, then_expr, else_expr) ->
      analyze_if_chain cond then_expr else_expr
  | Texp_match (expr, computation_cases, value_cases, _) ->
      let cases =
        List.map analyze_case computation_cases
        @ List.map analyze_case value_cases
      in
      let match_decision =
        if cases = [] then empty else decision ~matches:1 1
      in
      merge match_decision (merge (analyze_expr expr) (max_by_total cases))
  | Texp_try (expr, value_cases, effect_cases) ->
      let handlers = List.length value_cases + List.length effect_cases in
      let handler_decisions =
        if handlers = 0 then empty else decision ~try_handlers:1 1
      in
      let cases =
        List.map analyze_case value_cases @ List.map analyze_case effect_cases
      in
      merge handler_decisions (merge (analyze_expr expr) (max_by_total cases))
  | Texp_function _ -> empty
  | Texp_let (_, bindings, body) ->
      merge (sum (List.map analyze_let_binding bindings)) (analyze_expr body)
  | Texp_apply (fn, args) ->
      let boolean =
        if is_boolean_operator fn then decision ~boolean_operators:1 1
        else empty
      in
      merge boolean (merge (analyze_expr fn) (sum (List.map analyze_arg args)))
  | Texp_sequence (lhs, rhs) -> merge (analyze_expr lhs) (analyze_expr rhs)
  | Texp_tuple fields ->
      sum (List.map (fun (_, expr) -> analyze_expr expr) fields)
  | Texp_construct (_, _, args) | Texp_array (_, args) ->
      sum (List.map analyze_expr args)
  | Texp_record { fields; extended_expression; _ } ->
      merge
        (sum (Array.to_list (Array.map analyze_record_field fields)))
        (match extended_expression with
        | Some expr -> analyze_expr expr
        | None -> empty)
  | Texp_atomic_loc (expr, _, _)
  | Texp_field (expr, _, _)
  | Texp_lazy expr
  | Texp_assert (expr, _) ->
      analyze_expr expr
  | Texp_setfield (record, _, _, value) ->
      merge (analyze_expr record) (analyze_expr value)
  | Texp_while (cond, body) ->
      merge (decision ~loops:1 1)
        (merge (analyze_expr cond) (analyze_expr body))
  | Texp_for (_, _, first, last, _, body) ->
      merge (decision ~loops:1 1)
        (sum [ analyze_expr first; analyze_expr last; analyze_expr body ])
  | Texp_struct_item (_, body) -> analyze_expr body
  | Texp_letop { let_; ands; body; _ } ->
      let binding_count = 1 + List.length ands in
      let binding_exprs =
        analyze_expr let_.bop_exp
        :: List.map (fun (op : T.binding_op) -> analyze_expr op.bop_exp) ands
      in
      merge (decision binding_count)
        (merge (sum binding_exprs) (analyze_case body))
  | Texp_variant (_, arg) -> (
      match arg with Some expr -> analyze_expr expr | None -> empty)
  | Texp_override (_, fields) ->
      sum (List.map (fun (_, _, expr) -> analyze_expr expr) fields)
  | Texp_send (expr, _) | Texp_pack { mod_desc = Tmod_unpack (expr, _); _ } ->
      analyze_expr expr
  | Texp_constant _ | Texp_ident _ | Texp_new _ | Texp_instvar _
  | Texp_setinstvar _ | Texp_object _ | Texp_pack _ | Texp_unreachable
  | Texp_extension_constructor _ | Texp_typed_hole ->
      empty

and analyze_arg = function
  | _, T.Arg expr -> analyze_expr expr
  | _, T.Omitted () -> empty

and analyze_if_chain cond then_expr else_expr =
  let rec arms acc cond then_expr else_expr =
    let current = merge (analyze_expr cond) (analyze_expr then_expr) in
    match else_expr with
    | Some { T.exp_desc = Texp_ifthenelse (cond, then_expr, else_expr); _ } ->
        arms (current :: acc) cond then_expr else_expr
    | Some expr -> analyze_expr expr :: current :: acc
    | None -> current :: acc
  in
  merge
    (decision ~if_then_else:1 1)
    (max_by_total (arms [] cond then_expr else_expr))

and analyze_case : type k. k T.case -> complexity =
 fun case ->
  let guard =
    match case.c_guard with Some expr -> analyze_expr expr | None -> empty
  in
  merge guard (analyze_expr case.c_rhs)

and analyze_let_binding (vb : T.value_binding) =
  if is_function_expr vb.vb_expr then empty else analyze_expr vb.vb_expr

and analyze_record_field = function
  | _, T.Kept _ -> empty
  | _, T.Overridden (_, expr) -> analyze_expr expr

let analyze_function_cases cases =
  let match_decision = if cases = [] then empty else decision ~matches:1 1 in
  merge match_decision (max_by_total (List.map analyze_case cases))

let analyze_function_params params =
  sum
    (List.map
       (fun (param : T.function_param) ->
         match param.fp_kind with
         | Tparam_optional_default (_, expr) -> analyze_expr expr
         | Tparam_pat _ -> empty)
       params)

let rec analyze_function_body params body =
  let params = analyze_function_params params in
  let body =
    match body with
    | T.Tfunction_body expr -> analyze_named_body expr
    | T.Tfunction_cases { cases; _ } -> analyze_function_cases cases
  in
  merge params body

and analyze_named_body expr =
  match expr.T.exp_desc with
  | Texp_function (params, body) -> analyze_function_body params body
  | _ -> analyze_expr expr

let complexity expr = 1 + (analyze_named_body expr).total
let complexity_breakdown expr = analyze_named_body expr

let rec count_match_cases_expr expr =
  match expr.T.exp_desc with
  | Texp_function _ -> 0
  | Texp_match (scrutinee, computation_cases, value_cases, _) ->
      List.length computation_cases
      + List.length value_cases
      + count_match_cases_expr scrutinee
      + count_match_cases_cases computation_cases
      + count_match_cases_cases value_cases
  | Texp_ifthenelse (cond, then_expr, else_expr) ->
      count_match_cases_expr cond
      + count_match_cases_expr then_expr
      + Option.fold ~none:0 ~some:count_match_cases_expr else_expr
  | Texp_try (expr, value_cases, effect_cases) ->
      count_match_cases_expr expr
      + count_match_cases_cases value_cases
      + count_match_cases_cases effect_cases
  | Texp_let (_, bindings, body) ->
      List.fold_left
        (fun acc (vb : T.value_binding) ->
          acc
          +
          if is_function_expr vb.vb_expr then 0
          else count_match_cases_expr vb.vb_expr)
        (count_match_cases_expr body)
        bindings
  | Texp_sequence (lhs, rhs) ->
      count_match_cases_expr lhs + count_match_cases_expr rhs
  | Texp_apply (fn, args) ->
      count_match_cases_expr fn
      + List.fold_left
          (fun acc -> function
            | _, T.Arg expr -> acc + count_match_cases_expr expr
            | _, T.Omitted () -> acc)
          0 args
  | Texp_tuple fields ->
      List.fold_left
        (fun acc (_, expr) -> acc + count_match_cases_expr expr)
        0 fields
  | Texp_construct (_, _, args) | Texp_array (_, args) ->
      List.fold_left (fun acc expr -> acc + count_match_cases_expr expr) 0 args
  | Texp_record { fields; extended_expression; _ } ->
      Array.fold_left
        (fun acc field ->
          acc
          +
          match field with
          | _, T.Kept _ -> 0
          | _, T.Overridden (_, expr) -> count_match_cases_expr expr)
        (Option.fold ~none:0 ~some:count_match_cases_expr extended_expression)
        fields
  | Texp_atomic_loc (expr, _, _)
  | Texp_field (expr, _, _)
  | Texp_lazy expr
  | Texp_assert (expr, _) ->
      count_match_cases_expr expr
  | Texp_setfield (record, _, _, value) ->
      count_match_cases_expr record + count_match_cases_expr value
  | Texp_while (cond, body) ->
      count_match_cases_expr cond + count_match_cases_expr body
  | Texp_for (_, _, first, last, _, body) ->
      count_match_cases_expr first
      + count_match_cases_expr last
      + count_match_cases_expr body
  | Texp_struct_item ({ str_desc = Tstr_module mb; _ }, body) ->
      count_match_cases_module_expr mb.mb_expr + count_match_cases_expr body
  | Texp_struct_item (_, expr) -> count_match_cases_expr expr
  | Texp_letop { let_; ands; body; _ } ->
      count_match_cases_expr let_.bop_exp
      + List.fold_left
          (fun acc (op : T.binding_op) ->
            acc + count_match_cases_expr op.bop_exp)
          0 ands
      + count_match_cases_case body
  | Texp_variant (_, arg) ->
      Option.fold ~none:0 ~some:count_match_cases_expr arg
  | Texp_override (_, fields) ->
      List.fold_left
        (fun acc (_, _, expr) -> acc + count_match_cases_expr expr)
        0 fields
  | Texp_send (expr, _) | Texp_pack { mod_desc = Tmod_unpack (expr, _); _ } ->
      count_match_cases_expr expr
  | _ -> 0

and count_match_cases_case : type k. k T.case -> int =
 fun case ->
  Option.fold ~none:0 ~some:count_match_cases_expr case.c_guard
  + count_match_cases_expr case.c_rhs

and count_match_cases_cases : type k. k T.case list -> int =
 fun cases ->
  List.fold_left (fun acc case -> acc + count_match_cases_case case) 0 cases

and count_match_cases_module_expr module_expr =
  match module_expr.T.mod_desc with
  | Tmod_structure structure ->
      List.fold_left
        (fun acc item -> acc + count_match_cases_structure_item item)
        0 structure.str_items
  | Tmod_functor (_, body)
  | Tmod_constraint (body, _, _, _)
  | Tmod_apply (body, _, _)
  | Tmod_apply_unit body ->
      count_match_cases_module_expr body
  | Tmod_unpack (expr, _) -> count_match_cases_expr expr
  | Tmod_ident _ | Tmod_typed_hole -> 0

and count_match_cases_structure_item item =
  match item.T.str_desc with
  | Tstr_eval (expr, _) -> count_match_cases_expr expr
  | Tstr_value (_, bindings) ->
      List.fold_left
        (fun acc (vb : T.value_binding) ->
          acc
          +
          if is_function_expr vb.vb_expr then 0
          else count_match_cases_expr vb.vb_expr)
        0 bindings
  | Tstr_module mb -> count_match_cases_module_expr mb.mb_expr
  | Tstr_recmodule modules ->
      List.fold_left
        (fun acc (mb : T.module_binding) ->
          acc + count_match_cases_module_expr mb.mb_expr)
        0 modules
  | _ -> 0

let rec count_match_cases expr =
  match expr.T.exp_desc with
  | Texp_function (params, body) -> (
      let param_cases =
        List.fold_left
          (fun acc (param : T.function_param) ->
            match param.fp_kind with
            | Tparam_optional_default (_, expr) ->
                acc + count_match_cases_expr expr
            | Tparam_pat _ -> acc)
          0 params
      in
      param_cases
      +
      match body with
      | T.Tfunction_body expr -> count_match_cases expr
      | T.Tfunction_cases { cases; _ } ->
          List.length cases
          + List.fold_left
              (fun acc case -> acc + count_match_cases_case case)
              0 cases)
  | _ -> count_match_cases_expr expr

let rec trailing_record_fields_case : type k. k T.case -> int =
 fun case -> trailing_record_fields_expr case.c_rhs

and trailing_record_fields_expr expr =
  match expr.T.exp_desc with
  | Texp_record { fields; _ } -> Array.length fields
  | Texp_let (_, _, body) -> trailing_record_fields_expr body
  | Texp_letop { body; _ } -> trailing_record_fields_case body
  | Texp_sequence (_, rhs) -> trailing_record_fields_expr rhs
  | Texp_ifthenelse (_, then_expr, None) ->
      trailing_record_fields_expr then_expr
  | Texp_ifthenelse (_, _, Some else_expr) ->
      trailing_record_fields_expr else_expr
  | Texp_try (expr, _, _) -> trailing_record_fields_expr expr
  | Texp_function ([], T.Tfunction_body body) ->
      trailing_record_fields_expr body
  | Texp_struct_item (_, body) -> trailing_record_fields_expr body
  | Texp_construct (_, _, [ expr ]) | Texp_variant (_, Some expr) ->
      trailing_record_fields_expr expr
  | _ -> 0

let rec trailing_record_fields expr =
  match expr.T.exp_desc with
  | Texp_function (_, T.Tfunction_body body) -> trailing_record_fields body
  | _ -> trailing_record_fields_expr expr

let rec is_pure_data_expr expr =
  match expr.T.exp_desc with
  | Texp_construct (_, _, args) -> List.for_all is_pure_data_expr args
  | Texp_array (_, exprs) -> List.for_all is_pure_data_expr exprs
  | Texp_record { fields; extended_expression = None; _ } ->
      Array.length fields >= 3
      && Array.for_all
           (function
             | _, T.Kept _ -> true
             | _, T.Overridden (_, expr) -> is_pure_data_expr expr)
           fields
  | Texp_tuple fields ->
      List.for_all (fun (_, expr) -> is_pure_data_expr expr) fields
  | Texp_variant (_, arg) -> Option.fold ~none:true ~some:is_pure_data_expr arg
  | Texp_sequence (lhs, rhs) -> is_pure_data_expr lhs && is_pure_data_expr rhs
  | Texp_field (expr, _, _) -> is_pure_data_expr expr
  | Texp_constant _ | Texp_ident _ -> true
  | _ -> false

let record_field_exprs fields =
  Array.to_list fields
  |> List.filter_map (function
    | _, T.Kept _ -> None
    | _, T.Overridden (_, expr) -> Some expr)

let max_depth current_depth depths = List.fold_left max current_depth depths

let rec depth_expr ~in_closure current_depth expr =
  match expr.T.exp_desc with
  | Texp_ifthenelse (cond, then_expr, else_expr) ->
      let new_depth = current_depth + 1 in
      let d1 = depth_expr ~in_closure current_depth cond in
      let d2 = depth_expr ~in_closure new_depth then_expr in
      let d3 =
        match else_expr with
        | Some { exp_desc = Texp_ifthenelse _; _ } as nested ->
            Option.fold nested ~none:current_depth
              ~some:(depth_expr ~in_closure current_depth)
        | Some expr -> depth_expr ~in_closure new_depth expr
        | None -> new_depth
      in
      max (max d1 d2) d3
  | Texp_match (expr, computation_cases, value_cases, _) ->
      let new_depth = current_depth + 1 in
      let case_depths =
        List.map (depth_case ~in_closure new_depth) computation_cases
        @ List.map (depth_case ~in_closure new_depth) value_cases
      in
      List.fold_left max (depth_expr ~in_closure current_depth expr) case_depths
  | Texp_try (expr, value_cases, effect_cases) ->
      let new_depth = current_depth + 1 in
      let case_depths =
        List.map (depth_case ~in_closure new_depth) value_cases
        @ List.map (depth_case ~in_closure new_depth) effect_cases
      in
      List.fold_left max (depth_expr ~in_closure current_depth expr) case_depths
  | Texp_while (cond, body) ->
      let new_depth = current_depth + 1 in
      max
        (depth_expr ~in_closure current_depth cond)
        (depth_expr ~in_closure new_depth body)
  | Texp_for (_, _, first, last, _, body) ->
      let new_depth = current_depth + 1 in
      List.fold_left max new_depth
        [
          depth_expr ~in_closure current_depth first;
          depth_expr ~in_closure current_depth last;
          depth_expr ~in_closure new_depth body;
        ]
  | Texp_function _ -> current_depth
  | Texp_let (_, bindings, body) ->
      depth_let ~in_closure current_depth bindings body
  | Texp_sequence (lhs, rhs) -> depth_pair ~in_closure current_depth lhs rhs
  | Texp_apply (fn, args) -> depth_apply ~in_closure current_depth fn args
  | Texp_record { fields; extended_expression; _ } ->
      depth_record ~in_closure current_depth fields extended_expression
  | Texp_tuple fields ->
      List.fold_left max current_depth
        (List.map
           (fun (_, expr) -> depth_expr ~in_closure current_depth expr)
           fields)
  | Texp_construct (_, _, args) | Texp_array (_, args) ->
      List.fold_left max current_depth
        (List.map (depth_expr ~in_closure current_depth) args)
  | Texp_atomic_loc (expr, _, _)
  | Texp_field (expr, _, _)
  | Texp_lazy expr
  | Texp_assert (expr, _)
  | Texp_send (expr, _)
  | Texp_pack { mod_desc = Tmod_unpack (expr, _); _ } ->
      depth_expr ~in_closure current_depth expr
  | Texp_setfield (record, _, _, value) ->
      depth_pair ~in_closure current_depth record value
  | Texp_struct_item ({ str_desc = Tstr_module mb; _ }, body) ->
      max
        (depth_module_expr ~in_closure current_depth mb.mb_expr)
        (depth_expr ~in_closure current_depth body)
  | Texp_struct_item (_, expr) -> depth_expr ~in_closure current_depth expr
  | Texp_letop { let_; ands; body; _ } ->
      depth_letop ~in_closure current_depth let_ ands body
  | Texp_variant (_, arg) -> (
      match arg with
      | Some expr -> depth_expr ~in_closure current_depth expr
      | None -> current_depth)
  | Texp_override (_, fields) ->
      List.fold_left max current_depth
        (List.map
           (fun (_, _, expr) -> depth_expr ~in_closure current_depth expr)
           fields)
  | Texp_constant _ | Texp_ident _ | Texp_new _ | Texp_instvar _
  | Texp_setinstvar _ | Texp_object _ | Texp_pack _ | Texp_unreachable
  | Texp_extension_constructor _ | Texp_typed_hole ->
      current_depth

and depth_case : type k. in_closure:bool -> int -> k T.case -> int =
 fun ~in_closure current_depth case ->
  let guard =
    Option.fold ~none:current_depth
      ~some:(depth_expr ~in_closure current_depth)
      case.c_guard
  in
  max guard (depth_expr ~in_closure current_depth case.c_rhs)

and depth_pair ~in_closure current_depth lhs rhs =
  max
    (depth_expr ~in_closure current_depth lhs)
    (depth_expr ~in_closure current_depth rhs)

and depth_apply ~in_closure current_depth fn args =
  let arg_depths =
    List.map
      (function
        | _, T.Arg expr -> depth_expr ~in_closure current_depth expr
        | _, T.Omitted () -> current_depth)
      args
  in
  max_depth (depth_expr ~in_closure current_depth fn) arg_depths

and depth_letop ~in_closure current_depth let_ ands body =
  let binding_depths =
    depth_expr ~in_closure current_depth let_.T.bop_exp
    :: List.map
         (fun (op : T.binding_op) ->
           depth_expr ~in_closure current_depth op.bop_exp)
         ands
  in
  max_depth (depth_case ~in_closure current_depth body) binding_depths

and depth_let ~in_closure current_depth bindings body =
  let binding_depth =
    List.fold_left
      (fun acc (vb : T.value_binding) ->
        let depth =
          if is_function_expr vb.vb_expr then current_depth
          else depth_expr ~in_closure current_depth vb.vb_expr
        in
        max acc depth)
      current_depth bindings
  in
  max binding_depth (depth_expr ~in_closure current_depth body)

and depth_record ~in_closure current_depth fields extended_expression =
  let field_exprs = record_field_exprs fields in
  let depths =
    List.map (fun expr -> depth_expr ~in_closure current_depth expr) field_exprs
  in
  let depths =
    match extended_expression with
    | Some expr -> depth_expr ~in_closure current_depth expr :: depths
    | None -> depths
  in
  List.fold_left max current_depth depths

and depth_module_expr ~in_closure current_depth module_expr =
  match module_expr.T.mod_desc with
  | Tmod_structure structure ->
      List.fold_left max current_depth
        (List.map
           (depth_structure_item ~in_closure current_depth)
           structure.str_items)
  | Tmod_functor (_, body)
  | Tmod_constraint (body, _, _, _)
  | Tmod_apply (body, _, _) ->
      depth_module_expr ~in_closure current_depth body
  | Tmod_apply_unit body -> depth_module_expr ~in_closure current_depth body
  | Tmod_unpack (expr, _) -> depth_expr ~in_closure current_depth expr
  | Tmod_ident _ | Tmod_typed_hole -> current_depth

and depth_structure_item ~in_closure current_depth item =
  match item.T.str_desc with
  | Tstr_eval (expr, _) -> depth_expr ~in_closure current_depth expr
  | Tstr_value (_, bindings) ->
      List.fold_left max current_depth
        (List.map
           (fun (vb : T.value_binding) ->
             if is_function_expr vb.vb_expr then current_depth
             else depth_expr ~in_closure current_depth vb.vb_expr)
           bindings)
  | Tstr_module mb -> depth_module_expr ~in_closure current_depth mb.mb_expr
  | Tstr_recmodule modules ->
      List.fold_left max current_depth
        (List.map
           (fun (mb : T.module_binding) ->
             depth_module_expr ~in_closure current_depth mb.mb_expr)
           modules)
  | _ -> current_depth

let depth_function ~in_closure current_depth params body =
  let default_depths =
    List.map
      (fun (param : T.function_param) ->
        match param.fp_kind with
        | Tparam_optional_default (_, expr) ->
            depth_expr ~in_closure current_depth expr
        | Tparam_pat _ -> current_depth)
      params
  in
  let new_depth =
    if in_closure || current_depth > 0 then current_depth + 1 else current_depth
  in
  let body_depth =
    match body with
    | T.Tfunction_body body -> depth_expr ~in_closure:true new_depth body
    | T.Tfunction_cases { cases; _ } ->
        let match_depth = new_depth + 1 in
        List.fold_left max match_depth
          (List.map (depth_case ~in_closure:true match_depth) cases)
  in
  List.fold_left max body_depth default_depths

let nesting expr =
  match expr.T.exp_desc with
  | Texp_function (params, body) ->
      depth_function ~in_closure:false 0 params body
  | _ -> depth_expr ~in_closure:false 0 expr

let name_of_pattern (pat : T.pattern) =
  match pat.pat_desc with
  | Tpat_var (_, name, _) -> Some name.txt
  | Tpat_alias (_, _, name, _, _) -> Some name.txt
  | _ -> None

let of_binding (vb : T.value_binding) =
  Option.map
    (fun name ->
      {
        name;
        loc = vb.vb_loc;
        is_function = is_function_expr vb.vb_expr;
        complexity = complexity vb.vb_expr;
        complexity_breakdown = complexity_breakdown vb.vb_expr;
        nesting = nesting vb.vb_expr;
        match_cases = count_match_cases vb.vb_expr;
        trailing_record_fields = trailing_record_fields vb.vb_expr;
        pure_data = is_pure_data_expr vb.vb_expr;
      })
    (name_of_pattern vb.vb_pat)

let of_structure (structure : T.structure) =
  let values = ref [] in
  let push value = values := value :: !values in
  let rec process_structure_item item =
    match item.T.str_desc with
    | Tstr_value (_, bindings) ->
        List.filter_map of_binding bindings |> List.iter push
    | Tstr_module { mb_expr = { mod_desc = Tmod_structure structure; _ }; _ } ->
        List.iter process_structure_item structure.str_items
    | Tstr_recmodule modules ->
        List.iter
          (fun (mb : T.module_binding) ->
            match mb.mb_expr.mod_desc with
            | Tmod_structure structure ->
                List.iter process_structure_item structure.str_items
            | _ -> ())
          modules
    | _ -> ()
  in
  List.iter process_structure_item structure.str_items;
  List.rev !values

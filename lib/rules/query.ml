module T = Ocaml_typing.Typedtree
module Tast_iterator = Ocaml_typing.Tast_iterator

let clean_name_part s =
  match String.index_opt s '!' with None -> s | Some i -> String.sub s 0 i

let ends_with ~suffix path =
  let rec drop n xs =
    if n <= 0 then xs else match xs with [] -> [] | _ :: xs -> drop (n - 1) xs
  in
  let len = List.length path in
  let suffix_len = List.length suffix in
  len >= suffix_len && drop (len - suffix_len) path = suffix

module Path = struct
  let parts path =
    Ocaml_typing.Path.name path
    |> String.split_on_char '.'
    |> List.filter (fun s -> s <> "")
    |> List.map clean_name_part

  let ends_with path suffix = ends_with ~suffix (parts path)
end

module Longident = struct
  let parts lid = Ocaml_parsing.Longident.flatten lid
  let ends_with lid suffix = ends_with ~suffix (parts lid)
end

module Expr = struct
  let rec callee_parts expr =
    match expr.T.exp_desc with
    | Texp_ident (path, _, _) -> Some (Path.parts path)
    | Texp_apply (fn, _) -> callee_parts fn
    | Texp_construct (lid, _, _) -> Some (Longident.parts lid.txt)
    | Texp_open (_, inner) -> callee_parts inner
    | _ -> None

  let callee_ends_with expr suffix =
    match callee_parts expr with
    | None -> false
    | Some parts -> ends_with ~suffix parts

  let rec calls expr suffix =
    match expr.T.exp_desc with
    | Texp_apply ({ exp_desc = Texp_ident (path, _, _); _ }, _) ->
        Path.ends_with path suffix
    | Texp_apply ({ exp_desc = Texp_open (_, inner); _ }, _) ->
        calls inner suffix
    | Texp_open (_, inner) -> calls inner suffix
    | _ -> false

  let positional_args args =
    List.filter_map
      (function
        | Ocaml_parsing.Asttypes.Nolabel, T.Arg expr -> Some expr | _ -> None)
      args

  let rec application expr =
    match expr.T.exp_desc with
    | Texp_apply (fn, args) ->
        let head, previous_args = application fn in
        (head, previous_args @ positional_args args)
    | _ -> (expr, [])

  let last_positional_arg args =
    match List.rev (positional_args args) with
    | last :: _ -> Some last
    | [] -> None

  let string expr =
    match expr.T.exp_desc with
    | Texp_constant (Ocaml_parsing.Asttypes.Const_string (s, _, _)) -> Some s
    | _ -> None

  let rec body expr =
    match expr.T.exp_desc with
    | Texp_function (_, Tfunction_body inner) -> body inner
    | _ -> expr
end

module Pattern = struct
  let var_name (type k) (pat : k T.general_pattern) =
    match pat.pat_desc with Tpat_var (_, name, _) -> Some name.txt | _ -> None
end

let iter_expressions view f =
  match File_view.typedtree view with
  | Some (`Implementation structure) ->
      let iterator =
        {
          Tast_iterator.default_iterator with
          expr =
            (fun this expr ->
              f expr;
              Tast_iterator.default_iterator.expr this expr);
        }
      in
      iterator.structure iterator structure
  | Some (`Interface _) | None -> ()

let iter_value_bindings view f =
  match File_view.typedtree view with
  | Some (`Implementation structure) ->
      let iterator =
        {
          Tast_iterator.default_iterator with
          value_binding =
            (fun this vb ->
              f vb;
              Tast_iterator.default_iterator.value_binding this vb);
        }
      in
      iterator.structure iterator structure
  | Some (`Interface _) | None -> ()

let iter_structure_items view f =
  match File_view.typedtree view with
  | Some (`Implementation structure) -> List.iter f structure.str_items
  | Some (`Interface _) | None -> ()

let iter_signature_items view f =
  match File_view.typedtree view with
  | Some (`Interface signature) -> List.iter f signature.sig_items
  | Some (`Implementation _) | None -> ()

(** Shared detector for empty Alcotest / alcobar suites of the form
    [let suite = ("name", [])]. Used by E621 (test_ files) and E726 (fuzz_
    files), parameterised on the filename prefix. *)

module Issue_location = Location
open Ocaml_parsing

(* The empty list [[]] sometimes appears under an open: [Alcobar.[]],
   [List.[]], etc. The parser renders that as [Pexp_open _ (Pexp_construct
   "[]" None)], so we descend through opens to spot it. *)
let rec is_empty_list (expr : Parsetree.expression) =
  match expr.pexp_desc with
  | Pexp_construct ({ txt = Lident "[]"; _ }, None) -> true
  | Pexp_open (_, inner) -> is_empty_list inner
  | _ -> false

(** Walk [structure] for [let suite = ("name", body)] where [body] is the empty
    list. Returns the binding's location on a hit. *)
let find structure =
  List.find_map
    (fun (item : Parsetree.structure_item) ->
      match item.pstr_desc with
      | Pstr_value
          ( _,
            [
              {
                pvb_pat = { ppat_desc = Ppat_var { txt = "suite"; _ }; _ };
                pvb_expr;
                _;
              };
            ] ) -> (
          match pvb_expr.pexp_desc with
          | Pexp_tuple [ (_, _); (_, list_expr) ] ->
              if is_empty_list list_expr then Some pvb_expr.pexp_loc else None
          | _ -> None)
      | _ -> None)
    structure

(** [check ~prefix ~mk_payload ctx] is the rule body: only ML files whose
    basename starts with [<prefix>_] are considered; if their [suite] binding is
    empty, we yield an issue tagged with [mk_payload name] where [name] is the
    basename with the [<prefix>_] dropped. *)
let check ~prefix ~mk_payload (ctx : Context.file) =
  let filename = ctx.filename in
  let basename = Filename.basename filename in
  let prefix_us = prefix ^ "_" in
  if
    not
      (String.starts_with ~prefix:prefix_us basename && File_kind.is_ml basename)
  then []
  else
    match File_view.parsetree (Context.view ctx) with
    | None -> []
    | Some structure -> (
        match find structure with
        | None -> []
        | Some loc ->
            let suite_name =
              let fp = Fpath.v filename in
              Fpath.(fp |> rem_ext |> basename) |> fun s ->
              if String.starts_with ~prefix:prefix_us s then
                String.sub s (String.length prefix_us)
                  (String.length s - String.length prefix_us)
              else s
            in
            let loc =
              Issue_location.v ~file:filename ~start_line:loc.loc_start.pos_lnum
                ~start_col:0 ~end_line:loc.loc_start.pos_lnum ~end_col:80
            in
            [ Issue.v ~loc (mk_payload suite_name) ])

module T = Ocaml_typing.Typedtree

type binding = { loc : Location.t; name : string option; empty : bool }
type expected = Alcotest | Alcobar

let rec strip_open (expr : T.expression) =
  match expr.exp_desc with
  | Texp_open (_, inner) -> strip_open inner
  | _ -> expr

let constructor (expr : T.expression) =
  match (strip_open expr).exp_desc with
  | Texp_construct (lid, _, args) ->
      Some (Ocaml_parsing.Longident.flatten lid.txt, args)
  | _ -> None

let is_empty_list expr =
  match constructor expr with Some ([ "[]" ], []) -> true | _ -> false

(* The elements of a list literal, or [None] when the expression is not one.
   The distinction matters: [Some []] says "a list of no suites", which is what
   [let suite = []] is, while a [suite] built by a call has no elements to
   enumerate at all and must fall through to the single-pair reading. *)
let list_elements expr =
  let rec walk acc expr =
    match constructor expr with
    | Some ([ "[]" ], []) -> Some (List.rev acc)
    | Some ([ "::" ], [ head; tail ]) -> walk (head :: acc) tail
    | _ -> None
  in
  walk [] expr

let string_constant (expr : T.expression) =
  match expr.exp_desc with
  | Texp_constant (Ocaml_parsing.Asttypes.Const_string (s, _, _)) -> Some s
  | _ -> None

(* One [(name, cases)] pair, located at [loc]. *)
let pair ~loc (expr : T.expression) =
  match (strip_open expr).exp_desc with
  | Texp_tuple [ (None, name_expr); (None, list_expr) ] ->
      Some
        {
          loc;
          name = string_constant name_expr;
          empty = is_empty_list list_expr;
        }
  | _ -> None

(* A test module writes either one [(name, cases)] pair or a list of them, and
   the list carries a name and an emptiness per element. Each element is
   located at its own expression rather than at the whole [let], so a finding
   points at the entry it is about. *)
let binding_of_value ~filename (vb : T.value_binding) =
  match vb.vb_pat.pat_desc with
  | Tpat_var (_, name, _) when name.txt = "suite" -> (
      match list_elements vb.vb_expr with
      | Some elements ->
          List.filter_map
            (fun (element : T.expression) ->
              pair ~loc:(Loc.of_typed ~filename element.exp_loc) element)
            elements
      | None ->
          Option.to_list
            (pair ~loc:(Loc.of_typed ~filename vb.vb_loc) vb.vb_expr))
  | _ -> []

let bindings ~filename view =
  match File_view.typedtree view with
  | Some (`Implementation structure) ->
      List.concat_map
        (fun (item : T.structure_item) ->
          match item.str_desc with
          | Tstr_value (_, values) ->
              List.concat_map (binding_of_value ~filename) values
          | _ -> [])
        structure.str_items
  | Some (`Interface _) | None -> []

let empty ~filename view =
  bindings ~filename view
  |> List.find_map (fun binding ->
      if binding.empty then Some binding.loc else None)

let check_empty ~prefix ~mk_payload (ctx : Context.file) =
  let filename = Context.filename ctx in
  let basename = Filename.basename filename in
  let prefix_us = prefix ^ "_" in
  if
    not
      (String.starts_with ~prefix:prefix_us basename && File_kind.is_ml basename)
  then []
  else
    match empty ~filename (Context.view ctx) with
    | None -> []
    | Some loc ->
        let suite_name = Fpath.basename (Fpath.rem_ext (Fpath.v filename)) in
        let suite_name =
          if String.starts_with ~prefix:prefix_us suite_name then
            String.sub suite_name (String.length prefix_us)
              (String.length suite_name - String.length prefix_us)
          else suite_name
        in
        [ Issue.v ~loc (mk_payload suite_name) ]

(* Names that immediately precede a [.suite] reference in [view]'s resolved
   identifiers. [references] / [references_with_prefix] used to rebuild this
   set per query while walking the full identifier list; precomputing it
   once per view makes the per-module check a pair of cheap lookups. *)
type callers = {
  exact : (string, unit) Hashtbl.t;
      (** Caller names that match a candidate module exactly. *)
  wrapped : string list;
      (** Caller names that need the [__<module>] suffix check (dune-wrapped
          library modules). Typically a small fraction of [exact]. *)
}

let callers view =
  match File_view.resolved_identifiers view with
  | None -> None
  | Some refs ->
      let exact = Hashtbl.create 64 in
      let wrapped = ref [] in
      List.iter
        (fun ref_ ->
          let name = File_view.Reference.name ref_ in
          if File_view.Name.base name = "suite" then
            match List.rev (File_view.Name.prefix name) with
            | actual :: _ ->
                Hashtbl.replace exact actual ();
                if
                  let len = String.length actual in
                  let rec has_dunder i =
                    if i + 1 >= len then false
                    else if actual.[i] = '_' && actual.[i + 1] = '_' then true
                    else has_dunder (i + 1)
                  in
                  has_dunder 0
                then wrapped := actual :: !wrapped
            | [] -> ())
        refs;
      Some { exact; wrapped = !wrapped }

let references_in callers module_name =
  Hashtbl.mem callers.exact module_name
  || List.exists
       (fun actual -> String.ends_with ~suffix:("__" ^ module_name) actual)
       callers.wrapped

let missing_references view modules =
  match callers view with
  | None -> []
  | Some c -> List.filter (fun module_ -> not (references_in c module_)) modules

type 'a resolved = Unresolved | Resolved of 'a

let references view module_name =
  match callers view with
  | None -> Unresolved
  | Some c -> Resolved (references_in c module_name)

let references_with_prefix view ~prefix =
  match callers view with
  | None -> Unresolved
  | Some c ->
      Resolved
        (Hashtbl.fold
           (fun name () acc -> acc || String.starts_with ~prefix name)
           c.exact false)

let calls_test_case view =
  if not (File_view.is_resolved view) then Unresolved
  else
    Resolved
      (File_view.calls_path view [ "Alcobar"; "test_case" ]
      || File_view.calls_path view [ "Alcotest"; "test_case" ])

let expected_of_string = function
  | "string * unit Alcotest.test_case list" -> Some Alcotest
  | "string * Alcobar.test_case list" -> Some Alcobar
  | _ -> None

let string_type = File_view.Type_view.is_string
let unit_type = File_view.Type_view.is_unit
let list_type elem = File_view.Type_view.is_list ~elem

let alcotest_case_list =
  list_type (fun typ ->
      match File_view.Type_view.constr typ with
      | Some (name, [ arg ]) ->
          File_view.Name.equals_path name [ "Alcotest"; "test_case" ]
          && unit_type arg
      | _ -> false)

let alcobar_case_list =
  list_type (fun typ ->
      match File_view.Type_view.constr typ with
      | Some (name, []) ->
          File_view.Name.equals_path name [ "Alcobar"; "test_case" ]
      | _ -> false)

let expected_type expected ct =
  match File_view.Type_view.tuple ct with
  | Some [ name; cases ] -> (
      string_type name
      &&
      match expected with
      | Alcotest -> alcotest_case_list cases
      | Alcobar -> alcobar_case_list cases)
  | _ -> false

let is_value_suite expected item =
  File_view.Item.name item = "suite"
  &&
  match File_view.Item.type_sig item with
  | Some typ -> expected_type expected typ
  | None -> false

(* [expected] is parsed before the typedtree is consulted: an expectation this
   module cannot express is the caller's error, answerable without forcing the
   artefact. *)
let is_compliant_view ~expected view =
  match expected_of_string expected with
  | None -> Resolved false
  | Some expected -> (
      if not (File_view.is_resolved view) then Unresolved
      else
        match File_view.typed_items view with
        | [ item ] when File_view.Item.kind item = File_view.Item.Value ->
            Resolved (is_value_suite expected item)
        | _ -> Resolved false)

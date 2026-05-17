(** E219: [let rec ... and ...] groups that aren't mutually recursive.

    A [let rec f x = ... and g x = ...] binding group only needs the [and] chain
    when at least one binding actually references another binding in the group.
    When a binding in the chain references neither its siblings nor itself,
    [and] is misused -- the binding should be lifted to its own [let] above or
    below the group. *)

module T = Ocaml_typing.Typedtree
module Tast_iterator = Ocaml_typing.Tast_iterator

type kind =
  | Standalone_nonrec
      (** No references to siblings or self: [let name = ...]. *)
  | Standalone_rec  (** Self-recursive only: [let rec name = ...]. *)

type payload = { name : string; kind : kind; group : string list }

let pat_name pat = Query.Pattern.var_name pat

(** Collect every resolved identifier inside [expr] whose final path component
    is found in [names].

    The rule is about a local [let rec] group, so the relevant paths are local
    identifiers. A shadowed local with the same printed name still counts as a
    reference and may suppress an issue, which is a false negative rather than a
    false positive. *)
let collect_refs ~names expr =
  let found = ref [] in
  let add_path path =
    match List.rev (Query.Path.parts path) with
    | name :: _ when List.mem name names && not (List.mem name !found) ->
        found := name :: !found
    | _ -> ()
  in
  let iter =
    {
      Tast_iterator.default_iterator with
      expr =
        (fun this e ->
          (match e.T.exp_desc with
          | Texp_ident (path, _, _) -> add_path path
          | _ -> ());
          Tast_iterator.default_iterator.expr this e);
    }
  in
  iter.expr iter expr;
  !found

(** [reachable_from graph start] is the set of nodes reachable from [start] via
    one or more edges. The starting node is included only if it lies on a cycle.
*)
let reachable_from graph start =
  let visited = ref [] in
  let rec dfs n =
    let succs = try List.assoc n graph with Not_found -> [] in
    List.iter
      (fun m ->
        if not (List.mem m !visited) then begin
          visited := m :: !visited;
          dfs m
        end)
      succs
  in
  dfs start;
  !visited

(** Two nodes are in the same non-trivial SCC iff each is reachable from the
    other. We compute SCCs by checking, for each node [n], the intersection of
    [reachable_from n] with [{m | n in reachable_from m}]. Quadratic but
    operating on the small graphs typical of [let rec] groups (at most a handful
    of bindings). *)
let scc_of_node ~graph ~siblings node =
  let forward = reachable_from graph node in
  List.filter
    (fun other ->
      other <> node && List.mem other forward
      && List.mem node (reachable_from graph other))
    siblings

let classify_binding ~scc ~self_loop =
  if scc <> [] then `Mutually_recursive
  else if self_loop then `Standalone_rec
  else `Standalone_nonrec

let graph_of_named_bindings named =
  let names = List.map snd named in
  List.map
    (fun ((vb : T.value_binding), name) ->
      (name, collect_refs ~names vb.vb_expr))
    named

let classify_named_binding ~graph ~siblings name =
  let refs = try List.assoc name graph with Not_found -> [] in
  let scc = scc_of_node ~graph ~siblings name in
  classify_binding ~scc ~self_loop:(List.mem name refs)

let classify_group issues bindings =
  if List.length bindings >= 2 then
    let named =
      List.filter_map
        (fun (vb : T.value_binding) ->
          match pat_name vb.vb_pat with Some n -> Some (vb, n) | None -> None)
        bindings
    in
    if List.length named = List.length bindings then
      let siblings = List.map snd named in
      let graph = graph_of_named_bindings named in
      List.iter
        (fun ((vb : T.value_binding), name) ->
          match classify_named_binding ~graph ~siblings name with
          | `Mutually_recursive -> ()
          | `Standalone_rec ->
              issues :=
                (vb.vb_loc, { name; kind = Standalone_rec; group = siblings })
                :: !issues
          | `Standalone_nonrec ->
              issues :=
                (vb.vb_loc, { name; kind = Standalone_nonrec; group = siblings })
                :: !issues)
        named

(** Walk every top-level (and nested) structure looking for
    [Pstr_value (Recursive, bindings)] with at least two bindings whose patterns
    are [Ppat_var]. Returns a list of [(loc, name, kind, group_names)] for each
    misused [and]-binding. *)
let collect_misused_bindings view =
  let issues = ref [] in
  Query.iter_structure_items view (fun (item : T.structure_item) ->
      match item.str_desc with
      | Tstr_value (Recursive, bindings) -> classify_group issues bindings
      | _ -> ());
  Query.iter_expressions view (fun (expr : T.expression) ->
      match expr.exp_desc with
      | Texp_let (Recursive, bindings, _) -> classify_group issues bindings
      | _ -> ());
  List.rev !issues

let pp ppf { name; kind; group } =
  let group_str = String.concat ", " group in
  let suggestion =
    match kind with
    | Standalone_rec ->
        Fmt.str "extract [%s] from the [let rec %s] group as its own [let rec]"
          name group_str
    | Standalone_nonrec ->
        Fmt.str "extract [%s] from the [let rec %s] group as a plain [let]" name
          group_str
  in
  Fmt.pf ppf
    "[%s] is part of [let rec ... and ...] but isn't mutually recursive with \
     its siblings: %s"
    name suggestion

let check (ctx : Context.file) =
  let filename = ctx.filename in
  collect_misused_bindings (Context.view ctx)
  |> List.map (fun (loc, payload) ->
      Issue.v ~loc:(Loc.of_typed ~filename loc) payload)

let rule =
  Rule.v ~code:"E219" ~title:"Useless [and] in [let rec ... and ...] groups"
    ~category:Style_modernization
    ~hint:
      "A [let rec f and g and h] chain only needs the [and] when at least one \
       binding calls another binding in the group. When [h] references neither \
       [f] nor [g] (and isn't recursive itself), the [and] is just a coupling: \
       future readers assume the bindings are co-dependent. Lift the \
       standalone binding to its own [let] above or below the group. The same \
       applies inside expressions: [let rec ... and ... in body] follows the \
       same rule."
    ~examples:
      [
        {
          is_good = false;
          code =
            {|let rec is_even n = n = 0 || is_odd (n - 1)
and is_odd n = n <> 0 && is_even (n - 1)
and double x = x + x|};
        };
        {
          is_good = true;
          code =
            {|let double x = x + x

let rec is_even n = n = 0 || is_odd (n - 1)
and is_odd n = n <> 0 && is_even (n - 1)|};
        };
      ]
    ~pp (File check)

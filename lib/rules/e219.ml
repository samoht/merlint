(** E219: [let rec ... and ...] groups that aren't mutually recursive.

    A [let rec f x = ... and g x = ...] binding group only needs the [and] chain
    when at least one binding actually references another binding in the group.
    When a binding in the chain references neither its siblings nor itself,
    [and] is misused -- the binding should be lifted to its own [let] above or
    below the group. *)

type kind =
  | Standalone_nonrec
      (** No references to siblings or self: [let name = ...]. *)
  | Standalone_rec  (** Self-recursive only: [let rec name = ...]. *)

type payload = { name : string; kind : kind; group : string list }

let pat_name (pat : Parsetree.pattern) =
  match pat.ppat_desc with Ppat_var { txt; _ } -> Some txt | _ -> None

(** Collect every [Pexp_ident] inside [expr] whose [Longident] is an unqualified
    name found in [names]. We ignore shadowing: a local [let name = ...] inside
    the body still counts as a reference to the outer binding. The undercount
    this would cause flips the lint the safe way -- we'd see a self-shadowed
    identifier as "still referenced" and decline to flag, which is a false
    negative, never a false positive. *)
let collect_unqualified_refs ~names expr =
  let found = ref [] in
  let iter =
    {
      Ast_iterator.default_iterator with
      expr =
        (fun this e ->
          (match e.Parsetree.pexp_desc with
          | Pexp_ident { txt = Lident s; _ } when List.mem s names ->
              if not (List.mem s !found) then found := s :: !found
          | _ -> ());
          Ast_iterator.default_iterator.expr this e);
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
    (fun ((vb : Parsetree.value_binding), name) ->
      (name, collect_unqualified_refs ~names vb.pvb_expr))
    named

let classify_named_binding ~graph ~siblings name =
  let refs = try List.assoc name graph with Not_found -> [] in
  let scc = scc_of_node ~graph ~siblings name in
  classify_binding ~scc ~self_loop:(List.mem name refs)

(** Walk every top-level (and nested) structure looking for
    [Pstr_value (Recursive, bindings)] with at least two bindings whose patterns
    are [Ppat_var]. Returns a list of [(loc, name, kind, group_names)] for each
    misused [and]-binding. *)
let collect_misused_bindings structure =
  let issues = ref [] in
  let rec walk_item (item : Parsetree.structure_item) =
    match item.pstr_desc with
    | Pstr_value (Recursive, bindings) when List.length bindings >= 2 ->
        let named =
          List.filter_map
            (fun (vb : Parsetree.value_binding) ->
              match pat_name vb.pvb_pat with
              | Some n -> Some (vb, n)
              | None -> None)
            bindings
        in
        if List.length named = List.length bindings then (
          let siblings = List.map snd named in
          let graph = graph_of_named_bindings named in
          List.iter
            (fun ((vb : Parsetree.value_binding), name) ->
              match classify_named_binding ~graph ~siblings name with
              | `Mutually_recursive -> ()
              | `Standalone_rec ->
                  issues :=
                    ( vb.pvb_loc,
                      { name; kind = Standalone_rec; group = siblings } )
                    :: !issues
              | `Standalone_nonrec ->
                  issues :=
                    ( vb.pvb_loc,
                      { name; kind = Standalone_nonrec; group = siblings } )
                    :: !issues)
            named;
          List.iter (fun (vb, _) -> walk_expr vb.Parsetree.pvb_expr) named)
    | Pstr_value (_, bindings) ->
        List.iter (fun vb -> walk_expr vb.Parsetree.pvb_expr) bindings
    | Pstr_module mb -> walk_module_expr mb.pmb_expr
    | Pstr_recmodule mbs ->
        List.iter
          (fun (mb : Parsetree.module_binding) -> walk_module_expr mb.pmb_expr)
          mbs
    | _ -> ()
  and walk_module_expr (me : Parsetree.module_expr) =
    match me.pmod_desc with
    | Pmod_structure s -> List.iter walk_item s
    | _ -> ()
  and walk_expr expr =
    (* Nested [let rec ... and ...] inside an expression body. *)
    let iter =
      {
        Ast_iterator.default_iterator with
        expr =
          (fun this e ->
            (match e.Parsetree.pexp_desc with
            | Pexp_let (Recursive, bindings, _) when List.length bindings >= 2
              ->
                let named =
                  List.filter_map
                    (fun (vb : Parsetree.value_binding) ->
                      match pat_name vb.pvb_pat with
                      | Some n -> Some (vb, n)
                      | None -> None)
                    bindings
                in
                if List.length named = List.length bindings then
                  let siblings = List.map snd named in
                  let graph = graph_of_named_bindings named in
                  List.iter
                    (fun ((vb : Parsetree.value_binding), name) ->
                      match classify_named_binding ~graph ~siblings name with
                      | `Mutually_recursive -> ()
                      | `Standalone_rec ->
                          issues :=
                            ( vb.pvb_loc,
                              { name; kind = Standalone_rec; group = siblings }
                            )
                            :: !issues
                      | `Standalone_nonrec ->
                          issues :=
                            ( vb.pvb_loc,
                              {
                                name;
                                kind = Standalone_nonrec;
                                group = siblings;
                              } )
                            :: !issues)
                    named
            | _ -> ());
            Ast_iterator.default_iterator.expr this e);
      }
    in
    iter.expr iter expr
  in
  List.iter walk_item structure;
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
  let content = Context.content ctx in
  match Ast.parse_structure ~filename content with
  | None -> []
  | Some structure ->
      collect_misused_bindings structure
      |> List.map (fun (loc, payload) ->
          Issue.v ~loc:(Ast.merlint_of_loc ~filename loc) payload)

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

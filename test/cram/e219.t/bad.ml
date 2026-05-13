(* [scope_of] / [scope_in_items] don't recurse with siblings and should
   be plain [let]; [scope_in_item] is self-recursive only and should be
   its own [let rec]. None of the three needs to be in the same [and]
   chain. *)

type scope = { with_test : bool; with_doc : bool; build : bool }

let empty_scope = { with_test = false; with_doc = false; build = false }

let merge_scope a b =
  {
    with_test = a.with_test || b.with_test;
    with_doc = a.with_doc || b.with_doc;
    build = a.build || b.build;
  }

let rec scope_of v =
  match v with
  | `Option (_, constraints) -> scope_in_items constraints
  | _ -> empty_scope

and scope_in_items items =
  List.fold_left
    (fun acc item -> merge_scope acc (scope_in_item item))
    empty_scope items

and scope_in_item item =
  match item with
  | `Ident "with-test" -> { empty_scope with with_test = true }
  | `Ident "with-doc" -> { empty_scope with with_doc = true }
  | `Ident "build" -> { empty_scope with build = true }
  | `Logop (_, l, r) -> merge_scope (scope_in_item l) (scope_in_item r)
  | `Pfxop (_, inner) -> scope_in_item inner
  | _ -> empty_scope

(* A genuine mutual recursion: [is_even] and [is_odd] call each other.
   This must NOT be flagged. [double] sits in the same group but
   references neither sibling -- it must be flagged. *)
let rec is_even n = n = 0 || is_odd (n - 1)
and is_odd n = n <> 0 && is_even (n - 1)
and double x = x + x

let _ = (double, is_even, is_odd, scope_of)

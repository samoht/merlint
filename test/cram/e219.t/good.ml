(* Properly linearised: each binding gets the smallest [let] form it
   needs, and the only [and] chain contains genuinely mutually
   recursive bindings. *)

type scope = { with_test : bool; with_doc : bool; build : bool }

let empty_scope = { with_test = false; with_doc = false; build = false }

let merge_scope a b =
  {
    with_test = a.with_test || b.with_test;
    with_doc = a.with_doc || b.with_doc;
    build = a.build || b.build;
  }

let rec scope_in_item item =
  match item with
  | `Ident "with-test" -> { empty_scope with with_test = true }
  | `Ident "with-doc" -> { empty_scope with with_doc = true }
  | `Ident "build" -> { empty_scope with build = true }
  | `Logop (_, l, r) -> merge_scope (scope_in_item l) (scope_in_item r)
  | `Pfxop (_, inner) -> scope_in_item inner
  | _ -> empty_scope

let scope_in_items items =
  List.fold_left
    (fun acc item -> merge_scope acc (scope_in_item item))
    empty_scope items

let scope_of v =
  match v with
  | `Option (_, constraints) -> scope_in_items constraints
  | _ -> empty_scope

let double x = x + x

let rec is_even n = n = 0 || is_odd (n - 1)
and is_odd n = n <> 0 && is_even (n - 1)

let _ = (double, is_even, is_odd, scope_of)

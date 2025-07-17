(** Issue types and formatting *)

type 'a t = Issue of { location : Location.t option; data : 'a } | Disabled

let v ?loc data = Issue { location = loc; data }
let disabled () = Disabled
let location = function Disabled -> None | Issue i -> i.location

let compare a b =
  match (a, b) with
  | Disabled, Disabled -> 0
  | Disabled, _ -> 1
  | _, Disabled -> -1
  | Issue a, Issue b -> (
      (* Compare by location only since we can't access rule details *)
      match (a.location, b.location) with
      | Some la, Some lb -> Location.compare la lb
      | None, Some _ -> -1
      | Some _, None -> 1
      | None, None -> 0)

(* Pretty-printer - basic version without rule dependency *)
let pp pp_data ppf = function
  | Disabled -> Fmt.string ppf "(disabled)"
  | Issue i -> (
      match i.location with
      | None -> Fmt.pf ppf "(global) %a" pp_data i.data
      | Some loc -> Fmt.pf ppf "%a: %a" Location.pp loc pp_data i.data)

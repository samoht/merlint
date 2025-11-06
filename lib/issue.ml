(** Issue types and formatting *)

type 'a t = {
  location : Location.t option;
  data : 'a;
  severity : int; (* Higher = more severe, 0 = default *)
}

let v ?loc ?(severity = 0) data = { location = loc; data; severity }
let location t = t.location
let severity t = t.severity

let compare a b =
  (* Compare by severity first (descending), then by location *)
  match Int.compare b.severity a.severity with
  | 0 -> (
      match (a.location, b.location) with
      | Some la, Some lb -> Location.compare la lb
      | None, Some _ -> -1
      | Some _, None -> 1
      | None, None -> 0)
  | c -> c

(* Pretty-printer - basic version without rule dependency *)
let pp pp_data ppf t =
  match t.location with
  | None -> Fmt.pf ppf "(global) %a" pp_data t.data
  | Some loc -> Fmt.pf ppf "%a: %a" Location.pp loc pp_data t.data

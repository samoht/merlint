(** Issue types and formatting *)

type 'a t = { location : Location.t option; data : 'a }

let v ?loc data = { location = loc; data }
let location t = t.location

let compare a b =
  (* Compare by location only since we can't access rule details *)
  match (a.location, b.location) with
  | Some la, Some lb -> Location.compare la lb
  | None, Some _ -> -1
  | Some _, None -> 1
  | None, None -> 0

(* Pretty-printer - basic version without rule dependency *)
let pp pp_data ppf t =
  match t.location with
  | None -> Fmt.pf ppf "(global) %a" pp_data t.data
  | Some loc -> Fmt.pf ppf "%a: %a" Location.pp loc pp_data t.data

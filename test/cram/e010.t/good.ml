(* [else if] chains stay flat: each [else if] counts at the same level
   as the surrounding [if], so a guard cascade isn't penalised for
   reading as flat. *)
let classify x =
  if x < 0 then `Negative
  else if x = 0 then `Zero
  else if x < 10 then `Small
  else if x < 100 then `Medium
  else `Large

let process x y z =
  if x <= 0 || y <= 0 || z <= 0 then 0
  else if x >= 100 then 0
  else x + y + z

(* Record literals carrying inert data don't count as nesting -- only
   records whose fields contain closures or control flow do. *)
type point = { x : int; y : int; z : int }

let translate p dx dy dz = { x = p.x + dx; y = p.y + dy; z = p.z + dz }
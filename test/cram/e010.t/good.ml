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

(* Record literals carrying inert data don't count as nesting. *)
type point = { x : int; y : int; z : int }

let translate p dx dy dz = { x = p.x + dx; y = p.y + dy; z = p.z + dz }

(* A nested function literal is a separate control-flow body. Its body should
   not inflate the enclosing function's nesting depth. *)
type 'a visitor = { visit : 'a visitor -> 'a -> unit }

let collect xs =
  let acc = ref [] in
  let visitor =
    {
      visit =
        (fun _this x ->
          if x > 0 then
            if x > 10 then
              if x > 100 then acc := x :: !acc else ()
            else ()
          else ());
    }
  in
  List.iter (visitor.visit visitor) xs;
  !acc

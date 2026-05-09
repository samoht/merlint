let process x y z =
  if x > 0 then
    if y > 0 then
      if z > 0 then
        if x < 100 then
          x + y + z
        else 0
      else 0
    else 0
  else 0

(* The "heavy work in else" pattern: depth grows on the else side too,
   so a chain of three guards followed by a real else-block counts as
   nesting depth 4. *)
let classify_with_work x =
  if x < 0 then `Negative
  else
    let abs_x = abs x in
    if abs_x = 0 then `Zero
    else if abs_x < 10 then `Small
    else
      let bucket =
        if abs_x < 100 then `Medium
        else if abs_x < 1000 then `Large
        else `Huge
      in
      bucket
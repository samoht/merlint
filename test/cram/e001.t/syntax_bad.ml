let branchy x y z =
  if x then
    match y with
    | 0 -> if z then 1 else 2
    | 1 -> (
        try if z then 3 else 4 with
        | Failure _ -> 5
        | _ -> 6)
    | _ -> 7
  else 8

let guarded x y z =
  if (x && y) || z then
    while x && y do
      ignore z
    done
  else ()

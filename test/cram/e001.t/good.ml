let check_positive x = x > 0

let check_triangle x y z =
  x + y > z && y + z > x && x + z > y

let check_input x y z =
  if not (check_positive x && check_positive y && check_positive z) then
    "invalid"
  else if not (check_triangle x y z) then
    "invalid"
  else
    "valid"
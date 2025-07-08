(* Simple function with low complexity *)
let add x y = x + y

(* Function with moderate complexity *)
let classify_number n =
  if n = 0 then
    "zero"
  else if n > 0 then
    "positive"
  else
    "negative"
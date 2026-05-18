type transform =
  | None_
  | Translate of int * int option
  | Translate_x of int
  | Translate_y of int
  | Translate_z of int
  | Translate_3d of int * int * int
  | Rotate of int
  | Rotate_x of int
  | Rotate_y of int
  | Rotate_z of int
  | Rotate_3d of int * int * int * int
  | Rotate_axis of int * int * int * int
  | Scale of int
  | Scale_x of int
  | Scale_y of int
  | Scale_z of int
  | Skew_x of int
  | Skew_y of int
  | Matrix of int * int * int * int * int * int

type 'a printer = string -> 'a -> string

let pp_transform : transform printer =
 fun ctx -> function
  | None_ -> ctx ^ "none"
  | Translate (x, None) -> ctx ^ string_of_int x
  | Translate (x, Some y) -> ctx ^ string_of_int (x + y)
  | Translate_x x -> ctx ^ string_of_int x
  | Translate_y y -> ctx ^ string_of_int y
  | Translate_z z -> ctx ^ string_of_int z
  | Translate_3d (x, y, z) -> ctx ^ string_of_int (x + y + z)
  | Rotate a -> ctx ^ string_of_int a
  | Rotate_x a -> ctx ^ string_of_int a
  | Rotate_y a -> ctx ^ string_of_int a
  | Rotate_z a -> ctx ^ string_of_int a
  | Rotate_3d (x, y, z, a) -> ctx ^ string_of_int (x + y + z + a)
  | Rotate_axis (x, y, z, a) -> ctx ^ string_of_int (x + y + z + a)
  | Scale s -> ctx ^ string_of_int s
  | Scale_x x -> ctx ^ string_of_int x
  | Scale_y y -> ctx ^ string_of_int y
  | Scale_z z -> ctx ^ string_of_int z
  | Skew_x x -> ctx ^ string_of_int x
  | Skew_y y -> ctx ^ string_of_int y
  | Matrix (a, b, c, d, e, f) -> ctx ^ string_of_int (a + b + c + d + e + f)

let nested_function_does_not_inflate_outer xs =
  List.map
    (fun x ->
      if x > 0 then
        if x > 1 then
          if x > 2 then
            if x > 3 then x else x + 1
          else x + 2
        else x + 3
      else x + 4)
    xs

let simple_loop xs =
  let total = ref 0 in
  for i = 0 to List.length xs - 1 do
    total := !total + List.nth xs i
  done;
  !total

let flat_classifier n =
  if n < 0 then "negative"
  else if n = 0 then "zero"
  else if n < 10 then "small"
  else if n < 100 then "medium"
  else "large"

let match_with_classifier_fallback = function
  | `Named name -> name
  | `Code n ->
      if n >= 100 && n < 200 then "informational"
      else if n >= 200 && n < 300 then "success"
      else if n >= 300 && n < 400 then "redirection"
      else if n >= 400 && n < 500 then "client error"
      else if n >= 500 && n < 600 then "server error"
      else "unknown"

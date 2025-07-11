(* Function with deep nesting *)
let deeply_nested_function x =
  if x > 0 then
    if x > 1 then
      if x > 2 then
        if x > 3 then
          if x > 4 then
            if x > 5 then
              if x > 6 then
                x * 2
              else
                x * 3
            else
              x * 4
          else
            x * 5
        else
          x * 6
      else
        x * 7
    else
      x * 8
  else
    x * 9

(* Function with acceptable nesting *)
let normal_nesting x =
  if x > 0 then
    if x > 1 then
      x * 2
    else
      x * 3
  else
    x * 4
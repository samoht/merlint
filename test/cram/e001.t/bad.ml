let check_input x y z =
  if x > 0 then
    if y > 0 then
      if z > 0 then
        if x + y > z then
          if y + z > x then
            if x + z > y then
              "valid"
            else "invalid"
          else "invalid"
        else "invalid"
      else "invalid"
    else "invalid"
  else "invalid"
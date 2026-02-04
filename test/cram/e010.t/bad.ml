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
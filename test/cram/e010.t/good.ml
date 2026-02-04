let process x y z =
  if x <= 0 || y <= 0 || z <= 0 then 0
  else if x >= 100 then 0
  else x + y + z
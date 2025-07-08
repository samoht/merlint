let is_number s =
  try
    ignore (int_of_string s);
    true
  with _ -> false

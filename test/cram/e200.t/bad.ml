let contains_at s = 
  Str.string_match (Str.regexp ".*@.*") s 0
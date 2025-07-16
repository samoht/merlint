let contains_at s = 
  Stdlib.Str.string_match (Stdlib.Str.regexp ".*@.*") s 0
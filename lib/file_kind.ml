type t = Ml | Mli | Other

let of_filename f =
  let n = String.length f in
  if
    n >= 4
    && String.unsafe_get f (n - 4) = '.'
    && String.unsafe_get f (n - 3) = 'm'
    && String.unsafe_get f (n - 2) = 'l'
    && String.unsafe_get f (n - 1) = 'i'
  then Mli
  else if
    n >= 3
    && String.unsafe_get f (n - 3) = '.'
    && String.unsafe_get f (n - 2) = 'm'
    && String.unsafe_get f (n - 1) = 'l'
  then Ml
  else Other

let is_ml f = of_filename f = Ml
let is_mli f = of_filename f = Mli
let is_ml_or_mli f = of_filename f <> Other

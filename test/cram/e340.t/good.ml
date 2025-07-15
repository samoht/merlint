(* Define error helpers at the top of the file *)
let err_invalid x = Error (Fmt.str "Invalid data: %d" x)
let err_too_large n = Error (Fmt.str "Data too large: %d" n)

let process_data x =
  match x with
  | 0 -> err_invalid x
  | n -> 
      if n > 100 then
        err_too_large n
      else Ok n
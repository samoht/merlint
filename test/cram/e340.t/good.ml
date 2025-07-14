(* Define error helpers at the top of the file *)
let err_invalid x = Error (`Invalid x)
let err_fmt fmt = Fmt.kstr (fun msg -> Error (`Msg msg)) fmt

let process_data x =
  match x with
  | 0 -> err_invalid x
  | n -> 
      if n > 100 then
        err_fmt "Too large: %d" n
      else Ok n
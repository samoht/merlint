(* File with catch-all exception handler *)
let dangerous_function () =
  try failwith "something went wrong" with _ -> "caught"

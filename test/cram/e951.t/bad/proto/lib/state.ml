let handle (m : Message.t) =
  match m with Hello -> Ok () | _ -> Error "unexpected"

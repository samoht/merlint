let handle (m : Message.t) =
  match m with Hello -> Ok () | Bye -> Ok () | Data _ -> Error "unexpected"

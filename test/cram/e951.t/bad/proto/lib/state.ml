let handle (m : Message.t) (t : int) =
  match m with Hello -> Ok (t + 1) | _ -> Ok t

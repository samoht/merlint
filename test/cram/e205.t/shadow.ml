module Shadow = struct
  module Printf = struct
    let sprintf _ = ""
    let printf _ = ()
  end

  module Format = struct
    let asprintf _ = ""
  end
end

open Shadow

let message = Printf.sprintf "ok"
let () = Printf.printf "ok"
let formatted = Format.asprintf "ok"

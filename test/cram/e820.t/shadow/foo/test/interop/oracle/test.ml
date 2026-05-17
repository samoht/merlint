module Shadow = struct
  let open_in path = path
  let input_line line = line

  module String = struct
    let split_on_char _ line = [ line ]
  end
end

open Shadow

let parse path =
  let ic = open_in path in
  String.split_on_char ',' (input_line ic)

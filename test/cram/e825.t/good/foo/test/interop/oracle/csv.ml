module Field = struct
  let string = ()
end

module Row = struct
  let obj f = f
  let col _name _field ~enc:_ f = f
  let finish f = f
end

let of_file _codec _path = []

type 'a codec = unit

let string = ()

module Row = struct
  let obj _ = ()
  let col _ _ ~enc:_ _ = ()
  let finish _ = ()
end

let decode_file _ _ = Ok []

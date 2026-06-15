let dump x = Marshal.to_string x []
let load s : int = Marshal.from_string s 0
let save oc x = output_value oc x
let restore ic : int = input_value ic

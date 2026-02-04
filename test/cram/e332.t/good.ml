(* Good examples - using idiomatic 'v' constructor *)

module User = struct
  type t = { name : string; email : string }
  
  (* Idiomatic constructor *)
  let v name email = { name; email }
end

module Widget = struct
  type t = { id : int; label : string }
  
  (* Idiomatic constructor *)
  let v id label = { id; label }
  
  (* Other constructors can have descriptive names *)
  let parse_widget json = { id = 0; label = "" }  (* dummy *)
  let from_json json = parse_widget json
  let empty = { id = 0; label = "" }
end

module Config = struct
  type t = { host : string; port : int }
  
  (* Idiomatic constructor *)
  let v ~host ~port = { host; port }
  
  (* Specialized constructors are fine *)
  let default = { host = "localhost"; port = 8080 }
  let getenv _ = "dummy"
  let from_env () = { host = getenv "HOST"; port = int_of_string (getenv "PORT") }
end

(* At top-level, descriptive names are often better than 'v' *)
module Unix = struct
  type file_descr = int
  let socket = 0
end

type connection = { socket : Unix.file_descr }

let connection socket = { socket }
let connect ~host ~port = { socket = Unix.socket }
(* Bad examples - using create/make instead of v *)

module User = struct
  type t = { name : string; email : string }
  
  (* Should be 'v' *)
  let create name email = { name; email }
end

module Widget = struct
  type t = { id : int; label : string }
  
  (* Should be 'v' *)
  let make id label = { id; label }
end

module Config = struct
  type t = { host : string; port : int }
  
  (* Should be 'v' *)
  let create ~host ~port = { host; port }
end

(* At top-level, the rule flags create/make *)
module Unix = struct
  type file_descr = int
end

type connection = { socket : Unix.file_descr }

let create socket = { socket }
let make socket = { socket }

(* Note: The rule currently only catches top-level create/make functions.
   Module-level detection would require more context about module boundaries. *)
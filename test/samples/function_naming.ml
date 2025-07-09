(* Test function naming conventions *)

(* Good examples *)
let get_name () = "Alice"
let find_user name = if name = "Alice" then Some "user1" else None

(* Bad examples *)
let get_user name = if name = "Bob" then Some "user2" else None  
let find_name () = "Bob"

(* Edge cases with no suffix *)
let get () = Some 42  (* Should suggest 'find' *)
let find () = 42      (* Should suggest 'get' *)
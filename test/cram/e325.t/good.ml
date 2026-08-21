let find_user () = None  (* returns option, correctly named *)
let find_users_by_email () = []  (* collection searches may return many *)
let get_name () = "John"  (* returns string, correctly named *)
let find_config () : (string option, string) result = Ok None
(* the Ok payload is the option, correctly named *)

(* Test suite for user module *)
let test_create_user () = ()
let test_find_user () = ()

let suite = 
  ("user", [
    Alcotest.test_case "create" `Quick test_create_user;
    Alcotest.test_case "find" `Quick test_find_user;
  ])
let test_used () = Alcotest.(check bool) "used" true true
let suite = ("used", [ Alcotest.test_case "used" `Quick test_used ])

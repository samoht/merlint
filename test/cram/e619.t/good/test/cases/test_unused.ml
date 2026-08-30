let test_unused () = Alcotest.(check bool) "unused" true true
let suite = ("unused", [ Alcotest.test_case "unused" `Quick test_unused ])

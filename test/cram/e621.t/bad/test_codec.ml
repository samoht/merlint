(* A [suite] declared as a list: each element carries its own name and its own
   emptiness, and the finding must point at the empty element, not at the
   [let]. *)
let test_roundtrip () = ()

let suite =
  [
    ("codec", [ Alcotest.test_case "roundtrip" `Quick test_roundtrip ]);
    ("codec errors", []);
  ]

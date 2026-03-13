let test_roundtrip () = ()

let suite =
  ( "encoder",
    [ Alcotest.test_case "roundtrip" `Quick test_roundtrip ] )

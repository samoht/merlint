(* Imported-style suite in a non-mirroring directory: the module under test
   (Corelib.Gadget) lives in lib/core/, not test/legacy/, but it is a real
   module of a declared library, so E610 must not flag it. *)
let suite =
  ( "gadget",
    [
      Alcotest.test_case "answer" `Quick (fun () ->
          Alcotest.(check int) "answer" 42 Corelib.Gadget.answer);
    ] )

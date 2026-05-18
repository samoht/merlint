let test_longident_helpers () =
  let module Longident = Ocaml_parsing.Longident in
  let module Location = Ocaml_parsing.Location in
  let lid =
    Longident.Ldot
      (Location.mknoloc (Longident.Lident "Fmt"), Location.mknoloc "str")
  in
  Alcotest.(check (list string))
    "parts" [ "Fmt"; "str" ]
    (Merlint.Query.Longident.parts lid);
  Alcotest.(check bool)
    "ends with" true
    (Merlint.Query.Longident.ends_with lid [ "Fmt"; "str" ])

let suite =
  ("query", [ ("longident_helpers", `Quick, test_longident_helpers) ])

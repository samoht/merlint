open Merlint

let test_to_capitalized_snake_case () =
  let test input expected =
    let actual = Naming.to_capitalized_snake_case input in
    Alcotest.(check string)
      (Printf.sprintf "to_capitalized_snake_case %s" input)
      expected actual
  in

  (* Basic PascalCase conversions *)
  test "WaitingForInput" "Waiting_for_input";
  test "ProcessingData" "Processing_data";
  test "ErrorOccurred" "Error_occurred";

  (* Acronyms at start *)
  test "XMLParser" "XML_parser";
  test "HTMLElement" "HTML_element";
  test "OCaml" "OCaml";
  test "OCamlCompiler" "OCaml_compiler";

  (* Acronyms at end *)
  test "PartIII" "Part_III";
  test "ParseHTML" "Parse_HTML";
  test "ConvertToXML" "Convert_to_XML";

  (* Mixed cases *)
  test "HTTPSConnection" "HTTPS_connection";
  test "IOError" "IO_error";

  (* Value naming (should be all lowercase) *)
  test "getUserName" "get_user_name";
  test "myValue" "my_value";

  (* Already correct *)
  test "Already_correct" "Already_correct";
  test "Has_underscores" "Has_underscores";

  (* Edge cases *)
  test "A" "A";
  test "AB" "AB";
  test "ABC" "ABC";
  test "AbC" "Ab_C";
  test "ABc" "ABc"

let test_is_pascal_case () =
  let test input expected =
    let actual = Naming.is_pascal_case input in
    Alcotest.(check bool)
      (Printf.sprintf "is_pascal_case %s" input)
      expected actual
  in

  (* True cases *)
  test "PascalCase" true;
  test "XMLParser" true;
  test "A" true;
  test "ABC" true;
  test "AbC" true;

  (* False cases *)
  test "snake_case" false;
  test "Snake_case" false;
  test "camelCase" false;
  test "has_underscore" false;
  test "" false;
  test "123" false

let suite =
  [
    ("to_capitalized_snake_case", `Quick, test_to_capitalized_snake_case);
    ("is_pascal_case", `Quick, test_is_pascal_case);
  ]

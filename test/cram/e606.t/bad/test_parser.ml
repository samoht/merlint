let test_parse () = assert (Parser_lib.Parser.parse "42" = 42)

let () = test_parse ()
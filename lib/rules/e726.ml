(** E726: Empty Fuzz Suite *)

type payload = { suite_name : string }

let check =
  Empty_suite.check ~prefix:"fuzz" ~mk_payload:(fun suite_name ->
      { suite_name })

let pp ppf { suite_name } =
  Fmt.pf ppf
    "Fuzz suite '%s' is empty — add meaningful fuzz tests covering parsers, \
     encoders, state machines, and edge cases"
    suite_name

let rule =
  Rule.v ~code:"E726" ~title:"Empty Fuzz Suite" ~category:Testing
    ~hint:
      "An empty fuzz suite provides no coverage. Fuzz tests should: (1) test \
       crash safety of all parsers and decoders on arbitrary input, (2) verify \
       roundtrip invariants (decode(encode(x)) = x), (3) exercise state \
       machine transitions including invalid ones, (4) cover boundary \
       conditions and edge cases that unit tests miss. A suite with no test \
       cases will never find bugs."
    ~examples:
      [
        {
          is_good = false;
          code =
            {|let suite = ("parser", Alcobar.[])  (* no fuzz tests: bugs go undetected *)|};
        };
        {
          is_good = true;
          code =
            {|let suite =
  ( "parser",
    Alcobar.
      [
        test_case "parse crash safety" [ bytes ] test_parse;
        test_case "roundtrip" [ bytes ] test_roundtrip;
        test_case "boundary: empty input" [ const () ] test_empty;
      ] )|};
        };
      ]
    ~pp (File check)

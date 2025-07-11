let () =
  let test_str = "(test.ml[1,0+11]..test.ml[1,0+31])" in
  Printf.printf "Testing: %s\n\n" test_str;

  (* Test individual parts *)
  let parts =
    [
      ("Opening paren", Re.str "(");
      ( "Filename",
        Re.seq [ Re.str "("; Re.group (Re.rep1 (Re.compl [ Re.char '[' ])) ] );
      ( "First bracket",
        Re.seq [ Re.str "("; Re.rep1 (Re.compl [ Re.char '[' ]); Re.str "[" ] );
      ("Line number", Re.seq [ Re.str "["; Re.group (Re.rep1 Re.digit) ]);
      ( "Full location",
        Re.seq
          [
            Re.str "(";
            Re.rep1 (Re.compl [ Re.char '[' ]);
            Re.str "[";
            Re.rep1 Re.digit;
            Re.str ",";
            Re.rep1 Re.digit;
            Re.str "+";
            Re.rep1 Re.digit;
            Re.str "]";
          ] );
    ]
  in

  List.iter
    (fun (name, regex) ->
      Printf.printf "%s: " name;
      try
        let compiled = Re.compile regex in
        let _ = Re.exec compiled test_str in
        Printf.printf "✓ matches\n"
      with Not_found -> Printf.printf "✗ no match\n")
    parts;

  (* Now test if we can find the pattern "(test.ml[" *)
  Printf.printf "\nSearching for location pattern...\n";
  let contains_location =
    String.contains test_str '('
    && String.contains test_str '['
    && String.contains test_str ']'
  in
  Printf.printf "Contains location chars: %b\n" contains_location;

  (* Test if the issue is with ".." *)
  if String.contains test_str '.' then
    Printf.printf "Contains dots: yes (at positions: ";
  String.iteri (fun i c -> if c = '.' then Printf.printf "%d " i) test_str;
  Printf.printf ")\n"

let () =
  let test_str = "(test.ml[1,0+11]..test.ml[1,0+31])" in
  Printf.printf "Testing: %s\n\n" test_str;

  (* The exact regex from typedtree.ml *)
  let loc_regex =
    Re.compile
      (Re.seq
         [
           Re.str "(";
           Re.group (Re.rep1 (Re.compl [ Re.char '[' ]));
           Re.str "[";
           Re.group (Re.rep1 Re.digit);
           Re.str ",";
           Re.rep1 Re.digit;
           (* Don't capture this *)
           Re.str "+";
           Re.group (Re.rep1 Re.digit);
           Re.str "]..";
           Re.rep1 (Re.compl [ Re.char '[' ]);
           (* Second filename *)
           Re.str "[";
           Re.group (Re.rep1 Re.digit);
           Re.str ",";
           Re.rep1 Re.digit;
           (* Don't capture this *)
           Re.str "+";
           Re.group (Re.rep1 Re.digit);
           Re.str ")";
         ])
  in

  try
    let m = Re.exec loc_regex test_str in
    Printf.printf "Success! Matched\n";
    Printf.printf "Groups:\n";
    for i = 1 to 5 do
      Printf.printf "  Group %d: %s\n" i (Re.Group.get m i)
    done
  with Not_found ->
    Printf.printf "Failed to match\n";

    (* Try step by step to find where it fails *)
    let steps =
      [
        ( "Up to first ]",
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
        ( "Up to ..",
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
              Re.str "]..";
            ] );
        ( "Testing second filename part",
          Re.seq [ Re.str "].."; Re.rep1 (Re.compl [ Re.char '[' ]) ] );
      ]
    in

    Printf.printf "\nStep by step:\n";
    List.iter
      (fun (name, regex) ->
        Printf.printf "  %s: " name;
        try
          let compiled = Re.compile regex in
          let _ = Re.exec compiled test_str in
          Printf.printf "✓\n"
        with Not_found -> Printf.printf "✗\n")
      steps

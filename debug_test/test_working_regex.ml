let () =
  let test_str = "(test.ml[1,0+11]..test.ml[1,0+31])" in
  Printf.printf "Testing: %s\n\n" test_str;

  (* Try a different approach - capture everything we need *)
  let loc_regex =
    Re.compile
      (Re.Pcre.re
         "\\(([^\\[]+)\\[(\\d+),(\\d+)\\+(\\d+)\\]\\.\\.[^\\[]+\\[(\\d+),(\\d+)\\+(\\d+)\\]\\)")
  in

  Printf.printf "Using PCRE regex:\n";
  try
    let m = Re.exec loc_regex test_str in
    Printf.printf "Success!\n";
    Printf.printf "  File: %s\n" (Re.Group.get m 1);
    Printf.printf "  Start line: %s\n" (Re.Group.get m 2);
    Printf.printf "  Start char: %s\n" (Re.Group.get m 3);
    Printf.printf "  Start col: %s\n" (Re.Group.get m 4);
    Printf.printf "  End line: %s\n" (Re.Group.get m 5);
    Printf.printf "  End char: %s\n" (Re.Group.get m 6);
    Printf.printf "  End col: %s\n" (Re.Group.get m 7)
  with Not_found -> Printf.printf "Failed\n"

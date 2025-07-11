let () =
  (* Test the parse_location function directly by exposing it temporarily *)
  let module Typedtree = struct
    include Merlint.Typedtree

    (* Copy the parse_location function from typedtree.ml *)
    let parse_location str =
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
        let m = Re.exec loc_regex str in
        let file = Re.Group.get m 1 in
        let start_line = int_of_string (Re.Group.get m 2) in
        let start_col = int_of_string (Re.Group.get m 3) in
        let end_line = int_of_string (Re.Group.get m 4) in
        let end_col = int_of_string (Re.Group.get m 5) in
        Some
          (Merlint.Location.create ~file ~start_line ~start_col ~end_line
             ~end_col)
      with Not_found -> None
  end in
  (* Test location parsing *)
  let test_str = "expression (test.ml[1,0+11]..test.ml[1,0+31])" in
  Printf.printf "Testing location parsing on: %s\n" test_str;
  match Typedtree.parse_location test_str with
  | Some loc ->
      Printf.printf "Success! Location: %s\n"
        (Fmt.to_to_string Merlint.Location.pp loc)
  | None ->
      Printf.printf "Failed to parse location\n";

      (* Now test the full parsing *)
      let json =
        `String
          "expression (test.ml[1,0+11]..test.ml[1,0+31])\n\
          \  Texp_ident \"Stdlib!.Printf.printf\""
      in
      let result = Typedtree.of_json json in
      Printf.printf "\nFull parsing result:\n";
      Printf.printf "Identifiers: %d\n"
        (List.length result.Typedtree.identifiers);
      List.iter
        (fun id ->
          Printf.printf "  - %s (loc: %s)\n"
            (Typedtree.name_to_string id.Typedtree.name)
            (match id.Typedtree.location with
            | Some loc -> Fmt.to_to_string Merlint.Location.pp loc
            | None -> "None"))
        result.Typedtree.identifiers

let () =
  let content = "let dangerous = Obj.magic 42" in
  let temp_file = Filename.temp_file "debug" ".ml" in
  let oc = open_out temp_file in
  output_string oc content;
  close_out oc;

  match Merlint.Merlin.get_typedtree temp_file with
  | Ok typedtree ->
      Printf.printf "Identifiers found: %d\n"
        (List.length typedtree.Merlint.Typedtree.identifiers);
      List.iter
        (fun id -> Printf.printf "  - %s\n" id.Merlint.Typedtree.name)
        typedtree.Merlint.Typedtree.identifiers;
      Sys.remove temp_file
  | Error e ->
      Printf.printf "Error: %s\n" e;
      Sys.remove temp_file

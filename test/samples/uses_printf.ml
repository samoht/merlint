let test_printf () =
  Printf.printf "Hello %s\n" "world";
  Printf.sprintf "Number: %d" 42

let test_format () =
  Format.printf "Hello %s@." "world";
  Format.asprintf "%d items" 10
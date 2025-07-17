open Merlint

let () =
  let sexp_str =
    {|
(library
  ((name mylib)
   (local true)
   (modules
    ((impl (_build/default/lib/parser.ml))
     (intf (_build/default/lib/parser.mli))
     (impl (_build/default/lib/lexer.ml))))))|}
  in
  let sexp = Parsexp.Single.parse_string_exn sexp_str in
  Printf.printf "Parsed S-expression:\n%s\n\n"
    (Sexplib0.Sexp.to_string_hum sexp);
  let files = Dune.get_project_files sexp in
  Printf.printf "Extracted files: [%s]\n" (String.concat "; " files)

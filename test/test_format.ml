(* Since Format module requires file system access to check for .ocamlformat 
   and .mli files, we cannot create meaningful unit tests without file I/O *)

let suite = [ ("format", []) ]

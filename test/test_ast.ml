(* Tests for Ast: the parsetree of one source file, and the compiler-libs entry
   point every other parsetree-backed reader in merlint goes through. *)

open Alcotest

let interface = {|type t
(** The type for a value. *)

val v : int -> t
|}

let implementation = {|let answer = 42
|}

(* The extension decides which grammar the file is read with, and getting it
   wrong is not a parse error but a wrong tree: an implementation parsed as an
   interface would report every binding missing. *)
let test_kind_follows_the_extension () =
  (match Merlint.Ast.v ~filename:"lib.mli" ~content:interface with
  | Merlint.Ast.Interface items ->
      check int "interface items" 2 (List.length items)
  | Merlint.Ast.Implementation _ -> fail "an .mli parsed as an implementation");
  match Merlint.Ast.v ~filename:"lib.ml" ~content:implementation with
  | Merlint.Ast.Implementation items ->
      check int "implementation items" 1 (List.length items)
  | Merlint.Ast.Interface _ -> fail "an .ml parsed as an interface"

(* Source that does not parse declares nothing, which is what a source
   declaring nothing says too. A file caught mid-edit must not take the run
   down with it. *)
let test_unparseable_source_is_empty () =
  (match
     Merlint.Ast.v ~filename:"broken.mli" ~content:"val v : (** oops *) let"
   with
  | Merlint.Ast.Interface items -> check int "no items" 0 (List.length items)
  | Merlint.Ast.Implementation _ -> fail "an .mli parsed as an implementation");
  match Merlint.Ast.v ~filename:"broken.ml" ~content:"let = = =" with
  | Merlint.Ast.Implementation items ->
      check int "no items" 0 (List.length items)
  | Merlint.Ast.Interface _ -> fail "an .ml parsed as an interface"

(* A location taken from the tree has to name the file it came from, or a
   finding reported against it points nowhere. *)
let test_positions_name_the_file () =
  match Merlint.Ast.v ~filename:"lib.mli" ~content:interface with
  | Merlint.Ast.Implementation _ -> fail "an .mli parsed as an implementation"
  | Merlint.Ast.Interface (item :: _) ->
      check string "file" "lib.mli" item.psig_loc.loc_start.pos_fname;
      check int "line" 1 item.psig_loc.loc_start.pos_lnum
  | Merlint.Ast.Interface [] -> fail "the interface parsed to nothing"

(* Printing a tree renders it back as source, which is what makes a tree
   readable in a log at all. *)
let test_pp_renders_the_source () =
  let printed =
    Fmt.str "%a" Merlint.Ast.pp
      (Merlint.Ast.v ~filename:"lib.ml" ~content:implementation)
  in
  check bool "names the binding" true
    (Astring.String.is_infix ~affix:"answer" printed);
  check bool "prints its value" true
    (Astring.String.is_infix ~affix:"42" printed)

(* The lexer and the docstring collector are process-global, and merlint parses
   from an executor pool. Unserialised, two domains walking over each other's
   state trip the lexer's own assertion, and what survives is a tree with the
   comments on the wrong declarations. Every parse has to come back with the
   same answer as a parse on its own. *)
let test_concurrent_parses_agree () =
  let wrong = Atomic.make 0 in
  let run () =
    for _ = 1 to 200 do
      match Merlint.Ast.v ~filename:"lib.mli" ~content:interface with
      | Merlint.Ast.Interface items when List.length items = 2 -> ()
      | Merlint.Ast.Interface _ | Merlint.Ast.Implementation _ ->
          Atomic.incr wrong
      | exception _ -> Atomic.incr wrong
    done
  in
  let d1 = Domain.spawn run in
  let d2 = Domain.spawn run in
  Domain.join d1;
  Domain.join d2;
  check int "every parse read the same two declarations" 0 (Atomic.get wrong)

let suite =
  ( "ast",
    [
      test_case "kind follows the extension" `Quick
        test_kind_follows_the_extension;
      test_case "unparseable source is empty" `Quick
        test_unparseable_source_is_empty;
      test_case "positions name the file" `Quick test_positions_name_the_file;
      test_case "pp renders the source" `Quick test_pp_renders_the_source;
      test_case "concurrent parses agree" `Quick test_concurrent_parses_agree;
    ] )

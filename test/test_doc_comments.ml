(* Tests for Doc_comments: the doc comments a source attaches to its
   declarations, read from a parse of the source itself. *)

open Alcotest

let interface =
  {|(** The module's own documentation. *)

type t
(** The type for a value. *)

val v : int -> t
(** [v n] is the value carrying [n]. *)

val undocumented : t -> int

type level = Debug | Info | Error
(** The type for the severity of a log entry. *)
|}

let docs_of ~filename ~content =
  Merlint.Doc_comments.v ~filename (Merlint.Ast.v ~filename ~content)

let docs = lazy (docs_of ~filename:"lib.mli" ~content:interface)

(* Offsets of a declaration in [interface], found the way a caller finds them:
   from the span of the declaration itself. *)
let span affix =
  let n = String.length affix and m = String.length interface in
  let rec go i =
    if i + n > m then failf "fixture does not contain %S" affix
    else if String.sub interface i n = affix then (i, i + n)
    else go (i + 1)
  in
  go 0

let find affix =
  let start, stop = span affix in
  Merlint.Doc_comments.find (Lazy.force docs) ~start ~stop

let text affix =
  match find affix with
  | None -> failf "no doc comment attached to %S" affix
  | Some (c : Merlint.Doc_comments.comment) -> c.text

(* A doc comment written after a declaration documents that declaration, and is
   what the reader sees against it. *)
let test_doc_after_a_declaration () =
  check string "type" "The type for a value." (text "type t");
  check string "value" "[v n] is the value carrying [n]."
    (text "val v : int -> t")

(* A declaration with no doc comment has none. Reporting one here -- or
   reporting none for a documented declaration -- is what makes a documentation
   rule wrong, so both directions are pinned. *)
let test_declaration_without_a_doc () =
  check bool "no comment" true
    (Option.is_none (find "val undocumented : t -> int"))

(* The comment after the last constructor of a variant attaches to that
   constructor, not to the type: the type has no closing delimiter for it to
   bind past. That asymmetry is the whole of E425, so it is pinned here. *)
let test_comment_after_the_last_constructor () =
  (* The parser records a constructor's span from its leading [|], so that is
     the span a caller holding the declaration has to look it up by. *)
  check string "constructor" "The type for the severity of a log entry."
    (text "| Error");
  check bool "not the type" true
    (Option.is_none (find "type level = Debug | Info | Error"))

(* The comment's own location is what a rule reports, so it has to name where
   the comment is rather than where the declaration is. *)
let test_comment_location_is_the_comment () =
  match find "type t" with
  | None -> fail "no doc comment attached to the type"
  | Some (c : Merlint.Doc_comments.comment) ->
      check string "file" "lib.mli" c.loc.file;
      check int "line" 4 c.loc.start.line

(* A floating comment is a section header between declarations, not
   documentation of what follows it: the parser marks it [ocaml.text] and it
   must not be served as any declaration's doc. *)
let test_floating_comment_is_not_a_declaration_doc () =
  check bool "module doc is not the type's" true
    (text "type t" <> "The module's own documentation.")

(* Source that does not parse has no declarations to attach anything to. A file
   caught mid-edit is not an error, it simply has nothing to say. *)
let test_unparseable_source_has_no_docs () =
  let broken =
    docs_of ~filename:"broken.mli" ~content:"val v : (** oops *) let"
  in
  check bool "no comments" true
    (Option.is_none (Merlint.Doc_comments.find broken ~start:0 ~stop:5))

(* Implementations carry doc comments too, on their bindings. *)
let test_implementation_bindings () =
  let content = "let answer = 42\n(** The answer. *)\n" in
  let docs = docs_of ~filename:"lib.ml" ~content in
  let start, stop = (0, String.length "let answer = 42") in
  match Merlint.Doc_comments.find docs ~start ~stop with
  | None -> fail "no doc comment attached to the binding"
  | Some (c : Merlint.Doc_comments.comment) ->
      check string "text" "The answer." c.text

(* The lexer and the docstring collector are process-global, and merlint parses
   from an executor pool. Unserialised, two domains walking over each other's
   state trip the lexer's own assertion, and the doc comments that survive land
   on the wrong declarations -- which reads, to a documentation rule, as a
   source that documents nothing. Every parse has to come back with the same
   answer as a parse on its own. *)
let test_concurrent_parses_agree () =
  let start, stop = span "val v : int -> t" in
  let wrong = Atomic.make 0 in
  let run () =
    for _ = 1 to 200 do
      let t = docs_of ~filename:"lib.mli" ~content:interface in
      match Merlint.Doc_comments.find t ~start ~stop with
      | Some (c : Merlint.Doc_comments.comment)
        when c.text = "[v n] is the value carrying [n]." ->
          ()
      | Some _ | None -> Atomic.incr wrong
      | exception _ -> Atomic.incr wrong
    done
  in
  let d1 = Domain.spawn run in
  let d2 = Domain.spawn run in
  Domain.join d1;
  Domain.join d2;
  check int "every parse found the doc comment" 0 (Atomic.get wrong)

let suite =
  ( "doc_comments",
    [
      test_case "doc after a declaration" `Quick test_doc_after_a_declaration;
      test_case "declaration without a doc" `Quick
        test_declaration_without_a_doc;
      test_case "comment after the last constructor" `Quick
        test_comment_after_the_last_constructor;
      test_case "comment location is the comment" `Quick
        test_comment_location_is_the_comment;
      test_case "floating comment is not a declaration doc" `Quick
        test_floating_comment_is_not_a_declaration_doc;
      test_case "unparseable source has no docs" `Quick
        test_unparseable_source_has_no_docs;
      test_case "implementation bindings" `Quick test_implementation_bindings;
      test_case "concurrent parses agree" `Quick test_concurrent_parses_agree;
    ] )

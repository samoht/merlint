(* Bare [Parse], [Parsetree], [Lexer], [Docstrings] and [Syntaxerr] here are
   compiler-libs': this module deliberately does not [open Ocaml_parsing],
   because merlin's vendored lexer has docstring handling switched off and would
   return a parsetree with no doc comments in it at all. Everything merlint
   reads out of a parse -- the declarations and the comments written on them --
   therefore comes from this one. *)

type t =
  | Implementation of Parsetree.structure
  | Interface of Parsetree.signature

let pp ppf = function
  | Implementation structure -> Pprintast.structure ppf structure
  | Interface signature -> Pprintast.signature ppf signature

let empty ~interface = if interface then Interface [] else Implementation []

let v ~filename ~content =
  let interface = File_kind.is_mli filename in
  let lexbuf = Lexing.from_string content in
  lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = filename };
  (* The lexer and the docstring collector are process-global: the lexer keeps
     the comment it is inside and the buffer it is filling, the collector keeps
     the docstrings seen so far and which declaration they are waiting for. Two
     domains parsing at once walk over each other's -- the lexer trips its own
     assertion, and the doc comments that survive land on the wrong
     declarations. So a parse runs under the mutex every entry into
     compiler-libs runs under, and starts from a reset state. *)
  Merlin.Cl_lock.with_lock (fun () ->
      Lexer.init ();
      Docstrings.init ();
      (* Source that does not parse declares nothing this run can say anything
         about, which is the answer a source declaring nothing gives too: a file
         caught mid-edit is not a reason to fail. *)
      try
        if interface then Interface (Parse.interface lexbuf)
        else Implementation (Parse.implementation lexbuf)
      with Syntaxerr.Error _ | Lexer.Error _ -> empty ~interface)

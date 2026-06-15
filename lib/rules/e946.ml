(** E946: Protocol layering -- [codec.ml] must not depend on [Message].

    The ocaml-protocols layering is one-way [codec <- message]: [codec.ml] is
    the AST-free combinator base, and the message codecs are built from it in
    [message.ml] ([type t] decoders that reference [Codec]). A [codec.ml] that
    references its sibling [Message] inverts that order. This is the mirror of
    E945 (encodings, where [value.ml] is the base): a protocol's base layer is
    the Codec, an encoding's base layer is the Value/AST. Dependency order only;
    a separate parser/lexer engine is fine. *)

(* A reference to the sibling [Message] module, wrapped ([Lib__Message]) or
   user-visible. *)
let is_message_module m =
  m = "Message"
  ||
  let suffix = "__Message" in
  let lm = String.length m and ls = String.length suffix in
  lm >= ls && String.sub m (lm - ls) ls = suffix

(* Only the protocol shape -- a [codec.ml] paired with a sibling [message.ml] --
   is in scope; that pair is what makes Codec the AST-free base. An encoding's
   [codec.ml] (paired with [value.ml]) legitimately depends on the AST and is
   covered by E945 instead. *)
let check (ctx : Context.file) =
  let filename = Context.filename ctx in
  let has_message_sibling () =
    Sys.file_exists (Filename.concat (Filename.dirname filename) "message.ml")
  in
  if Filename.basename filename <> "codec.ml" || not (has_message_sibling ())
  then []
  else if
    List.exists is_message_module
      (File_view.referenced_module_names (Context.view ctx))
  then [ Issue.v ~loc:(Location.in_file filename) () ]
  else []

let pp ppf () =
  Fmt.pf ppf
    "codec.ml depends on Message, inverting the codec <- message layering. \
     Keep codec.ml the AST-free base and build the message codecs in \
     message.ml."

let rule =
  Rule.v ~code:"E946" ~title:"Protocol layering"
    ~category:Rule.Project_structure
    ~hint:
      "The ocaml-protocols layering is one-way codec <- message: codec.ml is \
       the AST-free combinator base and message.ml builds its codecs from it. \
       A codec.ml that references its sibling Message inverts that order. \
       Mirror of E945 (encodings, value is the base). Dependency order only."
    ~examples:[] ~pp (File check)

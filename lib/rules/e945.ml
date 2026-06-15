(** E945: Encoding layering -- [value.ml] must not depend on [Codec].

    The ocaml-encodings (jsont) dependency is one-way [codec -> value]:
    [codec.ml] holds [type value = Value.t] and builds the AST via the identity
    codec, so [value.ml] is the base layer. A [value.ml] referencing its sibling
    [Codec] inverts that order. Dependency order only -- a separate parser/lexer
    engine is fine. *)

(* A reference to the sibling [Codec] module. Dune may wrap it as [Lib__Codec];
   accept both the user-visible [Codec] and the wrapped form. *)
let is_codec_module m =
  m = "Codec"
  ||
  let suffix = "__Codec" in
  let lm = String.length m and ls = String.length suffix in
  lm >= ls && String.sub m (lm - ls) ls = suffix

(* Only the jsont shape -- a [value.ml] paired with a sibling [codec.ml] -- is
   in scope: that pair is what fixes the codec -> value order. *)
let check (ctx : Context.file) =
  let filename = Context.filename ctx in
  let has_codec_sibling () =
    Sys.file_exists (Filename.concat (Filename.dirname filename) "codec.ml")
  in
  if Filename.basename filename <> "value.ml" || not (has_codec_sibling ()) then
    []
  else if
    List.exists is_codec_module
      (File_view.referenced_module_names (Context.view ctx))
  then [ Issue.v ~loc:(Location.in_file filename) () ]
  else []

let pp ppf () =
  Fmt.pf ppf
    "value.ml depends on Codec, inverting the codec -> value layering. Keep \
     value.ml the base layer and move parse entry points out of it."

let rule =
  Rule.v ~code:"E945" ~title:"Encoding layering"
    ~category:Rule.Project_structure
    ~hint:
      "The ocaml-encodings layering is one-way codec -> value: codec.ml holds \
       [type value = Value.t]; value.ml is the base layer and must not depend \
       on Codec. Dependency order only -- a separate parser engine is fine."
    ~examples:[] ~pp (File check)

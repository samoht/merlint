(** E945: AST/codec layering -- the AST must not depend on [Codec].

    One layering for data codecs (ocaml-encodings) and wire protocols
    (ocaml-protocols). The AST module is the base, a plain data type: it is
    named [Value] for a data codec and [Message] for a protocol, but it plays
    the same role. [Codec] is the typed bidirectional codec; it depends on the
    AST (and is built on some parser/wire layer -- [core.ml], ocaml-wire,
    [parser.ml], an internal detail). The dependency runs codec -> AST, one way.

    An AST module ([value.ml] or [message.ml]) that references its sibling
    [Codec] inverts that order. A protocol is just a codec plus a state machine,
    so [message.ml] follows the same rule as [value.ml]. Dependency order only;
    which parser the codec is built on is unconstrained. *)

(* A path component naming a [Codec] module. Dune wraps a sibling as
   [Lib__Codec], so accept the bare and wrapped forms. *)
let is_codec_comp c =
  c = "Codec"
  ||
  let suffix = "__Codec" in
  let lc = String.length c and ls = String.length suffix in
  lc >= ls && String.sub c (lc - ls) ls = suffix

(* True when a resolved reference path targets the sibling [Codec] module rather
   than an external [Wire.Codec] (ocaml-wire's combinators, which the AST may use
   freely). We match a [Codec] component that is not nested directly under
   [Wire]; that distinguishes [Codec.x] / [Lib.Codec.x] / [Lib__Codec.x] (the
   sibling) from [Wire.Codec.x] (external). *)
let ref_targets_sibling_codec r =
  let path = File_view.Reference.prefix r @ [ File_view.Reference.base r ] in
  let rec scan prev = function
    | c :: rest ->
        if is_codec_comp c && prev <> Some "Wire" then true
        else scan (Some c) rest
    | [] -> false
  in
  scan None path

(* Typedtree reference categories that can carry a [Codec] reference: a value
   use ([Codec.encode]), a type ([Codec.t]), a module ([open Codec]), a
   constructor/field in a pattern, or a variant. *)
let references_sibling_codec view =
  let getters =
    [
      File_view.resolved_modules;
      File_view.resolved_identifiers;
      File_view.resolved_types;
      File_view.resolved_patterns;
      File_view.resolved_variants;
    ]
  in
  List.exists
    (fun get ->
      match get view with
      | None -> false
      | Some refs -> List.exists ref_targets_sibling_codec refs)
    getters

(* In scope: an AST module ([value.ml] or [message.ml]) paired with a sibling
   [codec.ml] -- the data-codec / protocol shape that fixes the codec -> AST
   order. *)
let check (ctx : Context.file) =
  let filename = Context.filename ctx in
  let base = Filename.basename filename in
  let is_ast = base = "value.ml" || base = "message.ml" in
  let has_codec_sibling () =
    Sys.file_exists (Filename.concat (Filename.dirname filename) "codec.ml")
  in
  if (not is_ast) || not (has_codec_sibling ()) then []
  else if references_sibling_codec (Context.view ctx) then
    [ Issue.v ~loc:(Location.in_file filename) () ]
  else []

let pp ppf () =
  Fmt.pf ppf
    "the AST (value.ml / message.ml) depends on Codec, inverting the codec -> \
     AST layering. The typed Codec depends on the AST, not the reverse; keep \
     the AST a plain data type and move parse entry points out of it."

let rule =
  Rule.v ~code:"E945" ~title:"AST/codec layering"
    ~category:Rule.Project_structure
    ~hint:
      "One layering for codecs and protocols: the AST (Value for data, Message \
       for a protocol) is the base, and the typed Codec depends on it -- never \
       the reverse. An AST module that references its sibling Codec inverts \
       the order. A protocol is a codec plus a state machine, so message.ml \
       follows the same rule. Dependency order only -- which parser the codec \
       uses is unconstrained."
    ~examples:[] ~pp (File check)

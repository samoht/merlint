(** E921: dune-promoted MDX error blocks must not appear in source files.

    When an mdx-tested code block fails and the user runs [dune promote], dune
    rewrites the source file to wrap the compiler error in a fenced block (in
    Markdown) or in an [err]-tagged odoc sub-block (inside a [.mli] doc
    comment). Those promotions belong in [.corrected] files for review, not in
    committed source. The presence of one means a broken example was accepted
    instead of fixed. *)

val rule : Rule.t
(** The E921 rule definition. *)

(** E920: documentation files with OCaml code blocks must be MDX-tested.

    A README.md, .mli or .mld file that contains an OCaml code block
    ([```ocaml ...```] in markdown, [{[ ... ]}] in odoc) should be listed in an
    [(mdx (files ...))] stanza in the same directory's [dune] file so the code
    is type-checked and run during [dune test]. Untested examples drift silently
    as the API evolves. *)

val rule : Rule.t
(** The E920 rule definition. *)

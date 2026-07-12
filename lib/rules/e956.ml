(** E956: Dead library dependency.

    A stanza's [(libraries ...)] entry is dead when no compilation unit of that
    library appears in the imports the compiler recorded in the stanza's [.cmt]
    artefacts. Matching happens on object names -- the linker-level unit
    identity -- so an internal [wire.ml] of a wrapped library [spy] is
    [Spy__Wire], never [Wire]: a doc-comment token or a source-basename
    collision with another library's entry module can neither hide a dead entry
    nor invent a live one. This is the artefact-backed replacement for
    text-based module-reference scans.

    Not flagged: stanzas with [-linkall] in [(link_flags ...)] (every dependent
    library links whole, so side-effect-only libraries are live); C-shipping
    libraries in stanzas with [(foreign_stubs ...)] (C code can reach their
    symbols without an OCaml import); virtual-library implementations
    ([(implements ...)] resolves at link time); builtin compiler-distributed
    libraries; libraries whose units are unknown (not indexed or not built). A
    stanza with a missing or stale [.cmt] for any of its sources is skipped
    rather than guessed at. *)

type payload = { stanza : string; library : string }

let pp ppf { stanza; library } =
  Fmt.pf ppf
    "%s is linked by stanza %s but never imported: no compilation unit of %s \
     appears in the stanza's .cmt imports. Remove it from (libraries ...)."
    library stanza library

let check (_ctx : Context.project) : payload Issue.t list =
  failwith "TODO: implement E956: dead library dependency"

let rule =
  Rule.v ~code:"E956" ~title:"Dead library dependency"
    ~hint:
      "A stanza's [(libraries ...)] entry is dead when no compilation unit of \
       that library appears in the imports the compiler recorded in the \
       stanza's [.cmt] files. Imports are matched by object name (an internal \
       [wire.ml] of library [spy] is [Spy__Wire], never [Wire]), so doc \
       comments and source-basename collisions cannot mask a dead entry. \
       Remove the entry or use the library. Stanzas with [-linkall], \
       C-shipping libraries under [(foreign_stubs ...)] stanzas, \
       virtual-library implementations, and stanzas with missing or stale \
       artefacts are not flagged."
    ~category:Rule.Project_structure ~examples:[] ~pp (Project check)

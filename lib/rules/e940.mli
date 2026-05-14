(** E940: Dune warnings flag missing

    The top-level [dune] file of every OCaml project (or each subtree in a
    monorepo) should enable the canonical warning set via
    [(env (dev (flags :standard %{dune-warnings})))]. Without it, projects lose
    the warnings expected by [merlint]'s code-quality rules. *)

val rule : Rule.t
(** [rule] is the E940 rule definition. *)

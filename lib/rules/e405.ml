(** E405: Missing Type Documentation *)

type payload = { reason : string }

let check (_ctx : Context.file) =
  (* TODO: E405 - Implement missing type documentation check
     This rule should check that public types have documentation.
     Currently not implemented. *)
  [
    Issue.v { reason = "Missing type documentation check not yet implemented" };
  ]

let pp ppf { reason } = Fmt.pf ppf "%s" reason

let rule =
  Rule.v ~code:"E405" ~title:"Missing Type Documentation"
    ~category:Documentation
    ~hint:
      "All public values should have documentation explaining their purpose \
       and usage. Add doc comments (** ... *) above value declarations in .mli \
       files."
    ~examples:
      [
        {
          is_good = true;
          code =
            {|(** User API

    This module provides types and functions for interacting with users. *)|};
        };
      ]
    ~pp (File check)

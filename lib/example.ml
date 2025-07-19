(** Helper functions for creating code examples *)

let good code = { Rule.is_good = true; code }
let bad code = { Rule.is_good = false; code }

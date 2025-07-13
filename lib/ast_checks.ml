(** AST-based checks that require deeper analysis than typedtree provides *)

(** Analyze a file for AST-based checks

    TODO: Implement proper AST traversal for E105 Catch_all_exception Currently
    disabled because our simplified parsetree module doesn't provide the full
    AST structure needed for this check.

    Options: 1. Add a merlin command to get the full parsetree 2. Use
    compiler-libs directly to parse the file 3. Enhance the parsetree module to
    include try-with information *)
let analyze_file _filename = []

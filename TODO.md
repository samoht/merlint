# TODO

## High Priority - New Rules to Implement

### Code Quality Rules
- [ ] **Excessive String.contains Detection**
  - Flag functions with multiple String.contains calls (code smell)
  - Suggest using Re module for pattern matching
  - Threshold: 3+ String.contains in a single function

- [ ] **ML File Documentation Style**
  - Discourage `(** *)` comments in .ml files except for module headers
  - Function docs in .ml should use `(* *)` and be implementation notes
  - Reserve `(** *)` for .mli files and module-level documentation

### Idiomatic OCaml Rules
- [ ] **E331: Missing Labels for Same-Type Parameters**
  - Functions with 2+ parameters of same type should use labels
  - Prevents argument order mistakes (e.g., `copy ~from ~to`)

- [ ] **E326: Redundant 'get_' Prefix**
  - Simple accessors shouldn't have `get_` prefix
  - Use `User.name` not `User.get_name`
  - Reserve `get_` for computations that always succeed

### Code Complexity Rules
- [ ] **Code Duplication Detection**
  - Find duplicated code blocks across the codebase
  - Use AST subtree similarity or token-based analysis
  - Suggest extracting common code into functions

## High Priority - Rule Improvements

### AST-Based Rule Conversions
- [ ] **E105: Catch-all Exception Handler**
  - Currently catches ALL `_` patterns, not just in try-with
  - Need AST traversal to find only Pexp_try nodes with Ppat_any

- [ ] **E340: Inline Error Construction**
  - Pattern `Error (Fmt.str ...)` detection not working
  - Needs AST analysis of constructor applications

- [ ] **E110: Silenced Warning**
  - Uses regex for `[@warning...]` attributes
  - Need proper attribute support in AST/dump module

- [ ] **E600/E610/E615: Test File Detection Improvements**
  - E600: Currently only checks "test.ml" files - should check all test executables
  - E610/E615: Still use brittle path heuristics (checking for "lib/" or "test/" in paths)
  - All should use Context.executable_modules and Context.test_modules like E505 does

## Medium Priority

### Configuration & Flexibility
- [ ] **E325: Function Naming Convention**
  - get_* vs find_* convention not universal
  - Should be configurable/optional

- [ ] **Add Configuration Support**
  - Allow customizing thresholds
  - Enable/disable specific rule categories
  - Per-project overrides

### Additional Rules
- [ ] **KISS Simplicity Rules**
  - E342: Limit function parameters (max 4-5)
  - E343: Flag complex boolean expressions
  - E345: No single-letter variables (except x/xs, i)
  - E348: No magic numbers

- [ ] **E352: Generic Label Detection**
  - Flag uninformative labels (~f, ~x, ~k)
  - Enforce descriptive API design

- [ ] **E620: Test Naming Conventions**
  - Test suite names: lowercase, single words
  - Test cases: lowercase with underscores

## Low Priority

### Infrastructure
- [ ] **Profiling Integration**
  - Module exists but collects no data
  - Add timing to engine.ml rule execution
  - Track time per file and per rule

### Documentation & Cleanup
- [ ] **Rule Helper Consolidation**
  - Move kind_to_string from e325.ml/e330.ml to Outline module
  - Standardize Dump.check_elements pattern usage
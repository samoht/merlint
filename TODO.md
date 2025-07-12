# TODO

## High Priority

- [ ] Implement E350 Boolean Blindness rule
  - Flag functions with 2+ boolean parameters
  - Suggest using variant types instead
  - Example: `create_widget bool -> bool -> t` → use visibility and border types
  - High impact for API clarity

- [ ] Implement E351 Mutable State Detection
  - Flag use of `ref`, `:=` operator, and `mutable` record fields
  - Enforce immutability-first principle
  - Allow suppression with [@warning "-mutable"] or similar
  - Should catch: `let counter = ref 0`, `type t = { mutable x : int }`

- [ ] Fix E105 Catch_all_exception to only detect exception handlers
  - Currently flags ANY underscore pattern, not just in try...with
  - Need to analyze AST context to identify exception handlers specifically
  - Should only flag patterns like `try ... with _ ->` not all uses of `_`

- [ ] Make E205 Printf_module less strict
  - Printf and Format are part of stdlib and widely used
  - Should be a suggestion/warning, not an error
  - Or make it configurable/opt-in

- [ ] Enforce 1:1 mapping between test files and library modules
  - Each lib/*.ml file should have a corresponding test/test_*.ml file
  - No extra test files without corresponding library modules
  - Tests for a feature should go in the test file for the module implementing it
  - Example: tests for E335 (underscore bindings) go in test_naming.ml since the check is in naming.ml

- [ ] Store configuration in .merlintrc or similar config file
  - Currently --rules flag is command-line only
  - Would be useful to have project-level configuration

## Medium Priority

- [ ] Make E415 Missing_standard_function more reasonable
  - Currently requires equal/compare/pp/to_string for ALL types
  - Should only apply to types exposed in .mli files
  - Or make it configurable per project

- [ ] Review E325 Function_naming (get_* vs find_*)
  - Convention is reasonable but not universal in OCaml
  - Standard library doesn't follow this strictly (List.find raises exception)
  - Should be optional/configurable

- [ ] Add missing rules that align with idiomatic OCaml
  - Labeled arguments: Functions with 3+ same-type parameters should use labels
  - Optional argument placement: Optional args should come before mandatory ones
  - No useless open: Avoid `open` when only using 1-2 values from a module

- [ ] Add KISS-derived rules for simplicity
  - E342: Limit function parameters (max 4-5, suggest using records)
  - E343: Flag complex boolean expressions (suggest extracting to named functions)
  - E345: No single-letter variable names (except common idioms like x/xs, i)
  - E348: No magic numbers (require named constants)

- [ ] Implement E352 Generic Label Detection
  - Flag uninformative labels like ~f, ~x, ~k
  - Enforce descriptive API design
  - Good: ~compare, ~initial_value, ~on_error
  - Bad: ~f, ~x, ~k, ~v

- [ ] Implement E353 Modern Concurrency Enforcement
  - Flag direct use of Unix module for concurrent operations
  - Suggest using Eio or Lwt instead
  - Similar to existing Str/Printf rules but for concurrency
  - Allow Unix for non-concurrent operations (file stats, env vars)

- [ ] Add documentation style section for E410
  - E410 exists in error codes but has no reference in style guides
  - Add section to lib/guide.ml explaining expected documentation style
  - Should explicitly reference [E410] for documentation style issues

- [ ] Implement E411: Docstring Format Convention
  - Enforce `[function_name arg1 arg2] is ...` pattern for function docs
  - Use regex to check docstrings in .mli files start with `[<name> ...] is`
  - Ensures consistent documentation style across codebase

- [ ] Add rule to catch Error patterns and suggest using err_* helper functions
  - Detect `Error (Fmt.str ...)` patterns in code  
  - Suggest creating specific error helper functions like `err_invalid_input`, `err_file_not_found`
  - Helper functions should be defined at the top of the file for better organization
  - This promotes consistent error handling and reduces code duplication

- [ ] Implement E510: Missing Log Source
  - Each module should define its own log source
  - Check that every .ml file contains at least one `Logs.Src.create` call
  - Ensures proper logging configuration per module

- [ ] Implement E620: Test Name Convention
  - Test suite names should be lowercase, single words
  - Test case names should be lowercase with underscores
  - Inspect string literals passed to `Alcotest.test_case` and suite names

- [ ] Implement E326: Redundant 'get_' Prefix
  - Simple accessors shouldn't have `get_` prefix (use `User.name` not `User.get_name`)
  - Reserve `get_` for functions with non-trivial computation that succeed
  - Flag `get_*` functions that are just simple record field access
  - Requires semantic analysis of function body

- [ ] Implement E331: Missing Labels for Same-Type Parameters
  - When a function has 2+ parameters of the same type, labels should be used
  - Prevents confusion and argument order mistakes (e.g., `copy ~from ~to`)
  - Check function signatures for multiple parameters with identical types
  - Suggest adding labels when this pattern is detected

## Low Priority

- [ ] Merge redundant testing guides
  - prompts/test.md and prompts/tests.md have overlapping content
  - Creates confusion about which is authoritative
  - Use prompts/tests.md as base (more detailed)

- [ ] Investigate why we have test_style_rules and test_rules_integration that don't correspond to any lib/*.ml files
  - These test files exist but don't follow the 1:1 correspondence rule
  - Decide if they should be renamed or excluded from the check


## Function Naming Convention Rule

Implement a rule to enforce function naming conventions:

- **`get_*`** - for functions that extract/retrieve something from an existing structure
  - Should return the value directly (not wrapped in option)
  - Example: `get_field record` returns `string`

- **`find_*`** - for functions that search for something that might not exist  
  - Should return an option type
  - Example: `find_user_by_id id` returns `user option`

### Implementation Notes

This requires Merlin integration for accurate type analysis:

1. **Use `ocamlmerlin single outline`** to get function signatures:
   ```bash
   echo "let get_user_by_id id = Some user" | ocamlmerlin single outline file.ml
   ```
   This gives us structured information about all functions, their names, and types.

2. **Use `ocamlmerlin single type-enclosing`** for precise type information:
   ```bash
   echo "let find_user id = None" | ocamlmerlin single type-enclosing -position 1:15 file.ml
   ```
   This can give us the exact return type of functions.

3. **Parse function signatures** to detect option return types:
   - Look for functions ending with `option` in their return type
   - Check if function names match the semantic convention

4. **Flag violations**:
   - `extract_*`, `locate_*`, `search_*` should be renamed to `get_*` or `find_*`
   - `get_*` functions returning option should be `find_*`
   - `find_*` functions not returning option should be `get_*`

### Current Status
- Issue type `Bad_function_naming` is defined and partially implemented
- Currently checks get_/find_ naming based on return types from outline
- Could be enhanced with more semantic analysis

### Integration with Existing Code
This would fit well with the existing `merlin_interface.ml` module:
- Add `get_outline` function similar to existing `analyze_file`
- Add `get_type_at_position` function for type queries
- Create new `naming_analysis.ml` module for function naming checks
- Call from `naming_rules.ml` alongside other naming checks

## Other Improvements

- Enhance catch-all exception detection with better AST parsing
- Add more comprehensive documentation rules
- Improve complexity analysis for more OCaml constructs
- Add configuration file support for customizing thresholds


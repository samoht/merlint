# TODO

## Recent Progress (2025-07-15)

### ✅ Completed: Major Rule Refactoring
- **[x] Reorganized all rule checks into individual files** in `lib/rules/` directory
  - Each rule now has its own `rules/exxx.ml` and `rules/exxx.mli` file
  - Used `include_subdirs unqualified` to integrate rules into main library
  - Each rule file exposes only `val check` function for clean interfaces

- **[x] Moved ALL rule implementations to dedicated modules:**
  - **E001** (Cyclomatic_complexity) - moved from complexity.ml to rules/e001.ml
  - **E005** (Function_too_long) - moved from complexity.ml to rules/e005.ml
  - **E010** (Deep_nesting) - moved from complexity.ml to rules/e010.ml
  - **E100** (Obj_magic) - moved from style.ml to rules/e100.ml  
  - **E105** (Catch_all_exception) - moved from style.ml to rules/e105.ml
  - **E110** (Silenced_warning) - moved from warning_checks.ml to rules/e110.ml
  - **E200** (Str_module) - moved from style.ml to rules/e200.ml
  - **E205** (Printf_module) - moved from style.ml to rules/e205.ml
  - **E300** (Variant_naming) - moved from naming.ml to rules/e300.ml
  - **E305** (Module_naming) - moved from naming.ml to rules/e305.ml
  - **E310** (Value_naming) - moved from naming.ml to rules/e310.ml
  - **E315** (Type_naming) - moved from naming.ml to rules/e315.ml
  - **E320** (Long_identifier) - moved from naming.ml to rules/e320.ml
  - **E325** (Function_naming) - moved from naming.ml to rules/e325.ml
  - **E330** (Redundant_module_name) - moved from naming.ml to rules/e330.ml
  - **E335** (Used_underscore_binding) - moved from naming.ml to rules/e335.ml
  - **E340** (Error_pattern) - moved from style.ml to rules/e340.ml
  - **E350** (Boolean_blindness) - moved from api_design.ml to rules/e350.ml
  - **E351** (Mutable_state) - moved from naming.ml to rules/e351.ml
  - **E400** (Missing_mli_doc) - moved from doc.ml to rules/e400.ml
  - **E500** (Missing_ocamlformat_file) - moved from format.ml to rules/e500.ml
  - **E505** (Missing_mli_file) - moved from format.ml to rules/e505.ml
  - **E600** (Test_exports_module) - moved from test_checks.ml to rules/e600.ml
  - **E605** (Missing_test_file) - moved from test_coverage.ml to rules/e605.ml
  - **E610** (Test_without_library) - moved from test_coverage.ml to rules/e610.ml
  - **E615** (Test_suite_not_included) - moved from test_coverage.ml to rules/e615.ml

- **[x] Created placeholder rules for unimplemented checks:**
  - **E405** (Missing_type_doc) - placeholder created, raises Disabled exception
  - **E410** (Missing_value_doc) - placeholder created, raises Disabled exception
  - **E415** (Missing_exception_doc) - placeholder created, raises Disabled exception
  - **E510** (Missing_log_source) - placeholder created, raises Disabled exception

- **[x] Created shared AST module** (`lib/ast.ml`) to eliminate code duplication
  - Extracted common functionality from parsetree.ml and typedtree.ml
  - Both modules now use `open Ast` for shared types and functions

- **[x] Removed file I/O from all unit tests**
  - Tests now use mock data structures instead of temporary files
  - All tests pass without requiring file system operations

- **[x] Cleaned up ALL legacy modules in lib/**
  - Converted all legacy modules to minimal stubs that delegate to rule modules:
    - `complexity.ml` - delegates to E001, E005, E010
    - `style.ml` - empty stub (all checks moved)
    - `api_design.ml` - empty stub (all checks moved)
    - `naming.ml` - delegates to E300, E305, E310, E315, E320, E325, E330, E335
    - `doc.ml` - delegates to E400
    - `format.ml` - delegates to E500, E505
    - `test_checks.ml` - delegates to E600
    - `test_coverage.ml` - delegates to E605, E610, E615
  - Removed warning_checks.ml entirely as requested
  - Updated rules.ml to use new rule modules directly

- **[x] Fixed critical build issues**
  - Resolved dependency cycles between modules
  - Fixed typedtree location parsing (was disabled, preventing rules from working)
  - Fixed E100 (Obj.magic) detection by enabling location extraction
  - Added proper exception handling for disabled rules
  - Fixed E005 to handle anonymous functions gracefully

### 📋 Next Steps
1. **Show disabled rules in statistics** as requested by user
2. **Implement proper complexity calculation** for E001 and E010
3. **Fix E105 to only detect exception handlers** not all underscore patterns
4. **Implement missing documentation rules** (E405, E410, E415)
5. **Implement missing log source rule** (E510)
6. **Fix function name extraction** in Browse module for better E005 output

## High Priority

- [x] Implement E350 Boolean Blindness rule
  - Flag functions with 2+ boolean parameters
  - Suggest using variant types instead
  - Example: `create_widget bool -> bool -> t` → use visibility and border types
  - High impact for API clarity

- [x] Implement E351 Mutable State Detection (partial, needs refinement)
  - ✓ Flag use of `ref` and `:=` operator
  - ✓ Updated documentation to clarify only global mutable state is problematic
  - TODO: Distinguish between global and local refs (requires scope analysis)
  - TODO: Detect `mutable` record fields (requires deeper AST analysis)
  - TODO: Detect array creation/mutation at global scope
  - Currently flags all refs, but should only flag module-level refs

- [ ] Fix E105 Catch_all_exception to only detect exception handlers
  - Currently the typedtree patterns don't provide enough context
  - Should only flag patterns like `try ... with _ ->` not all uses of `_`
  - Plan: Use Parsetree traversal with Ast_iterator
    1. Override the expression method to find Pexp_try nodes
    2. Check exception handler cases for Ppat_any patterns
    3. Only flag wildcard patterns within try...with expressions
    4. This avoids false positives for valid underscore uses
  - Implementation would go in lib/style.ml or new lib/ast_checks.ml

- [x] Make E205 Printf_module less strict
  - ✓ Changed title from "Outdated" to "Consider Using Fmt Module"
  - ✓ Description already acknowledges Printf/Format are valid choices
  - ✓ Priority is already medium (3), not highest
  - Rule is now properly framed as a style suggestion

- [x] Enforce 1:1 mapping between test files and library modules
  - ✓ Already implemented as E605 (Missing_test_file) and E610 (Test_without_library)
  - ✓ Checks that each lib/*.ml file has a corresponding test/test_*.ml file
  - ✓ Checks that test files have corresponding library modules
  - ✓ Uses dune describe to find modules accurately
  - Note: May not be showing in output due to dune describe parsing

- [x] Store configuration in .merlintrc or similar config file
  - ✓ Implemented config_file.ml to load .merlintrc files
  - ✓ Searches up directory tree for config file
  - ✓ Supports all existing configuration options
  - ✓ Created .merlintrc.example as documentation
  - ✓ Integrated with main.ml to load config automatically

- [ ] Add code duplication detection
  - Find duplicated code blocks across the codebase
  - Compare AST subtree similarities or use token-based analysis
  - State of the art: structural similarity, clone detection algorithms
  - Could use hash-based detection for exact duplicates
  - Or tree-edit distance for near-duplicates
  - Suggest extracting common code into functions

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

- [x] Add rule E340 to catch Error patterns and suggest using err_* helper functions (partial)
  - ✓ Added issue types and documentation  
  - ✓ Created infrastructure for detecting `Error (Fmt.str ...)` patterns
  - TODO: Current implementation needs deeper AST analysis to properly detect the pattern
  - Would need to analyze constructor applications with function calls as arguments
  - Typedtree doesn't provide enough context for this pattern

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

## Testing Gaps

### Summary of Testing Gaps

- **`lib/complexity.ml`**
  - Gaps: Complexity_exceeded, Deep_nesting
  - Reason: The tests use mock data that doesn't simulate high complexity or deep nesting, so these checks are never triggered

- **`lib/naming.ml`**
  - Gaps: Bad_variant_naming, Bad_function_naming, Redundant_module_name
  - Reason: The tests cover value, module, and type naming, but lack specific test cases for incorrect variant constructor names, get/find mismatches, or names that are redundant with the module name (e.g., My_module.my_module_do_thing)

- **`lib/doc.ml`**
  - Gaps: Missing_value_doc, Bad_doc_style
  - Reason: The existing tests only check for the presence of the main module-level docstring ((** ... *)). They do not check if individual vals are missing documentation or if the documentation follows the [f x] is... style

- **`lib/style.ml`**
  - Gaps: Error_pattern, Mutable_state
  - Reason: The tests cover Obj.magic, Str, Printf, and Catch_all_exception. However, there are no tests for the rule that discourages Error (Fmt.str ...) or the mutable state detection

- **`lib/api_design.ml`**
  - Status: Fully Tested
  - Reason: The tests in test/test_api_design.ml correctly and thoroughly check for the Boolean_blindness rule

- **`lib/format.ml`**
  - Gaps: Missing_ocamlformat_file, Missing_mli_file
  - Reason: The tests exist but are inconclusive. They rely on dune describe and file system operations that are not properly mocked, so they can't make specific assertions and instead just check that the functions run without crashing. The tests need to be rewritten with a mocked file system or a more controlled test project structure to be effective

- **`lib/test_checks.ml`**
  - Gap: Test_exports_module_name
  - Reason: There is no test/test_test_checks.ml file, and no other unit tests appear to cover the logic in this module

- **`lib/test_coverage.ml`**
  - Gaps: Missing_test_file, Test_without_library, Test_suite_not_included
  - Reason: There is no test/test_test_coverage.ml file. The logic, which depends heavily on the output of dune describe, is not unit-tested at all

## Broken Tests (Rules Not Detecting Issues)

As of 2025-07-15, these tests have bad.ml files that don't trigger their rules:

### Complexity Rules (not implemented)
- **E001** - High Cyclomatic Complexity: Always returns complexity of 1
- **E005** - Long Functions: May work but test functions might be too short
- **E010** - Deep Nesting: Always returns nesting depth of 0

### Naming Convention Rules (detection issues)
- **E300** - Variant Naming: Merlin may not provide variant info from type definitions
- **E305** - Module Naming: Module naming detection not working
- **E315** - Type Naming: Type naming detection not working  
- **E330** - Redundant Module Names: May not be detecting redundant prefixes correctly

### Documentation Rules (not implemented)
- **E405** - Missing Value Documentation: Rule not implemented
- **E410** - Documentation Style: Rule not implemented (should detect `(* *)` vs `(** *)`)
- **E415** - Missing Standard Functions: Rule not implemented

### Other Rules
- **E105** - Catch-all Exception: Too broad - catches ALL `_` patterns, not just in try-with
- **E340** - Inline Error Construction: Pattern detection not working
- **E510** - Missing Log Source: Rule not implemented
- **E600** - Test Module Convention: Only checks files named exactly "test.ml"
- **E605** - Missing Test File: Rule not fully implemented
- **E610** - Test Without Library: Rule not implemented
- **E615** - Test Suite Not Included: Rule not implemented

## Other Improvements

- Enhance catch-all exception detection with better AST parsing
- Add more comprehensive documentation rules
- Improve complexity analysis for more OCaml constructs
- Add configuration file support for customizing thresholds


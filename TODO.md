# TODO

## Current Work in Progress

### ✅ Recent Fixes
- [x] **Fixed Parser AST Analysis**
  - Fixed sibling-based AST structure parsing for if-then-else, match, try expressions
  - Implemented dialect switching for mixed Typedtree/Parsetree nodes (Tstr_attribute)
  - Parser now correctly handles AST structure for complexity analysis

### 🔄 Next High Priority Tasks
- [ ] **Fix Complexity Calculation in E001**
  - Parser now works correctly but complexity calculation needs adjustment
  - 14 cram tests expecting exit code [1] but getting [0]
  - Need to investigate why functions aren't being detected as complex
- [ ] **GADT Refactoring of Issue.t and Rule.t**
  - Step 1: Parameterize Issue.t by payload directly (remove Issue.data variant)
  - Steps 2&3 (merged): Introduce GADT in Rule.t with type-safe payload matching and rename format_issue to pp

### 📋 Missing Unit Tests
The following modules in `lib/` are missing corresponding unit tests in `test/`:
- [ ] `ast.ml` - Shared AST functionality
- [ ] `data.ml` - Rule data definitions
- [ ] `guide.ml` - Style guide generation
- [ ] `profiling.ml` - Performance profiling
- [ ] `rule.ml` - Rule type definitions

Note: Individual rule checks (`lib/rules/e*.ml`) are tested via cram tests, not unit tests.

## High Priority

- [ ] Improve E351 Mutable State Detection
  - Currently flags all refs, but should only flag module-level refs
  - TODO: Distinguish between global and local refs (requires scope analysis)
  - TODO: Detect `mutable` record fields (requires deeper AST analysis)
  - TODO: Detect array creation/mutation at global scope

- [ ] Fix E105 Catch_all_exception to only detect exception handlers
  - Currently the typedtree patterns don't provide enough context
  - Should only flag patterns like `try ... with _ ->` not all uses of `_`
  - Plan: Use Parsetree traversal with Ast_iterator
    1. Override the expression method to find Pexp_try nodes
    2. Check exception handler cases for Ppat_any patterns
    3. Only flag wildcard patterns within try...with expressions
    4. This avoids false positives for valid underscore uses
  - Implementation would go in lib/style.ml or new lib/ast_checks.ml

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

- [ ] Fix E340 Error pattern detection
  - Infrastructure exists but needs deeper AST analysis to properly detect the pattern
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

### Complexity Rules (partially fixed)
- **E001** - High Cyclomatic Complexity: Parser fixed but still needs function detection
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
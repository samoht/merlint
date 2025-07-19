# TODO

## Current Work in Progress

### 🔄 Next High Priority Tasks

- [ ] **Fix file discovery bug when using 'dune exec -- merlint -vv'**
  - Files are not being found properly when using `dune exec`
  - This is a serious bug affecting usability
  
- [ ] **Improve test/library file detection in E610 and related rules**
  - Currently using brittle heuristics (checking for "test"/"tests" or "lib"/"src" in paths)
  - Should use dune metadata to properly identify test executables/libraries
  - See TODO comments in lib/rules/e610.ml
  - This affects accuracy of E605, E610, and E615 rules
  
- [ ] **Refactor AST Analysis Architecture**
  1. [ ] Use Merlin outline for:
     - Function locations and boundaries (for E005 - function length)
     - Getting accurate line counts
  2. [ ] Use ppxlib on parsetree for:
     - Cyclomatic complexity analysis
     - Control flow detection
     - Name extraction (for naming convention rules)
  3. [ ] Use simple regex on typedtree text for:
     - Module usage detection (E100, E200, E205)
  4. [ ] Remove complex three-phase parser in lib/dump.ml
  5. [ ] Update rules to use appropriate analysis method

- [ ] **Refactor lib/dump.ml to Remove Code Duplication**
  1. [ ] Merge duplicate function extraction functions (`functions_from_value_binding` and `functions_from_bracket_node`)
  2. [ ] Consolidate expression extraction functions into a single unified function
  3. [ ] Create helper for extracting parsed names from quoted strings
  4. [ ] Create generic sibling extraction helper for expression patterns
  5. [ ] Add debug logging helper for what-to-string conversion
  6. [ ] Remove extract_ prefix from functions - use shorter, meaningful names that reflect what they read or build
  7. [ ] Simplify `process_tree` by grouping similar cases
  8. [ ] Remove `find_function_body` and use unified expression extraction
  9. [ ] Fix non-existent function call (`from_bracket_node` on line 309)
  10. [ ] Rename `what_to_string` to `pp_what`

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

- [ ] Fix E500 test setup - needs proper good case with .ocamlformat file
- [ ] Fix E605 test setup - needs separate project structures for good/bad cases

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

- [ ] Fix E340 Error pattern detection
  - Infrastructure exists but needs deeper AST analysis to properly detect the pattern
  - Would need to analyze constructor applications with function calls as arguments
  - Typedtree doesn't provide enough context for this pattern

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

## Testing Gaps

### Summary of Testing Gaps

- **`lib/complexity.ml`**
  - Gaps: Complexity_exceeded, Deep_nesting
  - Reason: The tests use mock data that doesn't simulate high complexity or deep nesting, so these checks are never triggered

- **`lib/naming.ml`**
  - Gaps: Bad_variant_naming, Bad_function_naming, Redundant_module_name
  - Reason: The tests cover value, module, and type naming, but lack specific test cases for incorrect variant constructor names, get/find mismatches, or names that are redundant with the module name (e.g., My_module.my_module_do_thing)

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

As of 2025-07-19, these tests have bad.ml files that don't trigger their rules:

### Complexity Rules (partially fixed)
- **E001** - High Cyclomatic Complexity: Parser fixed but still needs function detection
- **E005** - Long Functions: May work but test functions might be too short
- **E010** - Deep Nesting: Always returns nesting depth of 0

### Naming Convention Rules (detection issues)
- **E300** - Variant Naming: Merlin may not provide variant info from type definitions
- **E305** - Module Naming: Module naming detection not working
- **E315** - Type Naming: Type naming detection not working  
- **E330** - Redundant Module Names: May not be detecting redundant prefixes correctly

### Other Rules
- **E105** - Catch-all Exception: Too broad - catches ALL `_` patterns, not just in try-with
- **E340** - Inline Error Construction: Pattern detection not working
- **E600** - Test Module Convention: Only checks files named exactly "test.ml"
- **E605** - Missing Test File: Rule not fully implemented
- **E610** - Test Without Library: Rule not implemented

## Regex to Dump/AST Iterator Conversions

These rules currently use regex or text-based analysis and should be converted to use dump.mli iterators or AST analysis:

### High Priority Conversions
- [ ] **E105 (Catch-all Exception Handler)** - Currently uses regex to find `with _ ->`. Need to enhance AST/dump to detect exception handler patterns
- [ ] **E110 (Silenced Warning)** - Uses regex to find `[@warning...]`, `[@@warning...]`, `[@@@warning...]`. Need attribute support in dump module
- [ ] **E340 (Error Pattern Detection)** - Uses regex to find `Error (Fmt.str`. Need to analyze constructor applications with function calls
- [ ] **E351 (Global Mutable State)** - Uses regex on type signatures from outline to check for `ref` and `array`. Need better type analysis

### Medium Priority Conversions  
- [ ] **E400 (Missing MLI Documentation)** - Reads file content and checks if first non-empty line starts with `(**`. Could use dump for structure items
- [ ] **E600 (Test Module Convention)** - Partially converted but test.ml checking was accidentally removed. Need to properly handle both File and Project contexts

## Other Improvements

- Enhance catch-all exception detection with better AST parsing
- Add more comprehensive documentation rules
- Improve complexity analysis for more OCaml constructs
- Add configuration file support for customizing thresholds
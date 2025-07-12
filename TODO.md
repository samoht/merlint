# TODO

## High Priority

- [x] Detect when a function or type has the name of the module it belongs to
  - Examples: `Process.process*` or `History.find_history`
  - This is redundant naming and should be flagged as a style issue
  - Should work for functions, types, and module names
  - DONE: Implemented as E330 - Redundant Module Names

- [x] Implement Unified Style Guide Data Model
  1. **Create Data Model** (lib/data.ml and lib/data.mli)
     - Define OCaml types for style guide sections, paragraphs, rules
     - Include placeholders for rule references (e.g., [E205])
  2. **Migrate Content** 
     - Translate prompts/coding-style.md into OCaml data structures
     - Preserve all prose, examples, and structure
  3. **Implement Generators**
     - Update bin/generate_docs.ml to generate both:
       - docs/STYLE_GUIDE.md - Narrative "textbook" for learning
       - docs/error-codes.html - Quick reference "dictionary" 
     - Both generated from same source (lib/data.ml + lib/hints.ml)
  4. **Update Build System**
     - Update dune files to compile Data module
     - Add promotion rules for both generated files
  5. **Clean Up**
     - Remove prompts/coding-style.md after verification
     - This creates single source of truth for all style information

- [ ] Fix E305 Module Naming Convention documentation
  - Current docs say "Snake_case" but should be "lowercase_with_underscores"
  - Example should be `MyModule` → `my_module` not `My_module`
  - Update hints.ml and regenerate documentation

- [x] Allow to turn off some checks with CLI options
  - Added enhanced --rules flag supporting multiple formats:
    - Legacy format: A-E110-E205 (all except E110 and E205)
    - OCaml-style: "+all -110 -205" or "-100..199" for ranges
    - Selective: "+E300 +E305" to enable only specific checks
  - Implemented range support (e.g., -100..199 disables all security/safety checks)
  - TODO: Store configuration in .merlintrc or similar config file

## Medium Priority

- [x] Add a rule to detect _ prefixed variables
  - Variables prefixed with underscore indicate unused/ignored values
  - Should check if these variables are actually used in the code
  - If used, suggest removing the underscore prefix
  - Helps maintain clarity about which variables are intentionally unused
  - DONE: Implemented as E335 - Used Underscore-Prefixed Binding

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

- [x] Consolidate style guide documentation
  - Previously fragmented across prompts/code.md, test.md, tests.md
  - Created single STYLE_GUIDE.md generated from lib/guide.ml
  - Reduces risk of conflicting or incomplete advice

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
- Issue type `Bad_function_naming` is defined but not implemented
- Placeholder function exists that returns empty list
- Needs proper Merlin integration for type analysis

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

## Completed

- [x] Don't expect tests for dune-generated main modules
- [x] Use dune describe to list files in the project instead of scanning
- [x] Sort issues by severity/length
- [x] Give a unique identifier to each error type
- [x] Generate an HTML page with all the rules and their numbers
- [x] Implement rule to check that test files export 'suite' instead of module name
- [x] Implement rule to verify code doesn't silence warnings
- [x] Move sample files from samples/ to test/samples/
- [x] Fix test convention check to verify suite has proper Alcotest type
- [x] Optimize dune describe calls to run once per project, not once per file
- [x] Fix executable detection using parsexp instead of regex
- [x] Create test coverage check ensuring 1:1 correspondence between lib and test files
- [x] Use dune describe to find library modules instead of hardcoding paths
- [x] Create test files for core modules: complexity, doc, dune, format, issue, location
- [x] Create test files for: merlin, naming, report, rules, style, warning_checks modules
- [x] Add Test_parser and Test_sexp suites to test runner (commented out as modules don't exist)
- [x] Remove raw JSON from codebase and use structured types
- [x] Implement verbose logging (-v and -vv flags)
- [x] Fix various bugs in merlint OCaml linter
- [x] Refactor long functions and replace Printf with Fmt in test coverage module
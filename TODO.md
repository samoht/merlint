# TODO

## High Priority

- [x] Don't expect tests for dune-generated main modules
  - ~~Dune generates `<library>__.ml` files as entry points for wrapped libraries~~
  - ~~These should not require test files (e.g., `prune__.ml` should not require `test_prune__.ml`)~~
  - ~~Need to identify these from dune describe output and exclude them from test coverage checks~~
  - ~~Example error to fix: `prune__.ml:1:0: Module 'prune__' is missing test file 'test_prune__.ml'`~~
  - DONE: Filter out modules with .ml-gen suffix and modules ending with "__"

- [x] Use dune describe to list files in the project instead of scanning
  - ~~Currently we scan the filesystem directly, but dune describe can provide a more accurate list of project files~~
  - ~~Should respect dune's source tree configuration and exclusions~~
  - DONE: Implemented `Dune.get_project_files` that extracts source files from dune describe output

## Medium Priority

- [x] Sort issues by severity/length (longest functions first as most actionable)
  - ~~Currently issues are not sorted by severity~~
  - ~~Longest functions should appear first as they are the most actionable items to fix~~
  - ~~Sort by: function length (descending), then complexity, then other issues~~
  - DONE: Enhanced Issue.compare to sort by numeric severity within each priority level

- [ ] Detect when a function or type has the name of the module it belongs to
  - Examples: `Process.process*` or `History.find_history`
  - This is redundant naming and should be flagged as a style issue
  - Should work for functions, types, and module names

- [x] Give a unique identifier to each error type (with gaps for future additions)
  - ~~Each issue type should have a unique error code (e.g., E001, E005, E010)~~
  - ~~Leave gaps for future error types (e.g., E001-E099 for complexity, E100-E199 for style)~~
  - ~~Error messages should reference the error code~~
  - ~~Update Issue.t type to include error codes~~
  - DONE: Implemented categorized error codes E001-E699 with aligned display format

- [ ] Generate an HTML page with all the rules and their numbers
  - Create a static HTML page documenting all linting rules
  - Include error codes, descriptions, examples, and fix suggestions
  - Host on GitHub Pages for easy reference
  - Auto-generate from the issue type definitions

- [ ] Allow to turn off some checks with CLI options
  - Add CLI flags like `-w +all -32-27` to enable/disable specific checks
  - Similar to OCaml compiler warning flags
  - Support ranges (e.g., `-w -100..199` to disable all style checks)
  - Store configuration in .merlintrc or similar config file

- [ ] Add rule to catch Error patterns and suggest using err_* helper functions
  - Detect `Error (Fmt.str ...)` patterns in code  
  - Suggest creating specific error helper functions like `err_invalid_input`, `err_file_not_found`
  - Helper functions should be defined at the top of the file for better organization
  - This promotes consistent error handling and reduces code duplication

## Low Priority

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
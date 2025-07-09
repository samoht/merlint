# TODO

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
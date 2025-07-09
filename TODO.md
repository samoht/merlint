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

This requires proper typed tree analysis via Merlin to check return types:
- Use `ocamlmerlin single dump -what parsetree` to get parsed AST
- Use `ocamlmerlin single type-enclosing` to get type information
- Parse function signatures to detect option return types
- Flag violations:
  - `extract_*`, `locate_*`, `search_*` should be renamed to `get_*` or `find_*`
  - `get_*` functions returning option should be `find_*`
  - `find_*` functions not returning option should be `get_*`

### Current Status
- Issue type `Bad_function_naming` is defined but not implemented
- Placeholder function exists that returns empty list
- Needs proper Merlin integration for type analysis

## Other Improvements

- Enhance catch-all exception detection with better AST parsing
- Add more comprehensive documentation rules
- Improve complexity analysis for more OCaml constructs
- Add configuration file support for customizing thresholds
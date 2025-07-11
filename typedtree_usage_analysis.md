# Typedtree Usage Analysis

## Summary

After analyzing the codebase, I found that typedtree is primarily used for extracting identifiers and their locations. The data extracted from typedtree could potentially be provided by browse/parsetree, with some differences in structure and available information.

## What Data is Extracted from Typedtree

### 1. In `naming.ml`
The file uses typedtree to extract:
- **patterns**: For checking value naming conventions (snake_case)
- **modules**: For checking module naming conventions
- **types**: For checking type naming conventions
- **variants**: For checking variant constructor naming
- **identifiers**: For checking long identifier names (too many underscores)
- **location**: Location information for each element

Key usage:
```ocaml
let patterns = typedtree.Typedtree.patterns in
let modules = typedtree.Typedtree.modules in
let types = typedtree.Typedtree.types in
let variants = typedtree.Typedtree.variants in
let all_elts = typedtree.Typedtree.identifiers @ typedtree.Typedtree.patterns
    @ typedtree.Typedtree.modules @ typedtree.Typedtree.types
    @ typedtree.Typedtree.exceptions @ typedtree.Typedtree.variants
```

### 2. In `style.ml`
The file uses typedtree to extract:
- **identifiers**: To check for problematic patterns like:
  - `Stdlib.Obj.*` (Obj.magic usage)
  - `Stdlib.Str.*` (Str module usage)
  - `Stdlib.Printf.*` (Printf module usage)
  - `Stdlib.Format.*printf` (Format printf functions)
- **patterns**: To check for catch-all exception handlers (`_`)
- **location**: Location information for each element

Key usage:
```ocaml
check_typedtree ~identifiers:typedtree.identifiers ~patterns:typedtree.patterns
```

## Typedtree Data Structure

From `typedtree.mli`:
```ocaml
type name = {
  prefix : string list;  (* Module path, e.g., ["Stdlib"; "Obj"] *)
  base : string;         (* Base identifier, e.g., "magic" *)
}

type elt = { name : name; location : Location.t option }

type t = {
  identifiers : elt list;  (* Texp_ident: references to values/functions *)
  patterns : elt list;     (* Tpat_var: new value bindings *)
  modules : elt list;      (* Tstr_module: module definitions *)
  types : elt list;        (* Tstr_type: type definitions *)
  exceptions : elt list;   (* Tstr_exception: exception definitions *)
  variants : elt list;     (* Tpat_construct: variant constructors *)
}
```

## Available Alternatives

### 1. Parsetree
Already implemented as a fallback in `style.ml`. Provides:
- Same structure as typedtree
- Less type information (no "Stdlib" prefix resolution)
- Works when typedtree fails due to type errors

### 2. Outline
Provides high-level structure information:
- Function names and type signatures
- Module, type, exception definitions
- Location ranges
- Used in `naming.ml` for function naming checks and redundant module name detection

### 3. Browse
Provides detailed AST traversal information:
- Value bindings with pattern matching detection
- Function vs non-function detection
- Used in `complexity.ml` for complexity analysis

## Key Differences

1. **Type Resolution**: Typedtree resolves module paths (e.g., `["Stdlib"; "Obj"]`), while parsetree only has what's written in source (e.g., `["Obj"]`)

2. **Granularity**: Typedtree/Parsetree provide fine-grained AST node access, while Outline provides high-level definitions only

3. **Error Handling**: Typedtree fails on type errors, requiring fallback to parsetree

4. **Performance**: Browse/Outline might be faster for specific queries vs full AST parsing

## Conclusion

The usage of typedtree is not fundamentally different from what parsetree provides. The main advantage is type resolution for module paths. The codebase already implements a fallback pattern in `style.ml` that demonstrates parsetree can serve as a replacement with minor adjustments to handle the lack of full module path resolution.

Most naming checks could potentially use Outline data, while style checks primarily need identifier and pattern information that parsetree can provide.
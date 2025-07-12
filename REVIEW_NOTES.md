# Merlint Rules Review - Daniel Bünzli Style Perspective

## Critical Issues to Fix

### 1. E105 - Catch_all_exception is incorrectly implemented
**Current**: Flags any `_` pattern anywhere in code
**Should be**: Only flag `_` in exception handlers (`try...with _ ->`)
**Fix**: Need to analyze AST context to identify exception handlers specifically

### 2. E205 - Printf_module rule is too strict
**Current**: Forbids all uses of Printf/Format modules
**Should be**: 
- Str module warning is good (it's genuinely outdated)
- Printf/Format are part of stdlib and widely used (including by Daniel Bünzli)
- Suggest Fmt as an alternative but don't forbid Printf/Format
**Fix**: Downgrade to warning or make it opt-in

### 3. E320 - Long_identifier threshold too low
**Current**: Max 3 underscores
**Should be**: 4-5 underscores (some descriptive names need it)
**Fix**: Increase threshold or make it configurable

## Rules That Are Good As-Is

### Naming Conventions (Aligned with OCaml standards)
- **E300** Variant_naming: `MyVariant` → `My_variant` ✓
- **E305** Module_naming: `MyModule` → `My_module` ✓  
- **E310** Value_naming: `myValue` → `my_value` ✓
- **E315** Type_naming: `myType` → `my_type` ✓

### Safety Rules
- **E100** Obj_magic: Correctly warns against unsafe operations ✓
- **E110** Silenced_warning: Good to catch `[@warning "-..."]` ✓

### Documentation Rules  
- **E400** Missing_mli_doc: Good practice ✓
- **E505** Missing_mli_file: Good for library modules ✓

## Rules That Need Refinement

### E325 - Function_naming (get_* vs find_*)
- Convention is reasonable but not universal in OCaml
- Standard library doesn't follow this strictly
- Should be optional/configurable

### E415 - Missing_standard_function
- Requiring equal/compare/pp/to_string for ALL types is excessive
- Should only apply to types exposed in .mli files
- Or make it configurable per project

### E335 - Used_underscore_binding  
- Good in principle but might flag legitimate development patterns
- Consider allowing `_debug` or `_tmp` prefixes
- Or make severity configurable

## Missing Rules Daniel Bünzli Would Want

1. **Labeled arguments**: Functions with 3+ same-type parameters should use labels
2. **Optional argument placement**: Optional args should come before mandatory ones
3. **Documentation style**: First sentence = summary, use imperative mood
4. **No useless open**: Avoid `open` when only using 1-2 values from a module

## Recommendations

1. **Fix critical bugs** (Catch_all_exception, Printf strictness)
2. **Add configuration** for thresholds and rule severity
3. **Context awareness**: Different rules for test files vs library files
4. **Better error messages**: Explain WHY a pattern is discouraged
5. **Gradual adoption**: Allow projects to enable rules incrementally

## Example Configuration File
```ocaml
(* .merlintrc *)
{
  "rules": {
    "E205": "disabled",  (* Printf is fine *)
    "E320": { "threshold": 5 },  (* Allow longer identifiers *)
    "E325": "warning",  (* get/find is a suggestion *)
    "E415": { "only_public": true }  (* Only for .mli types *)
  },
  "exclude": [
    "test/**/*_test.ml"  (* Relax rules for tests *)
  ]
}
```
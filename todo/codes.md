# Error Code and Documentation Review

This document lists inconsistencies, gaps, and other issues found in the error code documentation (`docs/error-codes.html`) and the style guides (`prompts/*.md`).

## 1. Redundant Testing Guides

- **Issue**: There are two separate and overlapping testing guides: `prompts/test.md` and `prompts/tests.md`.
- **Gasps**:
    - This creates confusion about which guide is authoritative.
    - Maintaining two documents increases the risk of them becoming inconsistent over time.
- **Recommendation**: Merge the content of `prompts/test.md` and `prompts/tests.md` into a single, comprehensive testing guide. `prompts/tests.md` appears to be more detailed and could be used as the base.

## 2. Incorrect Module Naming Convention (E305)

- **Issue**: The description for error `E305` in `docs/error-codes.html` is inconsistent with the project's actual convention.
- **Mismatch**:
    - `docs/error-codes.html` states the convention is `Snake_case` and gives a confusing example (`MyModule` → `My_module`).
    - `prompts/code.md` and the project's file structure clearly show the convention is `lowercase_with_underscores` (e.g., `user_profile.ml`).
- **Recommendation**: Correct the `E305` entry in `docs/error-codes.html` to specify `lowercase_with_underscores` and provide a clear example (e.g., `MyModule` → `my_module`).

## 3. Missing Reference for E410

- **Issue**: Error code `E410` (Documentation Style Issues) is defined in `docs/error-codes.html` but is not referenced in any of the `prompts/` style guides.
- **Gasp**: Developers have no context or guidance on what constitutes a "documentation style issue" or how to avoid this error.
- **Recommendation**: Add a section to `prompts/code.md` that explains the expected documentation style and explicitly references `[E410]`.

## 4. Overlapping Style Guide Content

- **Issue**: The style guides in `prompts/` are fragmented. For example, rules about testing are split between `test.md` and `tests.md`, and general coding style is in `code.md`.
- **Inconsistency**: This fragmentation can lead to incomplete or conflicting advice, as seen with the naming conventions.
- **Recommendation**: Consider consolidating all style-related documentation into a single, authoritative `STYLE_GUIDE.md` to ensure consistency and make it easier for developers to find information.

## 5. Rules Without Error Codes

The following rules from the style guides do not have corresponding error codes. They are candidates for being automated by `merlint`.

### E411: Docstring Format Convention (Proposed)
- **Rule**: From `prompts/code.md`, "For functions, use the `[function_name arg1 arg2] is ...` pattern."
- **Mechanization**: A linter could use a regular expression to check that the docstring for a `val` in an `.mli` file starts with `[<name> ...] is`. This would enforce a consistent documentation style.

### E330: Discouraged Argument Label (Proposed)
- **Rule**: From `prompts/code.md`, "Avoid `~f` and `~x`."
- **Mechanization**: This is a straightforward AST check. The linter can flag any function definition or call that uses the labels `~f` or `~x`.

### E510: Missing Log Source (Proposed)
- **Rule**: From `prompts/code.md`, "Each module should define its own log source."
- **Mechanization**: The linter can enforce that every `.ml` file contains at least one call to `Logs.Src.create`. This ensures that logging is properly configured on a per-module basis.

### E620: Test Name Convention (Proposed)
- **Rule**: From `prompts/tests.md`, "Test suite names should be lowercase, single words... Test case names should be lowercase with underscores."
- **Mechanization**: The linter can inspect the string literals passed to `Alcotest.test_case` and the suite names in the exported `suite` value to enforce the naming convention.

### E326: Redundant 'get_' Prefix (Proposed)
- **Rule**: Refined from `E325`. Simple accessors should not have a `get_` prefix. The name of the property is sufficient (e.g., `User.name` instead of `User.get_name`). The `get_` prefix should be reserved for functions that perform a non-trivial computation but are still guaranteed to succeed.
- **Mechanization**: The linter can flag functions named `get_*` where the implementation is a simple record field access. This would require semantic analysis of the function body.

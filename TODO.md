# TODO

## Architecture Improvements

### Use ppxlib for AST analysis
Currently, merlint uses Merlin's text/JSON output for AST analysis, which requires:
- Complex regex parsing
- Text manipulation to extract locations
- Fragile pattern matching on string representations

Migrating to ppxlib would provide:
- Proper typed AST traversal
- More robust and maintainable code
- Better performance
- Accurate pattern matching without false positives
- Direct access to location information

This would particularly improve:
- Catch-all exception detection (avoid false positives)
- Pattern matching analysis
- More sophisticated code analysis rules

## Features to Add

### From prompts/test.md
- Add rules from prompts/test.md to the analysis
- Detect "similar" functions or expressions
- Check we don't use String.contains for complex string manipulations

### Suppression Comments
- Add support for suppressing specific warnings with comments
- Example: `(* merlint-disable-next-line catch-all *)`

### Configuration File
- Add support for .merlint.json or .merlintrc configuration
- Allow customizing thresholds (complexity, line length, etc.)
- Enable/disable specific rules
- Configure exclusion patterns

### Better Error Messages
- Include suggestions for fixing issues
- Show code snippets with issues highlighted
- Provide links to documentation

## Bug Fixes

### Catch-all Detection Line Numbers
- Fix incorrect line number reporting for catch-all exceptions
- Currently reports the line of the `try` instead of the `with _ ->`

### Multiple Catch-all Detection
- Detect all catch-all patterns in a file, not just the first one
Test simple functions with low complexity
  $ merlint samples/simple.ml

Test function with high cyclomatic complexity
  $ merlint samples/complex.ml
  complex.ml:4:4: Avoid catch-all exception handler
  complex.ml:8:0: Function 'process_command' has cyclomatic complexity of 14 (threshold: 10)
  [1]

Test long function detection
  $ merlint samples/long_function.ml
  long_function.ml:2:0: Function 'very_long_function' is 54 lines long (threshold: 50)
  [1]

Test naming conventions
  $ merlint samples/bad_names.ml

Test documentation rules
  $ merlint samples/missing_docs.mli
  samples/missing_docs.mli:1:0: Module 'missing_docs' missing documentation comment
  [1]

Test style rules - Obj.magic
  $ merlint samples/bad_style.ml
  bad_style.ml:2:16: Never use Obj.magic
  [1]

Test style rules - Str module
  $ merlint samples/uses_str.ml
  uses_str.ml:2:31: Use Re module instead of Str
  uses_str.ml:2:20: Use Re module instead of Str
  uses_str.ml:6:4: Avoid catch-all exception handler
  uses_str.ml:6:32: Use Re module instead of Str
  uses_str.ml:6:12: Use Re module instead of Str
  [1]

Test catch-all exception handler
  $ merlint samples/catch_all.ml
  catch_all.ml:3:6: Avoid catch-all exception handler
  [1]

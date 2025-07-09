Test simple functions with low complexity
  $ merlint --quiet samples/simple.ml
  samples/simple.ml:1:1: missing interface file
  (project): Missing .ocamlformat file for consistent formatting
  [1]

Test function with high cyclomatic complexity
  $ merlint --quiet samples/complex.ml
  complex.ml:8:0: Function 'process_command' has cyclomatic complexity of 14 (threshold: 10)
  samples/complex.ml:1:1: missing interface file
  (project): Missing .ocamlformat file for consistent formatting
  [1]

Test long function detection
  $ merlint --quiet samples/long_function.ml
  long_function.ml:2:0: Function 'very_long_function' is 54 lines long (threshold: 50)
  samples/long_function.ml:1:1: missing interface file
  (project): Missing .ocamlformat file for consistent formatting
  [1]

Test naming conventions
  $ merlint --quiet samples/bad_names.ml
  bad_names.ml:3:7: Variant 'MyModule' should be 'My_module'
  bad_names.ml:4:6: Value 'myFunction' should be 'my_function'
  bad_names.ml:7:32: Variant 'ProcessingData' should be 'Processing_data'
  bad_names.ml:7:14: Variant 'WaitingForInput' should be 'Waiting_for_input'
  bad_names.ml:9:4: Value 'checkValue' should be 'check_value'
  samples/bad_names.ml:1:1: missing interface file
  (project): Missing .ocamlformat file for consistent formatting
  [1]

Test documentation rules
  $ merlint --quiet samples/missing_docs.mli
  samples/missing_docs.mli:1:0: Module 'missing_docs' missing documentation comment
  [1]

Test style rules - Obj.magic
  $ merlint --quiet samples/bad_style.ml
  bad_style.ml:2:16: Never use Obj.magic
  samples/bad_style.ml:1:1: missing interface file
  (project): Missing .ocamlformat file for consistent formatting
  [1]

Test style rules - Str module
  $ merlint --quiet samples/uses_str.ml
  samples/uses_str.ml:1:1: missing interface file
  uses_str.ml:2:31: Use Re module instead of Str
  uses_str.ml:2:20: Use Re module instead of Str
  uses_str.ml:6:32: Use Re module instead of Str
  uses_str.ml:6:12: Use Re module instead of Str
  (project): Missing .ocamlformat file for consistent formatting
  [1]

Test catch-all exception handler
  $ merlint --quiet samples/catch_all.ml
  samples/catch_all.ml:1:1: missing interface file
  (project): Missing .ocamlformat file for consistent formatting
  [1]

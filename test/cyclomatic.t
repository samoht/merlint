Test simple functions with low complexity
  $ cyclomatic samples/simple.ml

Test function with high cyclomatic complexity
  $ cyclomatic --max-complexity 5 samples/complex.ml
  complex.ml:4:0: Function 'process_command' has cyclomatic complexity of 14 (threshold: 5)
  [1]

Test long function detection
  $ cyclomatic --max-length 20 samples/long_function.ml
  long_function.ml:2:0: Function 'very_long_function' is 54 lines long (threshold: 20)
  [1]

Test with multiple violations
  $ cyclomatic --max-complexity 5 --max-length 20 samples/complex.ml samples/long_function.ml
  complex.ml:4:0: Function 'process_command' has cyclomatic complexity of 14 (threshold: 5)
  long_function.ml:2:0: Function 'very_long_function' is 54 lines long (threshold: 20)
  complex.ml:4:0: Function 'process_command' is 43 lines long (threshold: 20)
  [1]

Test with custom thresholds that pass
  $ cyclomatic --max-complexity 15 --max-length 60 samples/complex.ml samples/long_function.ml

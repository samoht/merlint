let () =
  let ic = open_in "traces/sample.bin" in
  ignore (input_char ic);
  close_in ic

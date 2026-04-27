let () =
  let ic = open_in "traces/sample.csv" in
  let line = input_line ic in
  let _fields = String.split_on_char ',' line in
  close_in ic

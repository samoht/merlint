let () =
  match Csv.decode_file "traces/sample.csv" Csv.Row.codec with
  | Ok _rows -> ()
  | Error _ -> ()

let () =
  let codec =
    Csv.Row.(
      obj (fun value -> value) |> col "value" Csv.string ~enc:Fun.id |> finish)
  in
  match Csv.decode_file codec "traces/sample.csv" with
  | Ok _rows -> ()
  | Error _ -> ()

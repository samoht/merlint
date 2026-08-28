let () =
  let codec =
    Csv.Row.(
      obj (fun value -> value)
      |> col "value" Csv.Field.string ~enc:Fun.id
      |> finish)
  in
  match Csv.of_file codec "traces/sample.csv" with
  | Ok _rows -> ()
  | Error _ -> ()

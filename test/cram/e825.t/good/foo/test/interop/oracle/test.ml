type row = { a : string; b : string; c : string }

let row_codec =
  Csv.Row.(
    obj (fun a b c -> { a; b; c })
    |> col "a" Csv.Field.string ~enc:(fun r -> r.a)
    |> col "b" Csv.Field.string ~enc:(fun r -> r.b)
    |> col "c" Csv.Field.string ~enc:(fun r -> r.c)
    |> finish)

let () = ignore (Csv.of_file row_codec "traces/sample.csv")

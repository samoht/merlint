type status =
  | Waiting_for_input  (* Snake_case *)
  | Processing_data
  | Error_occurred

type os =
  | Linux
  | MacOS       (* short trailing acronym: compound term *)
  | Windows
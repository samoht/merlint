let string =
  match Git_hash.hash with
  | "dev" -> (
      match Build_info.V1.version () with
      | Some v -> Build_info.V1.Version.to_string v
      | None -> "dev")
  | v -> v

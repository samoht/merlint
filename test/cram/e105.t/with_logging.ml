module Log = struct
  let err f = f Format.err_formatter
end

let dangerous_operation () =
  failwith "Something went wrong"

let safe_wrapper () =
  try dangerous_operation () with
  | exn ->
      Log.err (fun m -> 
        Format.fprintf m "Operation failed: %s@." 
          (Printexc.to_string exn));
      raise exn
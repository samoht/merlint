(** Bad: test_utils tests utils_lib but is in test_parser stanza *)
let test_identity () = assert (Utils_lib.Utils.identity 1 = 1)

let () = test_identity ()
(** Bad: test_utils tests utils_lib but is in test_parser stanza *)
let test_identity () = assert (Utils.identity 1 = 1)
try int_of_string "abc" with
| Failure _ -> 0
| exn -> print_endline "unexpected"; raise exn
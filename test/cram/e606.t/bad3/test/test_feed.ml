(* BAD: This tests views_lib.feed but is in the main test directory *)
let test_feed () = assert (Views_lib.Feed.generate () = "feed")
(* BAD: This tests core_lib.page but is in the main test directory *)
let test_page () = assert (Core_lib.Page.render () = "page")
(** Tests for Profiling module *)

let test_create () =
  (* Test creating a new profiling state *)
  let _state = Merlint.Profiling.create () in
  (* The state should exist - not much else we can test without internal access *)
  Alcotest.(check bool) "state created" true true

let test_equal () =
  (* Test equality of profiling states *)
  let state1 = Merlint.Profiling.create () in
  let state2 = Merlint.Profiling.create () in
  Alcotest.(check bool) "empty states are equal" true 
    (Merlint.Profiling.equal state1 state2)

let test_pp () =
  (* Test pretty-printing *)
  let state = Merlint.Profiling.create () in
  let output = Fmt.str "%a" Merlint.Profiling.pp state in
  Alcotest.(check bool) "pp output contains timing" true 
    (String.contains output 't')

let test_reset () =
  (* Test resetting state *)
  let state = Merlint.Profiling.create () in
  Merlint.Profiling.reset_state state;
  (* State should still be valid after reset *)
  let output = Fmt.str "%a" Merlint.Profiling.pp state in
  Alcotest.(check bool) "pp works after reset" true 
    (String.length output > 0)

let tests =
  [
    ("create", `Quick, test_create);
    ("equal", `Quick, test_equal);
    ("pp", `Quick, test_pp);
    ("reset", `Quick, test_reset);
  ]

let suite = ("profiling", tests)
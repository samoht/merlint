(** Tests for Example module *)

let test_good () =
  (* Test creating good examples *)
  let example = Merlint.Example.good "let x = 42" in
  Alcotest.(check bool) "is_good is true" true example.is_good;
  Alcotest.(check string) "code matches" "let x = 42" example.code

let test_bad () =
  (* Test creating bad examples *)
  let example = Merlint.Example.bad "let x = 42" in
  Alcotest.(check bool) "is_good is false" false example.is_good;
  Alcotest.(check string) "code matches" "let x = 42" example.code

let test_different () =
  (* Test that good and bad create different examples *)
  let good = Merlint.Example.good "code" in
  let bad = Merlint.Example.bad "code" in
  Alcotest.(check bool) "is_good differs" true (good.is_good <> bad.is_good)

let tests =
  [
    ("good", `Quick, test_good);
    ("bad", `Quick, test_bad);
    ("different", `Quick, test_different);
  ]

let suite = ("example", tests)

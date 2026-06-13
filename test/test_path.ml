let check name expected actual = Alcotest.(check string) name expected actual

(* All paths are made absolute against the current directory, so build the
   expectations the same way rather than hard-coding an absolute prefix. *)
let abs rel = Fpath.(to_string (v (Sys.getcwd ()) // v rel))

let test_canonical () =
  check "relative is absolutised" (abs "a/b.ml")
    (Merlint.Path.to_string (Merlint.Path.v "a/b.ml"));
  check "redundant segments collapse" (abs "a/b.ml")
    (Merlint.Path.to_string (Merlint.Path.v "a/./c/../b.ml"));
  check "trailing slash dropped" (abs "a/b")
    (Merlint.Path.to_string (Merlint.Path.v "a/b/"))

let test_equal () =
  Alcotest.(check bool)
    "two spellings are equal" true
    (Merlint.Path.equal (Merlint.Path.v "a/./b.ml") (Merlint.Path.v "a/b.ml"))

let test_parent_basename () =
  let p = Merlint.Path.v "a/b/c.ml" in
  check "basename" "c.ml" (Merlint.Path.basename p);
  check "parent" (abs "a/b") (Merlint.Path.to_string (Merlint.Path.parent p))

let test_is_descendant () =
  let root = Merlint.Path.v "a/b" in
  let inside = Merlint.Path.v "a/b/c/d.ml" in
  let sibling = Merlint.Path.v "a/bb/d.ml" in
  Alcotest.(check bool)
    "self is descendant" true
    (Merlint.Path.is_descendant ~ancestor:root root);
  Alcotest.(check bool)
    "child is descendant" true
    (Merlint.Path.is_descendant ~ancestor:root inside);
  Alcotest.(check bool)
    "prefix-of-name is not descendant" false
    (Merlint.Path.is_descendant ~ancestor:root sibling)

let test_under () =
  let root = Merlint.Path.v "a/b" in
  check "relative resolves under root" (abs "a/b/c.ml")
    (Merlint.Path.to_string (Merlint.Path.under ~root "c.ml"));
  Alcotest.check_raises "escaping root raises"
    (Invalid_argument (Fmt.str "Path: %S escapes %S" "../x.ml" (abs "a/b")))
    (fun () -> ignore (Merlint.Path.under ~root "../x.ml"))

let tests =
  [
    ("canonical", `Quick, test_canonical);
    ("equal", `Quick, test_equal);
    ("parent_basename", `Quick, test_parent_basename);
    ("is_descendant", `Quick, test_is_descendant);
    ("under", `Quick, test_under);
  ]

let suite = ("path", tests)

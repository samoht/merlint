(* Tests for the library-name mangling that maps a type path to its .cmti
   compilation-unit name. These are the cases that broke cross-module
   resolution: the wrapped-lib suffix, the bare namespace marker, and the
   triple-underscore that joining them produces. *)

let check_mangle input expected () =
  Alcotest.(check string) input expected (Merlint.Type_kind.mangle_lib input)

let check_collapse input expected () =
  Alcotest.(check string)
    input expected
    (Merlint.Type_kind.collapse_underscores input)

(* End-to-end classification against the intf_fixture library's built
   interfaces (see test/intf_fixture). [Colour] surfaces a variant [t] through
   [include module type of Colour_intf] - the "_intf trick" - while [Opaque]
   declares an abstract [type t]. Lay the staged [.cmti] files out as an
   [_opam/lib] tree so [classify ~root] resolves them the way it resolves any
   installed package. *)

let copy src dst =
  In_channel.with_open_bin src (fun ic ->
      Out_channel.with_open_bin dst (fun oc ->
          Out_channel.output_string oc (In_channel.input_all ic)))

let fixture_root =
  lazy
    (let root = Filename.concat (Sys.getcwd ()) "tk_index" in
     let pkg = Filename.concat root "_opam/lib/intf_fixture" in
     List.iter
       (fun d -> if not (Sys.file_exists d) then Unix.mkdir d 0o755)
       [
         root;
         Filename.concat root "_opam";
         Filename.concat root "_opam/lib";
         pkg;
       ];
     copy "intf_fixture/colour.cmti.staged" (Filename.concat pkg "colour.cmti");
     copy "intf_fixture/opaque.cmti.staged" (Filename.concat pkg "opaque.cmti");
     copy "intf_fixture/wrapfix__Sibling.cmti.staged"
       (Filename.concat pkg "wrapfix__Sibling.cmti");
     root)

let tag = function
  | Merlint.Type_kind.Abstract -> "abstract"
  | Merlint.Type_kind.Transparent _ -> "transparent"
  | Merlint.Type_kind.Unknown -> "unknown"

let check_classify ?lib path expected () =
  let root = Lazy.force fixture_root in
  Alcotest.(check string)
    path expected
    (tag (Merlint.Type_kind.classify ~root ?lib ~path ()))

let check_library_of ?enclosing path expected () =
  Alcotest.(check string)
    path expected
    (Merlint.Type_kind.library_of ?enclosing path)

let tests =
  [
    (* mangle_lib *)
    ("plain module lowercased", `Quick, check_mangle "X509" "x509");
    ("multi-cap lowercased", `Quick, check_mangle "Merlin" "merlin");
    ("mangled suffix kept", `Quick, check_mangle "Eio__File" "eio__File");
    ("trailing namespace stripped", `Quick, check_mangle "Eio__" "eio");
    ("opam namespace stripped", `Quick, check_mangle "Opam__" "opam");
    (* collapse_underscores *)
    ("triple folds to double", `Quick, check_collapse "eio____File" "eio__File");
    ("double left alone", `Quick, check_collapse "wire__Private" "wire__Private");
    ("trailing double left alone", `Quick, check_collapse "eio__" "eio__");
    ("single left alone", `Quick, check_collapse "a_b" "a_b");
    (* library_of: the library a path's members are resolved against *)
    ( "wrapped sub-unit names its library",
      `Quick,
      check_library_of "Cascade__Css.declaration" "cascade" );
    ("bare head is its own library", `Quick, check_library_of "Re.t" "re");
    ( "short sibling takes the enclosing library",
      `Quick,
      check_library_of ~enclosing:"cascade" "Declaration.declaration" "cascade"
    );
    (* classify: the _intf trick must not read as abstract *)
    ( "type via include module type of is transparent",
      `Quick,
      check_classify "Colour.t" "transparent" );
    ( "abstract type stays abstract",
      `Quick,
      check_classify "Opaque.t" "abstract" );
    ("missing type is unknown", `Quick, check_classify "Colour.nope" "unknown");
    (* a short cross-unit sibling resolves only with the enclosing library *)
    ( "short sibling unresolved on its own",
      `Quick,
      check_classify "Sibling.t" "unknown" );
    ( "short sibling resolves under its library",
      `Quick,
      check_classify ~lib:"wrapfix" "Sibling.t" "transparent" );
  ]

let suite = ("type_kind", tests)

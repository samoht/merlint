(** Unit tests for the predicate helpers in {!Merlint.Dep_deps}. The library /
    package walks ([local_packages], [own_libs], [test_only_libs]) take a
    {!Project_index.t} and are exercised end-to-end by the cram fixtures of E941
    / E943. *)

open Merlint

let test_is_conf_pkg () =
  Alcotest.(check bool) "conf-libssl" true (Dep_deps.is_conf_pkg "conf-libssl");
  Alcotest.(check bool)
    "conf-pkg-config" true
    (Dep_deps.is_conf_pkg "conf-pkg-config");
  Alcotest.(check bool)
    "openssl (no prefix)" false
    (Dep_deps.is_conf_pkg "openssl");
  Alcotest.(check bool) "empty" false (Dep_deps.is_conf_pkg "");
  (* The predicate matches on prefix only; an internal "conf-" doesn't
     count. *)
  Alcotest.(check bool)
    "internal conf-" false
    (Dep_deps.is_conf_pkg "lib-conf-x")

let test_is_builtin () =
  Alcotest.(check bool) "unix" true (Dep_deps.is_builtin "unix");
  Alcotest.(check bool) "str" true (Dep_deps.is_builtin "str");
  Alcotest.(check bool)
    "threads.posix" true
    (Dep_deps.is_builtin "threads.posix");
  Alcotest.(check bool)
    "compiler-libs.common" true
    (Dep_deps.is_builtin "compiler-libs.common");
  Alcotest.(check bool) "fmt (third-party)" false (Dep_deps.is_builtin "fmt");
  (* The top-namespace check ignores the sub-library suffix, so a non-builtin
     sub-library inherits its parent's status. *)
  Alcotest.(check bool)
    "eio.core (eio is not builtin)" false
    (Dep_deps.is_builtin "eio.core")

let test_build_tools_membership () =
  let mem name = Dep_deps.String_set.mem name Dep_deps.build_tools in
  Alcotest.(check bool) "ocaml" true (mem "ocaml");
  Alcotest.(check bool) "dune" true (mem "dune");
  Alcotest.(check bool) "dune-configurator" true (mem "dune-configurator");
  Alcotest.(check bool) "js_of_ocaml" true (mem "js_of_ocaml");
  Alcotest.(check bool) "alcotest (not a build tool)" false (mem "alcotest")

let suite =
  ( "dep_deps",
    [
      Alcotest.test_case "is_conf_pkg: conf-* prefix only" `Quick
        test_is_conf_pkg;
      Alcotest.test_case "is_builtin: ocaml distribution libs" `Quick
        test_is_builtin;
      Alcotest.test_case "build_tools: known set" `Quick
        test_build_tools_membership;
    ] )

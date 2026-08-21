(* Tests for the Build helpers (dune build @check / cmt refresh).
   The shell-out paths need an Eio process_mgr and a real dune-project on
   disk; integration coverage lives in the cram suite. This file pins
   surface-level shape so refactors that drop a function or change a
   signature fail before they reach the cram run. *)

let test_module_compiles () =
  (* If the module's surface changes, the rebind here stops compiling and
     signals the regression. *)
  let _ = Merlint.Build.ensure_project_built in
  let _ = Merlint.Build.source_status in
  Alcotest.(check pass) "Build surface still binds" () ()

let suite =
  ( "build",
    [ Alcotest.test_case "module surface compiles" `Quick test_module_compiles ]
  )

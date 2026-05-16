(* Structural tests for [Merlint.Suite_mli]. *)

open Merlint
open Ocaml_parsing

let alcotest_t = "string * unit Alcotest.test_case list"
let alcobar_t = "string * Alcobar.test_case list"
let loc txt = { Location.txt; loc = Location.none }

let typ ptyp_desc =
  {
    Parsetree.ptyp_desc;
    ptyp_loc = Location.none;
    ptyp_loc_stack = [];
    ptyp_attributes = [];
  }

let longident path =
  match Longident.unflatten path with
  | Some lid -> lid
  | None -> invalid_arg "empty longident"

let constr path args = typ (Ptyp_constr (loc (longident path), args))
let string_type = constr [ "string" ] []
let unit_type = constr [ "unit" ] []
let list_type elt = constr [ "list" ] [ elt ]
let alcotest_case = constr [ "Alcotest"; "test_case" ] [ unit_type ]
let alcobar_case = constr [ "Alcobar"; "test_case" ] []
let pair a b = typ (Ptyp_tuple [ (None, a); (None, b) ])
let triple a b c = typ (Ptyp_tuple [ (None, a); (None, b); (None, c) ])

let value ?(name = "suite") pval_type =
  {
    Parsetree.pval_name = loc name;
    pval_type;
    pval_prim = [];
    pval_attributes = [];
    pval_loc = Location.none;
  }

let value_item ?name pval_type =
  {
    Parsetree.psig_desc = Psig_value (value ?name pval_type);
    psig_loc = Location.none;
  }

let attribute_item name =
  let attr =
    {
      Parsetree.attr_name = loc name;
      attr_payload = PStr [];
      attr_loc = Location.none;
    }
  in
  { Parsetree.psig_desc = Psig_attribute attr; psig_loc = Location.none }

let alcotest_suite = pair string_type (list_type alcotest_case)
let alcobar_suite = pair string_type (list_type alcobar_case)

let compliant ~expected signature =
  Suite_mli.is_compliant_signature ~expected signature

let test_compliant_alcotest () =
  Alcotest.(check bool)
    "minimal Alcotest suite-only mli" true
    (compliant ~expected:alcotest_t [ value_item alcotest_suite ])

let test_compliant_alcobar () =
  Alcotest.(check bool)
    "minimal alcobar suite-only mli" true
    (compliant ~expected:alcobar_t [ value_item alcobar_suite ])

let test_no_suite () =
  Alcotest.(check bool)
    "mli with no suite -> non-compliant" false
    (compliant ~expected:alcotest_t [ value_item ~name:"foo" alcotest_suite ])

let test_wrong_type () =
  Alcotest.(check bool)
    "suite of wrong type -> non-compliant" false
    (compliant ~expected:alcotest_t [ value_item (list_type alcotest_case) ])

let test_extra_val () =
  Alcotest.(check bool)
    "extra val export -> non-compliant" false
    (compliant ~expected:alcotest_t
       [ value_item alcotest_suite; value_item ~name:"helper" unit_type ])

let test_attributes_ignored () =
  Alcotest.(check bool)
    "floating attributes ignored" true
    (compliant ~expected:alcotest_t
       [ attribute_item "ocaml.warning"; value_item alcotest_suite ])

let test_alias_and_poly_wrappers () =
  let aliased = typ (Ptyp_alias (alcotest_suite, loc "suite")) in
  let poly = typ (Ptyp_poly ([ loc "a" ], alcotest_suite)) in
  Alcotest.(check bool)
    "type aliases tolerated" true
    (compliant ~expected:alcotest_t [ value_item aliased ]);
  Alcotest.(check bool)
    "poly wrappers tolerated" true
    (compliant ~expected:alcotest_t [ value_item poly ])

let test_exact_shape () =
  Alcotest.(check bool)
    "suite type must be exactly a pair" false
    (compliant ~expected:alcotest_t
       [ value_item (triple string_type string_type (list_type alcotest_case)) ]);
  Alcotest.(check bool)
    "missing [unit] mid-type -> non-compliant" false
    (compliant ~expected:alcotest_t
       [
         value_item
           (pair string_type
              (list_type (constr [ "Alcotest"; "test_case" ] [])));
       ])

let test_blank_signature () =
  Alcotest.(check bool)
    "empty mli -> non-compliant" false
    (compliant ~expected:alcotest_t [])

let suite =
  ( "suite_mli",
    [
      Alcotest.test_case "compliant alcotest" `Quick test_compliant_alcotest;
      Alcotest.test_case "compliant alcobar" `Quick test_compliant_alcobar;
      Alcotest.test_case "no suite" `Quick test_no_suite;
      Alcotest.test_case "wrong type" `Quick test_wrong_type;
      Alcotest.test_case "extra val" `Quick test_extra_val;
      Alcotest.test_case "attributes ignored" `Quick test_attributes_ignored;
      Alcotest.test_case "alias and poly wrappers" `Quick
        test_alias_and_poly_wrappers;
      Alcotest.test_case "exact shape" `Quick test_exact_shape;
      Alcotest.test_case "blank signature" `Quick test_blank_signature;
    ] )

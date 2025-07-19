(** Tests for simplified AST name extraction from typedtree and parsetree text
*)

open Merlint
open Dump

(** Test variant extraction from type declarations *)
let test_variant_extraction () =
  let ast_dump =
    "[\n\
    \  structure_item (bad.ml[1,0+0]..bad.ml[4,54+17])\n\
    \    Tstr_type Rec\n\
    \    [\n\
    \      type_declaration status/276 (bad.ml[1,0+0]..bad.ml[4,54+17])\n\
    \        ptype_params =\n\
    \          []\n\
    \        ptype_cstrs =\n\
    \          []\n\
    \        ptype_kind =\n\
    \          Ttype_variant\n\
    \            [\n\
    \              (bad.ml[2,15+2]..bad.ml[2,15+19])\n\
    \                WaitingForInput/277\n\
    \                []\n\
    \                None\n\
    \              (bad.ml[3,35+2]..bad.ml[3,35+18])\n\
    \                ProcessingData/278\n\
    \                []\n\
    \                None\n\
    \              (bad.ml[4,54+2]..bad.ml[4,54+17])\n\
    \                ErrorOccurred/279\n\
    \                []\n\
    \                None\n\
    \            ]\n\
    \        ptype_private = Public\n\
    \        ptype_manifest =\n\
    \          None\n\
    \    ]\n\
     ]"
  in
  let dump = Dump.typedtree ast_dump in
  Alcotest.(check int) "type count" 1 (List.length dump.types);
  Alcotest.(check int) "variant count" 3 (List.length dump.variants);
  let variant_names =
    List.map (fun v -> v.name.base) dump.variants |> List.sort String.compare
  in
  Alcotest.(check (list string))
    "variant names"
    [ "ErrorOccurred"; "ProcessingData"; "WaitingForInput" ]
    variant_names

(** Test identifier extraction *)
let test_identifier_extraction () =
  let ast_dump =
    "[\n\
    \  structure_item (test.ml[1,0+0]..test.ml[1,0+31])\n\
    \    Tstr_value Nonrec\n\
    \    [\n\
    \      <def>\n\
    \        pattern (test.ml[1,0+4]..test.ml[1,0+10])\n\
    \          Tpat_var \"coerce/276\"\n\
    \        expression (test.ml[1,0+13]..test.ml[1,0+31])\n\
    \          Texp_apply\n\
    \          expression (test.ml[1,0+15]..test.ml[1,0+31])\n\
    \            Texp_ident \"Stdlib!.Obj.magic\"\n\
    \          [\n\
    \            <arg>\n\
    \              Nolabel\n\
    \              expression (test.ml[1,0+29]..test.ml[1,0+30])\n\
    \                Texp_ident \"x/277\"\n\
    \          ]\n\
    \    ]\n\
     ]"
  in
  let dump = Dump.typedtree ast_dump in
  Alcotest.(check int) "identifier count" 2 (List.length dump.identifiers);
  let has_obj_magic =
    List.exists
      (fun id ->
        match id.name.prefix with
        | [ "Stdlib"; "Obj" ] -> id.name.base = "magic"
        | _ -> false)
      dump.identifiers
  in
  Alcotest.(check bool) "found Obj.magic" true has_obj_magic

(** Test pattern extraction *)
let test_pattern_extraction () =
  let ast_dump =
    "[\n\
    \  structure_item (test.ml[1,0+0]..test.ml[1,0+10])\n\
    \    Tstr_value Nonrec\n\
    \    [\n\
    \      <def>\n\
    \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
    \          Tpat_var \"x/276\"\n\
    \        expression (test.ml[1,0+8]..test.ml[1,0+10])\n\
    \          Texp_constant Const_int 42\n\
    \    ]\n\
     ]"
  in
  let dump = Dump.typedtree ast_dump in
  Alcotest.(check int) "pattern count" 1 (List.length dump.patterns);
  match dump.patterns with
  | [ { name; _ } ] -> Alcotest.(check string) "pattern name" "x" name.base
  | _ -> Alcotest.fail "Expected one pattern"

(** Test type error fallback *)
let test_type_error_fallback () =
  let ast_dump =
    "[\n\
    \  structure_item (test.ml[1,0+0]..test.ml[1,0+10])\n\
    \    Pstr_value Nonrec\n\
    \    [\n\
    \      <def>\n\
    \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
    \          Ppat_var \"x\"\n\
    \        expression (test.ml[1,0+8]..test.ml[1,0+20])\n\
    \          Pexp_ident \"*type-error*\"\n\
    \    ]\n\
     ]"
  in
  (* Should not raise exception *)
  let dump = Dump.typedtree ast_dump in
  Alcotest.(check int) "pattern count" 1 (List.length dump.patterns)

(** Test snake_case variant extraction *)
let test_snake_case_variants () =
  let ast_dump =
    "[\n\
    \  structure_item (test.ml[1,0+0]..test.ml[4,54+17])\n\
    \    Tstr_type Rec\n\
    \    [\n\
    \      type_declaration status/276 (test.ml[1,0+0]..test.ml[4,54+17])\n\
    \        ptype_params =\n\
    \          []\n\
    \        ptype_cstrs =\n\
    \          []\n\
    \        ptype_kind =\n\
    \          Ttype_variant\n\
    \            [\n\
    \              (test.ml[2,15+2]..test.ml[2,15+19])\n\
    \                waiting_for_input/277\n\
    \                []\n\
    \                None\n\
    \              (test.ml[3,35+2]..test.ml[3,35+18])\n\
    \                processing_data/278\n\
    \                []\n\
    \                None\n\
    \              (test.ml[4,54+2]..test.ml[4,54+17])\n\
    \                error_occurred/279\n\
    \                []\n\
    \                None\n\
    \            ]\n\
    \        ptype_private = Public\n\
    \        ptype_manifest =\n\
    \          None\n\
    \    ]\n\
     ]"
  in
  let dump = Dump.typedtree ast_dump in
  Alcotest.(check int) "variant count" 3 (List.length dump.variants);
  let variant_names =
    List.map (fun v -> v.name.base) dump.variants |> List.sort String.compare
  in
  Alcotest.(check (list string))
    "snake_case variant names"
    [ "error_occurred"; "processing_data"; "waiting_for_input" ]
    variant_names

(** Test variant extraction outside type declarations *)
let test_variant_constructors () =
  let ast_dump =
    "[\n\
    \  structure_item (test.ml[1,0+0]..test.ml[1,0+20])\n\
    \    Tstr_value Rec\n\
    \    [\n\
    \      <def>\n\
    \        pattern (test.ml[1,0+4]..test.ml[1,0+5])\n\
    \          Tpat_var \"x/276\"\n\
    \        expression (test.ml[1,0+8]..test.ml[1,0+20])\n\
    \          Texp_construct \"Some\" (test.ml[1,0+8]..test.ml[1,0+12])\n\
    \            [\n\
    \              expression (test.ml[1,0+13]..test.ml[1,0+15])\n\
    \                Texp_constant Const_int 42\n\
    \            ]\n\
    \    ]\n\
     ]"
  in
  let dump = Dump.typedtree ast_dump in
  Alcotest.(check int) "variant count" 1 (List.length dump.variants);
  match dump.variants with
  | [ { name; _ } ] -> Alcotest.(check string) "variant name" "Some" name.base
  | _ -> Alcotest.fail "Expected one variant"

let tests =
  [
    ("variant extraction", `Quick, test_variant_extraction);
    ("identifier extraction", `Quick, test_identifier_extraction);
    ("pattern extraction", `Quick, test_pattern_extraction);
    ("type error fallback", `Quick, test_type_error_fallback);
    ("snake case variants", `Quick, test_snake_case_variants);
    ("variant constructors", `Quick, test_variant_constructors);
  ]

let suite = [ ("dump", tests) ]

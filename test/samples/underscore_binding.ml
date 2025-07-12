(* Test file for underscore binding detection *)

(* Should trigger E335: underscore-prefixed binding that is used *)
let _debug_mode = true

let check_debug () =
  if _debug_mode then  (* This usage should trigger E335 *)
    print_endline "Debug mode enabled"

(* Should NOT trigger E335: underscore-prefixed binding that is NOT used *)
let _unused_var = 42

(* Should NOT trigger E335: non-underscore binding *)
let normal_var = 100

let use_normal () =
  print_int normal_var

(* Should trigger E335: multiple usages *)
let _temp_value = "temporary"

let process_temp () =
  print_endline _temp_value;  (* First usage *)
  String.length _temp_value   (* Second usage *)
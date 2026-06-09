(* Bad examples - variants and records whose cases share a redundant prefix. *)

(* Every constructor repeats the type name as a prefix. *)
type status =
  | Status_pending
  | Status_running
  | Status_done

(* Every field repeats the type name as a prefix. *)
type point = { point_x : int; point_y : int }

(* allowed_words exempts Token_eof; Token_word is still flagged. *)
type token =
  | Token_word
  | Token_eof

(* 'entity_type' would strip to the reserved keyword 'type'; the convention is a
   trailing underscore, so the suggestion is 'type_'. *)
type entity = { entity_id : int; entity_type : string }

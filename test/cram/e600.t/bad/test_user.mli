(** Test module interface that exports more than just suite *)

val suite : unit Alcotest.test

(* This should not be here - test modules should only export suite *)
val helper_function : unit -> unit
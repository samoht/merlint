(** Workload states. *)

(** The type for the state a workload is in. *)
type status = Running | Paused | Stopped

(** The type for the severity of a log entry. *)
type level = Debug | Info | Error

(** Workload states. *)

type status = Running | Paused | Stopped
(** The type for the state a workload is in. *)

type level =
  | Debug
  | Info
  | Error  (** The type for the severity of a log entry. *)

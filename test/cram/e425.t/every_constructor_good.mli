(** Workload states, documented case by case. *)

type status =
  | Running  (** The workload is executing. *)
  | Paused  (** The workload is suspended and can resume. *)
  | Stopped  (** The workload has exited. *)

type level =
  | Debug  (** Tracing detail. *)
  | Info  (** Normal progress. *)
  | Error  (** A failure. *)
(** The type for the severity of a log entry: [Error] already carries a doc
    comment, so this one binds to [level]. *)

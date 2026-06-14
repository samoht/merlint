(** Build-time project version, generated from [$PROJECT_VERSION]. *)

val env : string
(** [env] is the version string injected at build time, or ["dev"] when the
    [PROJECT_VERSION] environment variable is unset. *)

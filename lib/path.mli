(** Canonical filesystem paths for merlint.

    Re-exports {!Project_index.Path} so merlint and the project index share one
    path representation: a path is made canonical (absolute, normalised) once
    and then carried, compared and rendered without further normalisation. *)

include module type of struct
  include Project_index.Path
end

val dir_display : t -> string
(** [dir_display p] is {!display} as a directory path (with a trailing slash),
    for directory diagnostics. *)

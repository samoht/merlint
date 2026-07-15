(** Helpers shared by rules that read the [tags:] field of an opam file. *)

let string_of = function Opam.Value.String s -> Some s | _ -> None

let tags_of_value = function
  | Opam.Value.String s -> Some [ s ]
  | Opam.Value.List xs -> Some (List.filter_map string_of xs)
  | _ -> Some []

(** Read the [tags:] field from [opam_path]. Handles both the list form
    ([tags: ["a" "b"]]) and the single-string form ([tags: "a"]). Returns [None]
    when the field is absent or the file can't be opened; callers that don't
    need to distinguish absence from emptiness use {!read}. *)
let read_opt opam_path =
  match Opam.field_of_path opam_path "tags" with
  | None -> None
  | Some v -> tags_of_value v

(** Like {!read_opt} but folds an absent field into the empty list. *)
let read opam_path = Option.value (read_opt opam_path) ~default:[]

(** A package declares the I/O-free contract when its tags include the top-level
    [protocol] tag (a state machine over a wire codec) or any [codec] /
    [codec.*] topic (an encoding kind). *)
let is_io_free = function
  | "codec" | "protocol" -> true
  | t -> String.length t > 6 && String.sub t 0 6 = "codec."

let has_io_free tags = List.exists is_io_free tags

(** Helpers shared by rules that read the [tags:] field of an opam file. *)

let string_of = function Opam.Value.String s -> Some s | _ -> None

(** Read the [tags:] field from [opam_path]. Handles both the list form
    ([tags: ["a" "b"]]) and the single-string form ([tags: "a"]). Returns [None]
    when the field is absent or the file can't be opened; callers that don't
    need to distinguish absence from emptiness use {!read}. *)
let read_opt opam_path =
  match Opam.field_of_path opam_path "tags" with
  | None -> None
  | Some (Opam.Value.String s) -> Some [ s ]
  | Some (Opam.Value.List xs) -> Some (List.filter_map string_of xs)
  | Some _ -> Some []

(** Like {!read_opt} but folds an absent field into the empty list. *)
let read opam_path = Option.value (read_opt opam_path) ~default:[]

(** A package declares the sans-IO contract when its tags include the top-level
    [protocol] tag (a state machine over a wire codec) or any [codec] /
    [codec.*] topic (an encoding kind). *)
let is_sans_io = function
  | "codec" | "protocol" -> true
  | t -> String.length t > 6 && String.sub t 0 6 = "codec."

let has_sans_io tags = List.exists is_sans_io tags

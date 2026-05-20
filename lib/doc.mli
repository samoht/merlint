(** Render rule documentation in the format requested by the caller.

    Used by [merlint help] for both interactive viewing and reference-doc
    generation; the build rules under [merlint/docs/] invoke this same renderer
    via [merlint help --format=html|md --all -o FILE]. *)

type format = Text | Markdown | Html

val format_of_string : string -> (format, string) result
(** [format_of_string s] parses ["text"], ["md"]/["markdown"], or ["html"]. *)

val render_rule : format:format -> Rule.t -> string
(** [render_rule ~format rule] renders a single rule. *)

val render_all : format:format -> Rule.t list -> string
(** [render_all ~format rules] renders a full reference document containing
    every rule. In {!constructor-Markdown} format the rules are wrapped in the
    style-guide structure from {!Guide.content}. *)

val render_index : Rule.t list -> string
(** [render_index rules] is a one-line-per-rule terminal index
    ([Ecode  title  (category)]). Designed to be piped through [grep] to find a
    rule by name or category before drilling in with [merlint help <code>]. *)

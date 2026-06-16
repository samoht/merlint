(** E955: No ['] suffix on values -- raising variants use [_exn].

    The ocaml-encodings surface names raising variants with the [_exn] suffix
    ([of_string_exn], [decode_exn]), never a ['] suffix ([of_string']). The [']
    suffix is reserved for a format-native keyword escape ([object'], the JSON
    object sort) or a [pp] / [pp'] configuration-variant pair. This rule flags a
    value ending in ['] in any module of a codec package (tagged [codec]); there
    are no built-in exceptions, so a ['] name the package keeps must be listed
    in [allowed-names] in its [merlint.toml]. The encoding verb vocabulary is
    E953. *)

val rule : Rule.t
(** The E955 rule definition. *)

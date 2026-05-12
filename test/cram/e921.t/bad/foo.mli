(** Promoted broken example inside an odoc snippet.

    {[
      let _ = Foo.does_not_exist ()
    ][
{err@mdx-error[
Line 1, characters 9-29:
Error: Unbound value Foo.does_not_exist
]err}
    ]} *)

val compute : unit -> int

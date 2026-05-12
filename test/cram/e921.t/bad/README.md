# bad

Promoted broken example:

```ocaml
let _ = Foo.does_not_exist ()
```
```mdx-error
Line 1, characters 9-29:
Error: Unbound value Foo.does_not_exist
```

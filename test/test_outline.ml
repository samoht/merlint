(* Tests for Outline: what a source file declares, read from its parse. *)

open Alcotest

let outline ~filename ~content =
  Merlint.Outline.v (Merlint.Ast.v ~filename ~content)

let names items = List.map (fun (i : Merlint.Outline.item) -> i.name) items

let named items name =
  match
    List.find_opt (fun (i : Merlint.Outline.item) -> i.name = name) items
  with
  | Some item -> item
  | None ->
      failf "no declaration named %S in [%s]" name
        (String.concat "; " (names items))

let interface =
  {|type t = { size : int; mutable seen : bool }

val v : ?limit:int -> label:string -> t -> t option

val empty : t

exception Bad of string

type level = Debug | Info

module M : sig
  val inner : t -> t
end

module type S = sig
  type u
end
|}

let items = lazy (outline ~filename:"lib.mli" ~content:interface)

(* Every top-level declaration of the interface, in the order it is written.
   A rule walking the outline reports on what is here and is blind to what is
   not, so the list is pinned whole rather than by sampling. *)
let test_top_level_declarations () =
  check (list string) "declarations"
    [ "t"; "v"; "empty"; "Bad"; "level"; "M"; "S" ]
    (names (Lazy.force items))

(* The kind is what every naming and documentation rule branches on. *)
let test_kinds () =
  let kind name = (named (Lazy.force items) name).kind in
  let k : Merlint.Outline.kind testable =
    testable (fun ppf _ -> Fmt.string ppf "<kind>") (fun a b -> a = b)
  in
  check k "type" Merlint.Outline.Type (kind "t");
  check k "value" Merlint.Outline.Value (kind "v");
  check k "exception" Merlint.Outline.Exception (kind "Bad");
  check k "module" Merlint.Outline.Module (kind "M");
  check k "module type" Merlint.Outline.Module_type (kind "S")

(* Members of a module, fields of a record and constructors of a variant are
   nested under what declares them: a field of one record must never read as a
   reference to a same-named field of another. *)
let test_nesting () =
  let items = Lazy.force items in
  check (list string) "record fields" [ "size"; "seen" ]
    (names (named items "t").children);
  check (list string) "constructors" [ "Debug"; "Info" ]
    (names (named items "level").children);
  check (list string) "module members" [ "inner" ]
    (names (named items "M").children)

(* A [mutable] field is the whole of the immutable-state rule's question. *)
let test_mutable_field () =
  let fields = (named (Lazy.force items) "t").children in
  check bool "immutable" false (named fields "size").mutable_field;
  check bool "mutable" true (named fields "seen").mutable_field

(* The labels of a written arrow, outermost first. A documentation rule renders
   the signature from these, so an optional argument must stay distinguishable
   from a labelled one, and a value that is not a function must have none. *)
let test_arg_labels () =
  let items = Lazy.force items in
  let labels name = (named items name).arg_labels in
  check (list string) "labels" [ "?limit"; "~label"; "" ]
    (List.map
       (function
         | Ocaml_parsing.Asttypes.Optional l -> "?" ^ l
         | Labelled l -> "~" ^ l
         | Nolabel -> "")
       (labels "v"));
  check (list string) "not a function" []
    (List.map (fun _ -> "") (labels "empty"))

(* The span is the declaration's own, and it is what a finding is reported at
   and what a doc comment is looked up by. *)
let test_location_is_the_declaration () =
  let loc = (named (Lazy.force items) "v").loc in
  check string "file" "lib.mli" loc.loc_start.pos_fname;
  check int "line" 3 loc.loc_start.pos_lnum;
  check int "column" 0 (loc.loc_start.pos_cnum - loc.loc_start.pos_bol)

(* An implementation declares through its bindings, including the ones a
   pattern binds several names at once, and through the modules it nests them
   in. *)
let test_implementation_bindings () =
  let content =
    {|let answer = 42
let a, b = (1, 2)
let () = print_int answer

module Inner = struct
  let helper x = x
end
|}
  in
  let items = outline ~filename:"lib.ml" ~content in
  check (list string) "bindings" [ "answer"; "a"; "b"; "Inner" ] (names items);
  check (list string) "nested" [ "helper" ]
    (names (named items "Inner").children)

(* [[@@deriving]] and [[@deprecated]] are read off the declaration's own
   attributes. *)
let test_attributes () =
  let content =
    {|type t = int [@@deriving eq, show]

val old : t -> t [@@deprecated "use v"]
|}
  in
  let items = outline ~filename:"lib.mli" ~content in
  check (list string) "deriving" [ "eq"; "show" ] (named items "t").deriving;
  check bool "deprecated" true (named items "old").deprecated;
  check bool "not deprecated" false (named items "t").deprecated

(* Source that does not parse declares nothing. *)
let test_unparseable_source_declares_nothing () =
  check (list string) "no declarations" []
    (names (outline ~filename:"broken.mli" ~content:"val v : (** oops *) let"))

let suite =
  ( "outline",
    [
      test_case "top-level declarations" `Quick test_top_level_declarations;
      test_case "kinds" `Quick test_kinds;
      test_case "nesting" `Quick test_nesting;
      test_case "mutable field" `Quick test_mutable_field;
      test_case "arg labels" `Quick test_arg_labels;
      test_case "location is the declaration" `Quick
        test_location_is_the_declaration;
      test_case "implementation bindings" `Quick test_implementation_bindings;
      test_case "attributes" `Quick test_attributes;
      test_case "unparseable source declares nothing" `Quick
        test_unparseable_source_declares_nothing;
    ] )

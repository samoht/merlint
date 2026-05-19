(* Deliberate rule bait: missing .mli (E505), bad naming (E300),
   catch-all handler (E105). If merlint walks this file, several rules
   fire. The whole point of (vendored_dirs ext) is that it should not. *)

type BadVariant = X | Y | Z

let try_thing () = try failwith "x" with _ -> ()

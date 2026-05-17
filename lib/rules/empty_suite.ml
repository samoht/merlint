(** Shared detector for empty Alcotest / alcobar suites of the form
    [let suite = ("name", [])]. Used by E621 (test_ files) and E726 (fuzz_
    files), parameterised on the filename prefix. *)

module Issue_location = Location

let is_empty_list = Suite_bindings.is_empty_list

let find ~filename view =
  Suite_bindings.of_view ~filename view
  |> List.find_map (fun binding ->
      if binding.Suite_bindings.empty then Some binding.loc else None)

(** [check ~prefix ~mk_payload ctx] is the rule body: only ML files whose
    basename starts with [<prefix>_] are considered; if their [suite] binding is
    empty, we yield an issue tagged with [mk_payload name] where [name] is the
    basename with the [<prefix>_] dropped. *)
let check ~prefix ~mk_payload (ctx : Context.file) =
  let filename = ctx.filename in
  let basename = Filename.basename filename in
  let prefix_us = prefix ^ "_" in
  if
    not
      (String.starts_with ~prefix:prefix_us basename && File_kind.is_ml basename)
  then []
  else
    match find ~filename (Context.view ctx) with
    | None -> []
    | Some loc ->
        let suite_name =
          let fp = Fpath.v filename in
          Fpath.(fp |> rem_ext |> basename) |> fun s ->
          if String.starts_with ~prefix:prefix_us s then
            String.sub s (String.length prefix_us)
              (String.length s - String.length prefix_us)
          else s
        in
        [ Issue.v ~loc (mk_payload suite_name) ]

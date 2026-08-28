(** E825: Interop test uses CSV traces but dune lacks csv dependency *)

type payload = { dir : string }

let dune_file ctx (dir : Interop.oracle_dir) =
  try
    Context.file_content ctx Path.(dir.path / "dune")
    |> Dune.File.of_string |> Result.to_option
  with File_view.Analysis_error _ -> None

(* Match either the library name [csv] or its public name [nox-csv] (the
   opam package that provides it). A [(libraries ...)] field may reference
   the library by either name. *)
let has_csv_dependency dune =
  let libs =
    Dune.File.test_libraries dune
    @ Dune.File.executable_libraries dune
    @ List.concat_map Dune.File.Library.libraries (Dune.File.libraries dune)
  in
  List.exists (fun l -> l = "csv" || l = "nox-csv") libs

let check (ctx : Context.project) =
  let dirs = Interop.oracle_dirs_for ctx in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      if d.has_traces && d.has_dune then
        let traces = Path.(d.path / "traces") |> Context.string_of_path in
        let has_csv =
          try
            Fs.readdir traces |> Array.to_list
            |> List.exists (fun f -> Filename.check_suffix f ".csv")
          with Sys_error _ -> false
        in
        if has_csv then
          match dune_file ctx d with
          | Some dune when has_csv_dependency dune -> None
          | _ ->
              let loc = Location.in_file (Interop.display_child d "dune") in
              Some (Issue.v ~loc { dir = Interop.display d })
        else None
      else None)
    dirs

let pp ppf { dir } =
  Fmt.pf ppf "Interop test %s has CSV traces but dune lacks csv dependency" dir

let rule =
  Rule.v ~code:"E825" ~title:"Missing csv dependency" ~category:Interop_testing
    ~hint:
      "Interop tests with CSV traces should use csv for parsing. Add csv to \
       the (libraries ...) in the dune file and use Csv.of_file with a Row \
       codec."
    ~examples:[] ~pp (Project check)

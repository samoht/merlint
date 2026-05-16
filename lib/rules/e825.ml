(** E825: Interop test uses CSV traces but dune lacks csv dependency *)

type payload = { dir : string }

let dune_file ctx dir =
  let path = Filename.concat dir "dune" in
  try
    File_view.content (Context.file_view ctx path)
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
  let dirs = Interop.oracle_dirs ctx.project_root in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      if d.has_traces && d.has_dune then
        let traces = Filename.concat d.path "traces" in
        let has_csv =
          try
            Sys.readdir traces |> Array.to_list
            |> List.exists (fun f -> Filename.check_suffix f ".csv")
          with Sys_error _ -> false
        in
        if has_csv then
          match dune_file ctx d.path with
          | Some dune when has_csv_dependency dune -> None
          | _ ->
              let loc = Location.in_file (Filename.concat d.path "dune") in
              Some (Issue.v ~loc { dir = d.path })
        else None
      else None)
    dirs

let pp ppf { dir } =
  Fmt.pf ppf "Interop test %s has CSV traces but dune lacks csv dependency" dir

let rule =
  Rule.v ~code:"E825" ~title:"Missing csv dependency" ~category:Interop_testing
    ~hint:
      "Interop tests with CSV traces should use csv for parsing. Add csv to \
       the (libraries ...) in the dune file and use Csv.decode_file with a Row \
       codec."
    ~examples:[] ~pp (Project check)

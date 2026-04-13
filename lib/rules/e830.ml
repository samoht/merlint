(** E830: Inlined algorithm in interop generator *)

type payload = { dir : string; file : string; reason : string }

(* Heuristic: a generator that defines functions with algorithmic names
   (encode, decode, compute, calculate, process, transform, convert)
   is likely reimplementing the algorithm instead of calling the oracle. *)
let suspicious_defs =
  [
    (* Python: def <name>( *)
    (fun line ->
      let l = String.trim line in
      String.length l > 4
      && String.sub l 0 4 = "def "
      &&
      let name =
        try
          let i = String.index l '(' in
          String.sub l 4 (i - 4) |> String.trim
        with Not_found -> ""
      in
      List.exists
        (fun prefix ->
          Astring.String.is_prefix ~affix:prefix (String.lowercase_ascii name))
        [ "encode"; "decode"; "compute"; "calculate"; "process"; "transform" ]
      &&
      (* Exclude test/verification helpers *)
      not
        (Astring.String.is_prefix ~affix:"test" (String.lowercase_ascii name)
        || Astring.String.is_prefix ~affix:"verify"
             (String.lowercase_ascii name)));
    (* Rust: fn <name>( or pub fn <name>( *)
    (fun line ->
      let l = String.trim line in
      let after_fn =
        if Astring.String.is_prefix ~affix:"fn " l then
          Some (String.sub l 3 (String.length l - 3))
        else if Astring.String.is_prefix ~affix:"pub fn " l then
          Some (String.sub l 7 (String.length l - 7))
        else None
      in
      match after_fn with
      | None -> false
      | Some rest ->
          let name =
            try
              let i = String.index rest '(' in
              String.sub rest 0 i |> String.trim
            with Not_found -> ""
          in
          List.exists
            (fun prefix -> Astring.String.is_prefix ~affix:prefix name)
            [ "encode"; "decode"; "compute"; "calculate"; "process" ]);
  ]

let scan_file path =
  try
    let ic = open_in path in
    let found = ref false in
    (try
       while true do
         let line = input_line ic in
         if List.exists (fun check -> check line) suspicious_defs then
           found := true
       done
     with End_of_file -> ());
    close_in ic;
    !found
  with Sys_error _ -> false

let check (ctx : Context.project) =
  let dirs = Interop.find_oracle_dirs ctx.project_root in
  List.filter_map
    (fun (d : Interop.oracle_dir) ->
      let scripts = Filename.concat d.path "scripts" in
      if not (Sys.file_exists scripts) then None
      else
        let files =
          try Sys.readdir scripts |> Array.to_list with Sys_error _ -> []
        in
        let generator_files =
          List.filter
            (fun f ->
              let f = String.lowercase_ascii f in
              Astring.String.is_prefix ~affix:"generate" f
              && (Filename.check_suffix f ".py"
                 || Filename.check_suffix f ".rs"
                 || Filename.check_suffix f ".go"))
            files
        in
        let inlined =
          List.filter_map
            (fun f ->
              let path = Filename.concat scripts f in
              if scan_file path then Some f else None)
            generator_files
        in
        match inlined with
        | [] -> None
        | file :: _ ->
            Some
              (Issue.v
                 {
                   dir = d.path;
                   file;
                   reason =
                     "defines encode/decode/compute functions — may be \
                      reimplementing the algorithm instead of calling the \
                      oracle's API";
                 }))
    dirs

let pp ppf { dir; file; reason } =
  Fmt.pf ppf "Interop generator %s/scripts/%s: %s" dir file reason

let rule =
  Rule.v ~code:"E830" ~title:"Inlined algorithm in generator"
    ~category:Interop_testing
    ~hint:
      "The generator MUST call the upstream tool's public API. Never \
       reimplement the algorithm being verified — this defeats the purpose of \
       interop testing. If the public API doesn't expose what you need, drop \
       the test rather than inlining."
    ~examples:[] ~pp (Project check)

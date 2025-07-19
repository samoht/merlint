(** E110: Silenced Warning *)

type payload = { warning_number : string }
(** Payload for silenced warning issues *)

(** Create regex for warning attributes with given prefix *)
let make_warning_regex prefix =
  Re.compile
    (Re.seq
       [
         Re.str prefix;
         Re.rep Re.space;
         Re.opt (Re.seq [ Re.str "ocaml"; Re.str "." ]);
         Re.str "warning";
         Re.rep Re.space;
         Re.str "\"-";
         Re.group (Re.rep1 Re.digit);
         Re.str "\"";
       ])

let warning_attr_regex = make_warning_regex "[@"
let warning_attr2_regex = make_warning_regex "[@@"
let warning_attr3_regex = make_warning_regex "[@@@"

(** Check if a regex matches and extract warning number *)
let check_regex regex line =
  match Re.exec_opt regex line with
  | Some m -> Some (Re.Group.get m 1)
  | None -> None

(** Check all files for silenced warnings *)
let check (ctx : Context.project) =
  File.process_ocaml_files ctx (fun filename content ->
      let warning_regexes =
        [ warning_attr_regex; warning_attr2_regex; warning_attr3_regex ]
      in

      (* Check each regex separately and collect all matches *)
      List.concat_map
        (fun regex ->
          File.process_lines_with_location filename content
            (fun _line_idx line loc ->
              match check_regex regex line with
              | Some warning_num ->
                  Some (Issue.v ~loc { warning_number = warning_num })
              | None -> None))
        warning_regexes)

let pp ppf { warning_number } =
  Fmt.pf ppf "Warning %s is silenced instead of being fixed" warning_number

let rule =
  Rule.v ~code:"E110" ~title:"Silenced Warning"
    ~category:Rule.Style_modernization
    ~hint:
      "Warnings should be addressed rather than silenced. Fix the underlying \
       issue instead of using warning suppression attributes. If you must \
       suppress a warning, document why it's necessary."
    ~examples:[] ~pp (Project check)

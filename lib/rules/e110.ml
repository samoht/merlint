open Examples
(** E110: Silenced Warning *)

module P = Ocaml_parsing.Parsetree

type payload = { warning_number : string }
(** Payload for silenced warning issues *)

type state = { filename : string; issues : payload Issue.t list ref }

let is_warning_attr attr =
  match attr.P.attr_name.txt with
  | "warning" | "ocaml.warning" -> true
  | _ -> false

let warning_number s =
  let len = String.length s in
  if len < 2 || s.[0] <> '-' then None
  else
    let rec scan i =
      if
        i >= len
        || not
             (Char.code s.[i] >= Char.code '0'
             && Char.code s.[i] <= Char.code '9')
      then i
      else scan (i + 1)
    in
    let stop = scan 1 in
    if stop = 1 then None else Some (String.sub s 1 (stop - 1))

let payload_string attr =
  match attr.P.attr_payload with
  | P.PStr
      [
        {
          pstr_desc =
            P.Pstr_eval
              ( {
                  pexp_desc =
                    P.Pexp_constant
                      { pconst_desc = P.Pconst_string (warning_spec, _, _); _ };
                  _;
                },
                _ );
          _;
        };
      ] ->
      Some warning_spec
  | _ -> None

let visit_attribute state attr =
  if is_warning_attr attr then
    match Option.bind (payload_string attr) warning_number with
    | None -> ()
    | Some warning_number ->
        let loc = Loc.of_typed ~filename:state.filename attr.P.attr_loc in
        state.issues := Issue.v ~loc { warning_number } :: !(state.issues)

let init ctx = { filename = ctx.Context.filename; issues = ref [] }
let finish _ctx state = List.rev !(state.issues)

let pp ppf { warning_number } =
  Fmt.pf ppf "Warning %s is silenced instead of being fixed" warning_number

let rule =
  Rule.v ~code:"E110" ~title:"Silenced Warning"
    ~category:Rule.Style_modernization
    ~hint:
      "Warnings should be addressed rather than silenced. Fix the underlying \
       issue instead of using warning suppression attributes. If you must \
       suppress a warning, document why it's necessary."
    ~examples:[ Example.bad E110.suppressed_ml; Example.good E110.fixed_ml ]
    ~pp
    (Rule.pass ~init ~attribute:visit_attribute ~finish ())

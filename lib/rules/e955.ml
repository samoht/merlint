(** E955: No ['] suffix on values -- raising variants use [_exn]. *)

module FV = File_view
module P = Project_index.Package

type payload = { module_ : string; name : string }

let is_codec_pkg pkg =
  let tags = P.tags pkg in
  List.mem "codec" tags && not (List.mem "eio" tags)

(* Names a codec package documents as exempt from this rule (a format-native
   keyword escape such as [object'], or a [pp]/[pp'] configuration-variant
   pair), declared as [allowed-names] in its [merlint.toml]. There are no
   built-in exceptions: a ['] name is rejected unless it is listed here. *)
let allowed_names pkg =
  match P.source_dir pkg with
  | Some dir -> (Config.load (Fpath.to_string dir)).allowed_names
  | None -> []

type module_ = {
  module_name : string;
  file : Context.path;
  allowed : string list;
}

let codec_modules ctx =
  Context.index ctx |> Project_index.source_package_list
  |> List.filter is_codec_pkg
  |> List.concat_map (fun pkg ->
      let allowed = allowed_names pkg in
      Project_index.package_libraries pkg
      |> List.concat_map Project_index.Library.files
      |> List.filter_map (fun f ->
          if Fpath.has_ext ".ml" f then
            Some
              {
                module_name = Filename.remove_extension (Fpath.basename f);
                file = Context.resolve ctx f;
                allowed;
              }
          else None))

let has_prime name =
  String.length name > 0 && name.[String.length name - 1] = '\''

let check (ctx : Context.project) (m : module_) =
  match Context.file_view ctx m.file with
  | exception Context.Analysis_error _ -> []
  | view ->
      if not (FV.is_resolved view) then []
      else
        FV.all_items view
        |> List.filter_map (fun item ->
            match FV.Item.kind item with
            | FV.Item.Value ->
                let name = FV.Item.name item in
                if has_prime name && not (List.mem name m.allowed) then
                  Some
                    (Issue.v ~loc:(FV.Item.loc item)
                       { module_ = m.module_name; name })
                else None
            | _ -> None)

let enumerate ctx = codec_modules ctx

let pp ppf { module_; name } =
  Fmt.pf ppf
    "%s.%s uses a ' suffix. A raising variant is named with the _exn suffix, \
     not '; the ' suffix is only for a format-native keyword escape (object') \
     or a pp / pp' configuration-variant pair, and those must be listed in \
     allowed-names in merlint.toml."
    (String.capitalize_ascii module_)
    name

let rule =
  Rule.v ~code:"E955" ~title:"No prime suffix on values"
    ~category:Rule.Naming_conventions
    ~hint:
      "A raising variant of a codec entry point is named with the _exn suffix \
       (of_string_exn), never a ' suffix (of_string'). The ' suffix is \
       reserved for a format-native keyword escape (object', the JSON object \
       sort) or a pp / pp' configuration-variant pair; there are no built-in \
       exceptions, so any ' name a codec package keeps must be documented in \
       allowed-names in its merlint.toml. See E953 for the encoding verb \
       vocabulary."
    ~examples:[] ~pp
    (Project_units { enumerate; check })

(** Git working trees. *)

(* A linked working tree keeps a [.git] file rather than a directory, holding
   "gitdir: <repo>/.git/worktrees/<name>". The [commondir] beside that path
   names the repository's own [.git], and its parent is the main working tree:
   the tree a linked one was branched from, and the only one whose untracked,
   gitignored companions -- a local opam switch above all -- are there to be
   reused. *)

let first_line path =
  match
    In_channel.with_open_text (Fpath.to_string path) In_channel.input_line
  with
  | line -> Option.map String.trim line
  | exception Sys_error _ -> None

let gitdir_of_file dir =
  match first_line Fpath.(dir / ".git") with
  | None -> None
  | Some line -> (
      match Astring.String.cut ~sep:"gitdir:" line with
      | Some ("", path) ->
          let path = Fpath.v (String.trim path) in
          Some
            (if Fpath.is_abs path then Fpath.normalize path
             else Fpath.(dir // path |> normalize))
      | _ -> None)

(* [commondir] is written relative to the worktree's own git directory; the
   layout it describes ([<repo>/.git/worktrees/<name>] two levels below
   [<repo>/.git]) is what stands in when the file is absent. *)
let common_dir gitdir =
  match first_line Fpath.(gitdir / "commondir") with
  | Some rel -> Fpath.(gitdir // v rel |> normalize)
  | None -> Fpath.(gitdir / ".." / ".." |> normalize)

let main dir =
  match gitdir_of_file dir with
  | None -> None
  | Some gitdir ->
      let common = Fpath.rem_empty_seg (common_dir gitdir) in
      (* A bare repository has no working tree to point at. *)
      if Fpath.basename common <> ".git" then None
      else Some Fpath.(parent common |> normalize |> rem_empty_seg)

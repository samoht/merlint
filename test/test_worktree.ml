(* Tests for the Worktree module.

   The layout is written by hand rather than by running git: these are exactly
   the bytes git leaves in a linked working tree, and a test that shells out
   would prove the reader works only where a git binary is. The cram test
   test/cram/worktree.t runs the real thing. *)

let rec rm_rf path =
  match Unix.lstat path with
  | exception _ -> ()
  | { Unix.st_kind = Unix.S_DIR; _ } ->
      Sys.readdir path |> Array.iter (fun n -> rm_rf (Filename.concat path n));
      Unix.rmdir path
  | _ -> Sys.remove path

let with_temp_dir f =
  let dir = Filename.temp_file "merlint-worktree" "" in
  Sys.remove dir;
  Unix.mkdir dir 0o755;
  Fun.protect ~finally:(fun () -> rm_rf dir) (fun () -> f (Fpath.v dir))

let mkdir_p path =
  let rec loop path =
    if Sys.file_exists path then ()
    else begin
      loop (Filename.dirname path);
      Unix.mkdir path 0o755
    end
  in
  loop (Fpath.to_string path)

let write path contents =
  mkdir_p (Fpath.parent path);
  Out_channel.with_open_text (Fpath.to_string path) (fun oc ->
      Out_channel.output_string oc contents)

(* [main] holds the repository; [tree] is a linked working tree of it, with the
   [.git] file and [commondir] git writes for one. *)
let repo_with_worktree ?(commondir = "../..") ?gitdir root =
  let main = Fpath.(root / "main") in
  let tree = Fpath.(root / "tree") in
  let git_dir = Fpath.(main / ".git" / "worktrees" / "tree") in
  write Fpath.(git_dir / "commondir") (commondir ^ "\n");
  write Fpath.(main / ".git" / "HEAD") "ref: refs/heads/main\n";
  let gitdir =
    match gitdir with Some g -> g | None -> Fpath.to_string git_dir
  in
  write Fpath.(tree / ".git") (Fmt.str "gitdir: %s\n" gitdir);
  (main, tree)

let check_main = Alcotest.(check (option string)) "main working tree"

let path_of = function
  | Some p -> Some Fpath.(to_string (normalize p))
  | None -> None

let test_linked_tree () =
  with_temp_dir @@ fun root ->
  let main, tree = repo_with_worktree root in
  check_main
    (Some Fpath.(to_string (normalize main)))
    (path_of (Merlint.Worktree.main tree))

(* git writes an absolute gitdir when the trees are not siblings; a relative one
   is resolved against the working tree that holds the file. *)
let test_relative_gitdir () =
  with_temp_dir @@ fun root ->
  let main, tree =
    repo_with_worktree ~gitdir:"../main/.git/worktrees/tree" root
  in
  check_main
    (Some Fpath.(to_string (normalize main)))
    (path_of (Merlint.Worktree.main tree))

(* The main working tree keeps a [.git] directory, and reading it as a file
   yields nothing. *)
let test_main_tree_is_not_linked () =
  with_temp_dir @@ fun root ->
  let main, _ = repo_with_worktree root in
  check_main None (path_of (Merlint.Worktree.main main))

let test_plain_directory () =
  with_temp_dir @@ fun root ->
  mkdir_p Fpath.(root / "plain");
  check_main None (path_of (Merlint.Worktree.main Fpath.(root / "plain")))

(* A bare repository has no working tree to name: its [commondir] points at the
   repository itself rather than at a [.git] inside a checkout. *)
let test_bare_repository () =
  with_temp_dir @@ fun root ->
  let _, tree = repo_with_worktree ~commondir:"../../../bare.git" root in
  check_main None (path_of (Merlint.Worktree.main tree))

(* Without [commondir], the path the file itself names still describes the
   layout: two levels below the repository's [.git]. *)
let test_missing_commondir () =
  with_temp_dir @@ fun root ->
  let main, tree = repo_with_worktree root in
  Sys.remove
    Fpath.(to_string (main / ".git" / "worktrees" / "tree" / "commondir"));
  check_main
    (Some Fpath.(to_string (normalize main)))
    (path_of (Merlint.Worktree.main tree))

let test_garbage_git_file () =
  with_temp_dir @@ fun root ->
  let tree = Fpath.(root / "tree") in
  write Fpath.(tree / ".git") "not a gitdir line\n";
  check_main None (path_of (Merlint.Worktree.main tree))

let suite =
  ( "worktree",
    [
      Alcotest.test_case "linked tree" `Quick test_linked_tree;
      Alcotest.test_case "relative gitdir" `Quick test_relative_gitdir;
      Alcotest.test_case "main tree is not linked" `Quick
        test_main_tree_is_not_linked;
      Alcotest.test_case "plain directory" `Quick test_plain_directory;
      Alcotest.test_case "bare repository" `Quick test_bare_repository;
      Alcotest.test_case "missing commondir" `Quick test_missing_commondir;
      Alcotest.test_case "garbage .git file" `Quick test_garbage_git_file;
    ] )

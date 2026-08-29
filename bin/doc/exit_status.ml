open Cmdliner

(* A run answers three independent questions, so the status carries three bits.
   Bit 0: the code merlint read has findings. Bit 1: merlint could not look at
   part of what it was pointed at, which is work on a dune file or on merlint
   itself and says nothing about the code. Bit 2: merlint refused to look, so
   there is no verdict to read at all. Summed into one number, a caller could
   not tell them apart; as bits it can, and a caller that only wants pass or
   fail still reads any non-zero -- which is what the pre-commit hook does.

   Bits 0 and 1, status 3, is the worst of those two outcomes rather than a
   third kind of outcome: the findings are real, and the list they came from is
   also short, so it is strictly above either alone.

   An incomplete run is never merely a warning. A run that exits 0 having read
   half of what it was given is read as "this code is clean", and that reading
   is what hid three discovery defects until the status made it impossible.

   A path merlint has no rule for reaches bit 1 the same way. It is not a file
   the run failed to read, it is one the run was never going to read, and the
   caller who named it is owed that answer rather than the verdict over the
   other arguments. A check that raised reaches it too: the rule did not run, so
   what it would have found is not in the list, and the reason this time is
   merlint itself -- which bit 1 already says it can be.

   Bit 2 is not a louder bit 1, which is why it is a bit of its own. Bit 1 says
   merlint looked, read most of what it was given, and is reporting on that. Bit
   2 says it read none of it: the zeroes beside a refusal count nothing, they
   count nothing that happened. A caller acts on the two differently -- a
   refusal over a dune root another session holds is worth retrying and an
   incomplete run never is -- so folding them onto one bit would put the
   retry decision back into prose the caller cannot read.

   Bit 2 rather than cmdliner's [cli_error], which is 124, and 124 is also what
   coreutils' [timeout] exits with when it kills the command it wrapped. CI
   wraps linters in [timeout] as a matter of course, so under 124 a wrapper
   could not tell "merlint refused because the project does not build" from
   "merlint never finished": the collapse of two answers into one number that
   these bits exist to prevent, reintroduced one line below the refusal that
   prevents it. Every value the mask can spell is checked against
   [reserved_reason] by [Test_exit_status], so a fourth bit that lets the mask
   reach 124 again fails there rather than in someone's CI. *)

let findings = 1
let incomplete = 2
let refused = 4
let bits = [ findings; incomplete; refused ]

let all =
  List.fold_left
    (fun statuses bit -> List.concat_map (fun s -> [ s; s lor bit ]) statuses)
    [ 0 ] bits

(* Statuses something between merlint and its caller already spends, so a
   caller reading one learns nothing about this run. The shell's three and the
   signal range are POSIX; 124 and 125 are cmdliner's, and coreutils'
   [timeout] spends the same two. *)
let reserved_reason status =
  if status < 0 || status > 255 then
    Some
      "outside the range a process exits with, so the shell sees it modulo 256 \
       and 256 arrives as a clean run"
  else if status >= 128 then
    Some "the shell's status for a process a signal killed"
  else
    match status with
    | 123 -> Some "cmdliner's some_error"
    | 124 ->
        Some
          "cmdliner's cli_error, and timeout(1)'s status for a command it \
           killed"
    | 125 ->
        Some
          "cmdliner's internal_error, and timeout(1)'s status for its own \
           failure"
    | 126 -> Some "the shell's status for a command it found but could not run"
    | 127 -> Some "the shell's status for a command it could not find"
    | _ -> None

let of_run ~findings:n ~unchecked ~skipped ~failed =
  (if n > 0 then findings else 0)
  lor if unchecked > 0 || skipped > 0 || failed > 0 then incomplete else 0

(* The status is the only thing a scripted caller reads, so it is documented in
   the manual of every command that produces one. [Cmd.Exit.defaults] documents
   0 with "on success", which a run reporting an incomplete analysis is not, so
   0 is described here and the defaults are not reused. The last two are
   cmdliner's own and merlint does not choose them: [Cmd.eval] returns
   [cli_error] for a command line it could not parse, which is a different fact
   from a refusal and keeps the code cmdliner publishes for it. *)
let exits =
  [
    Cmd.Exit.info 0 ~doc:"on a complete run with no findings.";
    Cmd.Exit.info findings
      ~doc:"findings: the code merlint read has issues to fix.";
    Cmd.Exit.info incomplete
      ~doc:"incomplete coverage: merlint could not read part of it.";
    Cmd.Exit.info (findings lor incomplete)
      ~doc:"both: findings, over a run that read only part of the tree.";
    Cmd.Exit.info refused
      ~doc:"refused: nothing was analysed, so there is no verdict.";
    Cmd.Exit.info Cmd.Exit.cli_error
      ~doc:"on a command line merlint could not parse.";
    Cmd.Exit.info Cmd.Exit.internal_error ~doc:"on unexpected internal errors.";
  ]

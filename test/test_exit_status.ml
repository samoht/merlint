(* The exit status is merlint's only machine-readable output, and the only one
   a CI wrapper acts on without a human in between. These tests hold the two
   properties that make it readable: each bit answers one question, and no
   value the mask can spell is a value something else between merlint and the
   caller already spends -- a shell's, a signal's, or timeout(1)'s.

   The checks run over [Exit_status.bits] and [Exit_status.exits] rather than
   over a list written out here, so a fourth bit is covered by them the moment
   it is declared. A mask of bits 1, 2, 4, 8, 16, 32 and 64 can spell 123, 124,
   125, 126 and 127, and this is where that is found. *)

module Exit_status = Merlint_doc.Exit_status

(* Every 4-tuple of zero and non-zero counts, which is all [of_run]
   distinguishes. *)
let rec count_tuples n =
  if n = 0 then [ [] ]
  else
    List.concat_map
      (fun rest -> [ 0 :: rest; 1 :: rest ])
      (count_tuples (n - 1))

(* The statuses a merlint run returns: everything [of_run] answers with, plus
   the refusal, which is not one of its answers because a refused run counted
   nothing. *)
let emitted =
  count_tuples 4
  |> List.filter_map (function
    | [ findings; unchecked; skipped; failed ] ->
        Some (Exit_status.of_run ~findings ~unchecked ~skipped ~failed)
    | _ -> None)
  |> List.cons Exit_status.refused
  |> List.sort_uniq Int.compare

let documented = List.map Cmdliner.Cmd.Exit.info_code Exit_status.exits

(* A positive control for the check below it: an oracle that answered [None]
   to everything would pass "no status is reserved" over any mask at all. *)
let test_reserved_reason_names_the_reserved () =
  List.iter
    (fun status ->
      Alcotest.(check bool)
        (Fmt.str "%d is spent by something else" status)
        true
        (Exit_status.reserved_reason status <> None))
    [ 123; 124; 125; 126; 127; 128; 137; 255; 256; -1 ];
  List.iter
    (fun status ->
      Alcotest.(check bool)
        (Fmt.str "%d is merlint's to spend" status)
        true
        (Exit_status.reserved_reason status = None))
    [ 0; 1; 2; 3; 4; 5; 6; 7; 8; 100 ]

let test_mask_spells_no_reserved_value () =
  List.iter
    (fun status ->
      match Exit_status.reserved_reason status with
      | None -> ()
      | Some why ->
          Alcotest.failf "merlint's exit-status mask can spell %d, which is %s"
            status why)
    Exit_status.all

(* One question per bit. A bit that is not a power of two, or that overlaps one
   already declared, sets a bit some other question owns, and the two answers
   are back in one number a caller cannot take apart. *)
let test_each_bit_answers_one_question () =
  let claimed =
    List.fold_left
      (fun claimed bit ->
        if bit <= 0 || bit land (bit - 1) <> 0 then
          Alcotest.failf "%d is not a single bit" bit;
        if claimed land bit <> 0 then
          Alcotest.failf "bit %d is already claimed by another question" bit;
        claimed lor bit)
      0 Exit_status.bits
  in
  Alcotest.(check bool) "the mask has bits" true (claimed <> 0)

let check_status name expected actual =
  Alcotest.(check int) name expected actual

let test_of_run_reports_what_the_run_found () =
  check_status "a complete run with nothing to report" 0
    (Exit_status.of_run ~findings:0 ~unchecked:0 ~skipped:0 ~failed:0);
  check_status "findings over a complete run" Exit_status.findings
    (Exit_status.of_run ~findings:3 ~unchecked:0 ~skipped:0 ~failed:0);
  check_status "a file no rule read" Exit_status.incomplete
    (Exit_status.of_run ~findings:0 ~unchecked:1 ~skipped:0 ~failed:0);
  check_status "a path merlint has no rule for" Exit_status.incomplete
    (Exit_status.of_run ~findings:0 ~unchecked:0 ~skipped:1 ~failed:0);
  check_status "a check that raised" Exit_status.incomplete
    (Exit_status.of_run ~findings:0 ~unchecked:0 ~skipped:0 ~failed:1);
  check_status "findings over a run that read part of the tree"
    (Exit_status.findings lor Exit_status.incomplete)
    (Exit_status.of_run ~findings:1 ~unchecked:1 ~skipped:0 ~failed:0)

(* A run that got as far as counting anything is a run that looked, so it never
   answers with the status that says nothing was analysed. *)
let test_of_run_never_refuses () =
  List.iter
    (fun status ->
      if status <> Exit_status.refused && status land Exit_status.refused <> 0
      then Alcotest.failf "of_run answered %d, which claims a refusal" status)
    (List.filter (fun s -> s <> Exit_status.refused) emitted)

let test_every_status_is_in_the_manual () =
  List.iter
    (fun status ->
      Alcotest.(check bool)
        (Fmt.str "the manual documents status %d" status)
        true
        (List.mem status documented))
    emitted

(* The other direction: a documented status merlint cannot return is a manual
   entry describing a run that never happens. cmdliner's own two are the
   exception -- [Cmd.eval] returns them, merlint does not choose them. *)
let test_the_manual_documents_nothing_else () =
  let cmdliner_own =
    [ Cmdliner.Cmd.Exit.cli_error; Cmdliner.Cmd.Exit.internal_error ]
  in
  List.iter
    (fun status ->
      Alcotest.(check bool)
        (Fmt.str "merlint can return the documented status %d" status)
        true
        (List.mem status emitted || List.mem status cmdliner_own))
    documented

let suite =
  ( "exit_status",
    [
      Alcotest.test_case "reserved values are named" `Quick
        test_reserved_reason_names_the_reserved;
      Alcotest.test_case "the mask spells no reserved value" `Quick
        test_mask_spells_no_reserved_value;
      Alcotest.test_case "each bit answers one question" `Quick
        test_each_bit_answers_one_question;
      Alcotest.test_case "of_run reports what the run found" `Quick
        test_of_run_reports_what_the_run_found;
      Alcotest.test_case "of_run never refuses" `Quick test_of_run_never_refuses;
      Alcotest.test_case "every status is in the manual" `Quick
        test_every_status_is_in_the_manual;
      Alcotest.test_case "the manual documents nothing else" `Quick
        test_the_manual_documents_nothing_else;
    ] )

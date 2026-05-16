(** Tests for Cl_lock — the global compiler-libs mutex. *)

let test_runs_function () =
  let result = Merlint.Cl_lock.with_lock (fun () -> 42) in
  Alcotest.(check int) "returns inner result" 42 result

let test_propagates_exception () =
  let raised =
    try
      let _ = Merlint.Cl_lock.with_lock (fun () -> failwith "boom") in
      false
    with Failure msg -> msg = "boom"
  in
  Alcotest.(check bool) "propagates Failure" true raised

let test_releases_after_exception () =
  (* If [with_lock] failed to release the mutex on the previous call's
     exception, this second call would deadlock. The test passing means
     release happened. *)
  let raised_once =
    try
      let _ = Merlint.Cl_lock.with_lock (fun () -> failwith "first") in
      false
    with Failure _ -> true
  in
  Alcotest.(check bool) "first call raised" true raised_once;
  let result = Merlint.Cl_lock.with_lock (fun () -> "ok") in
  Alcotest.(check string) "lock re-acquired" "ok" result

let test_serialises_concurrent_access () =
  (* Two domains hammering [with_lock] must observe a count that equals
     the sum of their increments — no lost updates. With no lock, the
     non-atomic read-modify-write on [counter] would lose increments. *)
  let counter = ref 0 in
  let iterations = 10_000 in
  let bump () =
    Merlint.Cl_lock.with_lock (fun () ->
        let n = !counter in
        counter := n + 1)
  in
  let run () =
    for _ = 1 to iterations do
      bump ()
    done
  in
  let d1 = Domain.spawn run in
  let d2 = Domain.spawn run in
  Domain.join d1;
  Domain.join d2;
  Alcotest.(check int) "no lost updates" (2 * iterations) !counter

let suite =
  ( "cl_lock",
    [
      Alcotest.test_case "runs function" `Quick test_runs_function;
      Alcotest.test_case "propagates exception" `Quick test_propagates_exception;
      Alcotest.test_case "releases after exception" `Quick
        test_releases_after_exception;
      Alcotest.test_case "serialises concurrent access" `Quick
        test_serialises_concurrent_access;
    ] )

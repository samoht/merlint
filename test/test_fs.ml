let with_pool f =
  Eio_main.run @@ fun env ->
  Merlint.Fs.with_pool (Eio.Stdenv.domain_mgr env) f

let test_parallel_map_preserves_order () =
  with_pool @@ fun pool ->
  let actual = Merlint.Fs.parallel_map pool [ 3; 1; 2 ] (fun n -> n * n) in
  Alcotest.(check (list int)) "order" [ 9; 1; 4 ] actual

let test_parallel_map_empty () =
  with_pool @@ fun pool ->
  let actual = Merlint.Fs.parallel_map pool [] Fun.id in
  Alcotest.(check (list int)) "empty" [] actual

let test_parallel_map_propagates_exception () =
  with_pool @@ fun pool ->
  let raised =
    try
      ignore
        (Merlint.Fs.parallel_map pool [ 1; 2; 3 ] (fun n ->
             if n = 2 then failwith "boom" else n));
      false
    with Failure _ -> true
  in
  Alcotest.(check bool) "propagates" true raised

let suite =
  ( "fs",
    [
      Alcotest.test_case "parallel_map preserves order" `Quick
        test_parallel_map_preserves_order;
      Alcotest.test_case "parallel_map empty" `Quick test_parallel_map_empty;
      Alcotest.test_case "parallel_map propagates exception" `Quick
        test_parallel_map_propagates_exception;
    ] )

open Merlint

let is_sm = Protocol_modules.is_state_machine_name

let test_vocabulary () =
  let yes =
    [
      "state";
      "client";
      "server";
      "sender";
      "receiver";
      "initiator";
      "responder";
      "requester";
    ]
  in
  List.iter
    (fun n -> Alcotest.(check bool) (n ^ " is a state module") true (is_sm n))
    yes;
  (* Codec/AST/framing modules and ad-hoc names are not state machines, and a
     class-suffixed role is only recognised via allowed_states, not the default
     vocabulary. *)
  let no = [ "message"; "codec"; "packet"; "engine"; "sender1"; "foo" ] in
  List.iter
    (fun n ->
      Alcotest.(check bool) (n ^ " is not a state module") false (is_sm n))
    no

let test_normalization () =
  Alcotest.(check bool) "State.ml" true (is_sm "State.ml");
  Alcotest.(check bool) "lib/Client.mli" true (is_sm "lib/Client.mli");
  Alcotest.(check bool) "SERVER" true (is_sm "SERVER")

let test_role_pairs () =
  let pairs = Protocol_modules.role_pairs in
  Alcotest.(check int) "four role pairs" 4 (List.length pairs);
  List.iter
    (fun (a, b) ->
      Alcotest.(check bool)
        (a ^ " in roles") true
        (List.mem a Protocol_modules.roles);
      Alcotest.(check bool)
        (b ^ " in roles") true
        (List.mem b Protocol_modules.roles))
    pairs;
  (* [responder] pairs with both initiator and requester, but is deduplicated in
     [roles]. *)
  Alcotest.(check int)
    "responder appears once in roles" 1
    (List.length
       (List.filter (String.equal "responder") Protocol_modules.roles))

let suite =
  ( "protocol_modules",
    [
      Alcotest.test_case "vocabulary" `Quick test_vocabulary;
      Alcotest.test_case "normalization" `Quick test_normalization;
      Alcotest.test_case "role_pairs" `Quick test_role_pairs;
    ] )

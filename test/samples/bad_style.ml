(* File using Obj.magic *)
let convert x = Obj.magic x
let identity : 'a -> 'a = fun x -> convert x

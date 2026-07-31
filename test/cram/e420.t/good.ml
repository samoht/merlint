type t = { value : int }
type mode = Fast | Slow
type extensible = ..
type extensible += Added
exception E

module type S = sig
  val run : unit -> unit
end

module M : S = struct
  let run () = ()
end

class c = object
  val mutable iv = 0
  method m = iv
end

class type ct = object
  method n : int
end

let make value =
  M.run ();
  ignore Fast;
  if value < 0 then raise E;
  { value }

module Raw = struct
  type entry = { k : string; v : int }
end

type opts = { metadata : string; retries : int }
type left = { count : int }
type right = { count : int }

let scan opts ~key ?metadata () =
  ignore (opts.metadata, opts.retries, key, metadata);
  0

let expiry (_ : opts) : int option = None
let decode (_ : string) : (int, string) result = Ok 0

type alg = None | HS256
type status = Ok | Error

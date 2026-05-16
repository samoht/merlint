let mutex = Mutex.create ()

let with_lock f =
  Mutex.lock mutex;
  match f () with
  | r ->
      Mutex.unlock mutex;
      r
  | exception exn ->
      Mutex.unlock mutex;
      raise exn

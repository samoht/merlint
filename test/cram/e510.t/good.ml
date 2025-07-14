let log_src = Logs.Src.create "myapp.process"
module Log = (val Logs.src_log log_src : Logs.LOG)

let process () = Log.info (fun m -> m "processing")
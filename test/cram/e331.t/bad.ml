(* Bad examples - functions with redundant prefixes *)

(* Define necessary types *)
type user = { name : string; email : string; id : int }
type project = { name : string; title : string; description : string; status : string }

module Widget = struct
  let make ~visible ~bordered = (visible, bordered)
  let construct config = config
end

(* create_ prefix examples *)
let create_user name email = { name; email; id = 0 }
let create_project title = { name = ""; title; description = ""; status = "" }
let create_widget ~visible ~bordered = Widget.make ~visible ~bordered

(* get_ prefix examples *)
let get_name user = user.name
let get_email user = user.email 
let get_status project = project.status

(* find_ prefix examples *)
let find_user_by_id users id = List.find_opt (fun u -> u.id = id) users
let find_project_by_name projects name = List.find_opt (fun p -> p.name = name) projects

(* Module.create_module pattern *)
module Progress = struct
  type t = { current : int; total : int }
  
  let create_progress current total = { current; total }
end

module User = struct
  type t = { name : string; email : string }
  
  let create_user name email = { name; email }
end

(* More aggressive cases that should be flagged *)
let create_temp_file prefix = Filename.temp_file prefix ".tmp"
let make_widget config = Widget.construct config
let get_current_time () = Unix.gettimeofday ()
let find_free_port start_port = start_port + 1  (* dummy implementation *)
let find_next_available_port start_port = find_free_port start_port
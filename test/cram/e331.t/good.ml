(* Good examples - functions without redundant prefixes *)

(* Define necessary types *)
type user = { name : string; email : string; id : int }
type project = { name : string; title : string; description : string; status : string }

module Widget = struct
  let make ~visible ~bordered = (visible, bordered)
  let construct config = config
end

module Filesystem = struct
  let find path = path
end

module Http = struct
  let get remote = remote
end

module Db = struct
  let query db query = (db, query)
end

(* Direct constructor-style functions *)
let user name email = { name; email; id = 0 }
let project title = { name = ""; title; description = ""; status = "" }
let widget ~visible ~bordered = Widget.make ~visible ~bordered

(* Property accessors *)
let name user = user.name
let email user = user.email 
let status project = project.status

(* Finders returning options *)
let user_by_id users id = List.find_opt (fun u -> u.id = id) users
let project_by_name projects name = List.find_opt (fun p -> p.name = name) projects

(* Good module patterns *)
module Progress = struct
  type t = { current : int; total : int }
  
  let v current total = { current; total }
  let create current total = { current; total }
end

module User = struct
  type t = { name : string; email : string }
  
  let v name email = { name; email }
  let create name email = { name; email }
end

(* Helper function *)
let construct_user data = data

(* These are fine - different semantic meanings *)
let build_user data = construct_user data  (* build vs create *)
let build_widget config = Widget.construct config  (* build vs make *)
let fetch_name remote = Http.get remote     (* fetch vs get *)
let retrieve_email user = user.email       (* retrieve vs get *)
let search_user db query = Db.query db query (* search vs find *)
let locate_file path = Filesystem.find path  (* locate vs find *)
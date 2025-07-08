type config = {
  max_complexity : int;
  max_function_length : int;
}

val default_config : config

type location = {
  file : string;
  line : int;
  col : int;
}

type violation = 
  | ComplexityExceeded of {
      name : string;
      location : location;
      complexity : int;
      threshold : int;
    }
  | FunctionTooLong of {
      name : string;
      location : location;
      length : int;
      threshold : int;
    }

val analyze_structure : config -> Yojson.Safe.t -> violation list

val format_violation : violation -> string
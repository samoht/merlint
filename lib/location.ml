include Merlin.Location

let pp ppf loc = Fmt.pf ppf "%s:%d:%d" loc.file loc.start.line loc.start.col

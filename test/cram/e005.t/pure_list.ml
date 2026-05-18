type standard =
  | Accept
  | Accept_encoding
  | Accept_language
  | Accept_ranges
  | Allow

let standard_wire_names : ([ `Standard of standard | `Other ] * string) list =
  [
    (`Standard Accept, "Accept");
    (`Standard Accept_encoding, "Accept-Encoding");
    (`Standard Accept_language, "Accept-Language");
    (`Standard Accept_ranges, "Accept-Ranges");
    (`Standard Allow, "Allow");
    (`Other, "Other");
    (`Standard Accept, "Accept");
    (`Standard Accept_encoding, "Accept-Encoding");
    (`Standard Accept_language, "Accept-Language");
    (`Standard Accept_ranges, "Accept-Ranges");
    (`Standard Allow, "Allow");
    (`Other, "Other");
    (`Standard Accept, "Accept");
    (`Standard Accept_encoding, "Accept-Encoding");
    (`Standard Accept_language, "Accept-Language");
    (`Standard Accept_ranges, "Accept-Ranges");
    (`Standard Allow, "Allow");
    (`Other, "Other");
    (`Standard Accept, "Accept");
    (`Standard Accept_encoding, "Accept-Encoding");
    (`Standard Accept_language, "Accept-Language");
    (`Standard Accept_ranges, "Accept-Ranges");
    (`Standard Allow, "Allow");
    (`Other, "Other");
    (`Standard Accept, "Accept");
    (`Standard Accept_encoding, "Accept-Encoding");
    (`Standard Accept_language, "Accept-Language");
    (`Standard Accept_ranges, "Accept-Ranges");
    (`Standard Allow, "Allow");
    (`Other, "Other");
    (`Standard Accept, "Accept");
    (`Standard Accept_encoding, "Accept-Encoding");
    (`Standard Accept_language, "Accept-Language");
    (`Standard Accept_ranges, "Accept-Ranges");
    (`Standard Allow, "Allow");
    (`Other, "Other");
    (`Standard Accept, "Accept");
    (`Standard Accept_encoding, "Accept-Encoding");
    (`Standard Accept_language, "Accept-Language");
    (`Standard Accept_ranges, "Accept-Ranges");
    (`Standard Allow, "Allow");
    (`Other, "Other");
    (`Standard Accept, "Accept");
    (`Standard Accept_encoding, "Accept-Encoding");
    (`Standard Accept_language, "Accept-Language");
    (`Standard Accept_ranges, "Accept-Ranges");
    (`Standard Allow, "Allow");
    (`Other, "Other");
    (`Standard Accept, "Accept");
    (`Standard Accept_encoding, "Accept-Encoding");
    (`Standard Accept_language, "Accept-Language");
    (`Standard Accept_ranges, "Accept-Ranges");
    (`Standard Allow, "Allow");
    (`Other, "Other");
  ]

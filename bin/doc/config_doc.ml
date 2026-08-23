(** Documentation for [merlint.toml] -- both the cmdliner man-page blocks that
    drive [merlint help config] and the raw TOML examples that the config-parser
    test suite round-trips. Keeping the strings in one place means the docs
    can't drift from the parser: if an example stops parsing, [test_config_doc]
    fails. *)

(* Each example is a small, complete [merlint.toml] fragment. They are the
   source of truth for both the man page and the test fixture. *)

let example_settings =
  "max-complexity = 15              # cyclomatic complexity (default 10)\n\
   max-function-length = 100        # function length in lines (default 50)\n\
   max-nesting = 5                  # max nesting depth (default 4)\n\
   exempt-data-definitions = true   # don't measure pure-data length\n\n\
   max-underscores-in-name = 2      # max underscores in identifiers\n\
   min-name-length-underscore = 5\n\n\
   allow-obj-magic = false\n\
   allow-str-module = false\n\
   allow-catch-all-exceptions = false\n\n\
   require-ocamlformat-file = true\n\
   require-mli-files = true"

let example_allowed_words =
  "allowed_words = [\"create_table\", \"EdDSA\", \"ECDSA\"]"

let example_workspace = "workspace = \"../mono\""

let example_rules_single_glob =
  "[[rules]]\nfiles = \"lib/prose*.ml\"\nexclude = [\"E330\"]"

let example_rules_files_list =
  "[[rules]]\n\
   files = [\"lib/color.ml*\", \"lib/margin.ml*\", \"lib/padding.ml*\"]\n\
   exclude = [\"E330\"]"

let example_rules_recursive_glob =
  "[[rules]]\nfiles = \"test/**/*.ml\"\nexclude = [\"E400\", \"E410\"]"

let example_rules_skip_file =
  "[[rules]]\nfiles = \"vendor/**/*.ml\"\nexclude = [\"*\"]"

let examples =
  [
    ("settings", example_settings);
    ("allowed_words", example_allowed_words);
    ("workspace", example_workspace);
    ("rules: single glob", example_rules_single_glob);
    ("rules: files list", example_rules_files_list);
    ("rules: recursive glob", example_rules_recursive_glob);
    ("rules: skip file", example_rules_skip_file);
  ]

let join_pre xs = String.concat "\n\n" xs

let man_file =
  [
    `S "CONFIGURATION FILE";
    `P
      "$(mname) reads $(b,merlint.toml) by searching upward from the analyzed \
       path to the workspace root (outermost $(b,dune-project)). All found \
       files are merged: settings from closer files override outer ones, while \
       rule exclusions accumulate. Use $(b,--show-config) on the main command \
       to verify the loaded configuration.";
  ]

let man_settings =
  [
    `S "SETTINGS";
    `P
      "Top-level keys override default thresholds and toggles. All names use \
       kebab-case.";
    `Pre example_settings;
    `P
      "$(b,allowed_words) lists names accepted as-is by naming rules (E300, \
       E331, etc.). $(b,acronyms) is an alias for the same allowlist. For \
       example $(b,create_table) would normally trigger E331 (redundant \
       prefix) but can be exempted:";
    `Pre example_allowed_words;
    `P
      "A key $(mname) does not know stops the run, naming the key, the file it \
       came from, and the known key it is closest to. A misspelt key would \
       otherwise be discarded in silence, leaving the rule it configures at \
       its default while the file reads as though the setting had taken \
       effect.";
  ]

let man_linked_checkouts =
  [
    `S "LINKED CHECKOUTS";
    `P
      "A checkout whose dependencies resolve only inside a larger dune \
       workspace is built there, and its $(b,.cmt)/$(b,.cmti) artefacts are \
       written there too, so $(mname) analyses it as that workspace knows it. \
       $(b,workspace) names the workspace, as a path relative to the \
       $(b,merlint.toml) that sets it; the workspace reaches the checkout \
       through a symlink, and the run is rooted there. Without the declaration \
       the checkout is analysed as a project of its own, where no artefact \
       describes any of its files and every rule that reads a typedtree is \
       skipped.";
    `Pre example_workspace;
  ]

let man_exclusions =
  [
    `S "RULE EXCLUSIONS";
    `P
      "$(b,[[rules]]) blocks exclude specific rule codes for files matching a \
       glob. The $(b,files) field is either a single glob or a list of globs \
       -- the list form is the right shape when one exclude covers a known set \
       of files but a wider glob would catch siblings you want flagged.";
    `Pre
      (join_pre
         [
           "# Single glob";
           example_rules_single_glob;
           "# List of files: one block, many specific paths";
           example_rules_files_list;
           "# Test files: glob with directory recursion";
           example_rules_recursive_glob;
           "# Skip a file entirely";
           example_rules_skip_file;
         ]);
    `P
      "Each entry of a list-form $(b,files) becomes its own pattern -- the \
       second block above is equivalent to three separate $(b,[[rules]]) \
       blocks with the same exclude.";
  ]

let man_patterns =
  [
    `S "PATTERN SYNTAX";
    `P
      "Globs use standard wildcards: $(b,*) (any filename, no $(b,/)), $(b,**) \
       (any number of directories), $(b,?) (single character), and $(b,[abc]) \
       (character class). Rule patterns also accept $(b,*) (all rules) and \
       prefix forms like $(b,E1*) (all rules starting with E1).";
  ]

let man =
  man_file @ man_settings @ man_linked_checkouts @ man_exclusions @ man_patterns

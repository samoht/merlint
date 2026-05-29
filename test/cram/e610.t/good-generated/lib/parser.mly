%token EOF
%start main
%type <unit> main
%%
main: EOF { () } ;

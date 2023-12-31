module SIMPLE-TYPED-STATIC-SYNTAX
  imports DOMAINS-SYNTAX
  syntax Id ::= "main" [token]

  syntax Type ::= "void" | "int" | "bool" | "string"
                | Type "[" "]"
                | "(" Type ")"             [bracket]
                > Types "->" Type

  syntax Types ::= List{Type,","}          [klabel(exps)]
  syntax Param ::= Type Id
  syntax Params ::= List{Param,","}

  syntax Stmt ::= Type Exps ";"
                | Type Id "(" Params ")" Block
  syntax Exp ::= Int | Bool | String | Id
               | "(" Exp ")"             [bracket]
               | "++" Exp
               > Exp "[" Exps "]"        [strict]
               > Exp "(" Exps ")"        [strict]
               | "-" Exp                 [strict]
               | "sizeOf" "(" Exp ")"    [strict]
               | "read" "(" ")"
               > left:
                 Exp "*" Exp             [strict, left]
               | Exp "/" Exp             [strict, left]
               | Exp "%" Exp             [strict, left]
               > left:
                 Exp "+" Exp             [strict, left]
               | Exp "-" Exp             [strict, left]
               > non-assoc:
                 Exp "<" Exp             [strict, non-assoc]
               | Exp "<=" Exp            [strict, non-assoc]
               | Exp ">" Exp             [strict, non-assoc]
               | Exp ">=" Exp            [strict, non-assoc]
               | Exp "==" Exp            [strict, non-assoc]
               | Exp "!=" Exp            [strict, non-assoc]
               > "!" Exp                 [strict]
               > left:
                 Exp "&&" Exp            [strict, left]
               | Exp "||" Exp            [strict, left]
               > "spawn" Block
               > Exp "=" Exp             [strict(2), right]
  syntax Exps ::= List{Exp,","}          [strict, klabel(exps)]
  syntax Block ::= "{" "}"
                | "{" Stmt "}"

  syntax Stmt ::= Block
                | Exp ";"                                  [strict]
                | "if" "(" Exp ")" Block "else" Block      [avoid, strict]
                | "if" "(" Exp ")" Block                   [macro]
                | "while" "(" Exp ")" Block                [strict]
                | "for" "(" Stmt Exp ";" Exp ")" Block     [macro]
                | "return" Exp ";"                         [strict]
                | "return" ";"
                | "print" "(" Exps ")" ";"                 [strict]
                | "try" Block "catch" "(" Param ")" Block  [strict(1)]
                | "throw" Exp ";"                          [strict]
                | "join" Exp ";"                           [strict]
                | "acquire" Exp ";"                        [strict]
                | "release" Exp ";"                        [strict]
                | "rendezvous" Exp ";"                     [strict]
  syntax Stmt ::= Stmt Stmt                             [seqstrict, right]
  rule if (E) S => if (E) S else {}
  rule for(Start Cond; Step) {S:Stmt} => {Start while(Cond){S Step;}}
  rule for(Start Cond; Step) {} => {Start while(Cond){Step;}}
  rule T:Type E1:Exp, E2:Exp, Es:Exps; => T E1; T E2, Es;               [anywhere]
  rule T:Type X:Id = E; => T X; X = E;                                  [anywhere]

endmodule


module SIMPLE-TYPED-STATIC
  imports SIMPLE-TYPED-STATIC-SYNTAX
  imports DOMAINS
  imports SET

  syntax Exp ::= Type
  syntax Exps ::= Types
  syntax BlockOrStmtType ::= "block" | "stmt"
  syntax Type ::= BlockOrStmtType
  syntax Block ::= BlockOrStmtType
  syntax KResult ::= Type
                   | Types    //TODO: remove this, eventually

  configuration <T color="yellow">
                  <tasks color="orange">
                    <task multiplicity="*" color="yellow" type="Set">
                      <k color="green"> $PGM:Stmt </k>
                      <tenv multiplicity="?" color="cyan"> .Map </tenv>
                      <currEnvVar  multiplicity="?" color="DarkGreen"> .Set </currEnvVar>
                      <returnType multiplicity="?" color="Orchid"> void </returnType>
                    </task>
                  </tasks>
//                  <br/>
                  <gtenv color="blue"> .Map </gtenv>
                </T>

  rule <k> T:Type X:Id; => stmt ... </k>
      <tenv> Rho => Rho[X <- T] </tenv>
      <currEnvVar> Phi => Phi SetItem(X) </currEnvVar>
    requires notBool (X in Phi) 

// rule <k> T:Type X:Id; => stmt ... </k>
//         <tenv> Rho => (Rho[X <- T]) </tenv>
//       requires notBool (X in keys(Rho))
  
  rule <task> <k> T:Type X:Id; => stmt ...</k> </task>
       <gtenv> Rho (.Map => X |-> T) </gtenv>
    requires notBool(X in keys(Rho))
  
  
  // rule <k> T:Type X:Id; => stmt ...</k> 
  //     <gtenv> ... Rho2 ... </gtenv>
  //     <tenv> Rho => (Rho[X <- T]) </tenv>
  //     // <gtenv> ... Rho2 ... </gtenv>
  //     // <gtenv> Rho2 </gtenv> 
  //     // <tenv> Rho:Map => (Rho[X <- T]) </tenv>
  //     requires notBool (X in keys(Rho))

  context _:Type _::Exp[HOLE::Exps];
// The rule below may need to sort E to Exp in the future, if the
// parser gets stricter; without that information, it may not be able
// to complete the LHS into T E[int,Ts],.Exps; (and similarly for the RHS)
  rule T:Type E:Exp[int,Ts:Types]; => T[] E[Ts];
// I want to write the rule below as _:Type (E:Exp[.Types] => E),
// but the list completion seems to not work well with that.
  rule T:Type E:Exp[.Types]; => T E;

  rule <task> <k> T:Type F:Id(Ps:Params) S => getTypes(Ps)->T F; ...</k> </task>
       (.Bag => <task>
               <k> mkDecls(Ps) S </k> <tenv> .Map </tenv> <currEnvVar> .Set </currEnvVar> <returnType> T </returnType>
             </task>)

  rule <task> <k> stmt => main(.Exps); </k> (.Bag => <tenv> .Map </tenv>) </task>

  rule <task>... <k> _:BlockOrStmtType </k> <tenv> _ </tenv> <currEnvVar> _ </currEnvVar> ...</task> => .Bag

  rule _:Int => int
  rule _:Bool => bool
  rule _:String => string

  rule <k> X:Id => T ...</k> <tenv>... X |-> T ...</tenv>

  rule <k> X:Id => T ...</k> <tenv> Rho </tenv> <gtenv>... X |-> T ...</gtenv>
    requires notBool(X in keys(Rho))

  rule <task> <k> X:Id => T ...</k> <currEnvVar> Phi </currEnvVar> </task> <gtenv>... X |-> T ...</gtenv>

  context ++(HOLE => ltype(HOLE))
  rule ++ int => int

  rule int + int => int
  rule string + string => string
  rule int - int => int
  rule int * int => int
  rule int / int => int
  rule int % int => int
  rule - int => int
  rule int < int => bool
  rule int <= int => bool
  rule int > int => bool
  rule int >= int => bool
  rule T:Type == T => bool
  rule T:Type != T => bool
  rule bool && bool => bool
  rule bool || bool => bool
  rule ! bool => bool

// NOTE:
// We used to need parentheses in the RHS, to avoid capturing Ts as an attribute
// Let's hope that is not a problem anymore.

  rule (T[])[int, Ts:Types] => T[Ts]
  rule T:Type[.Types] => T

  rule sizeOf(_T[]) => int

  rule read() => int

  rule print(T:Type, Ts => Ts); requires T ==K int orBool T ==K string
  rule print(.Types); => stmt

  context (HOLE => ltype(HOLE)) = _
  rule T:Type = T => T

  rule (Ts:Types -> T)(Ts) => T requires Ts =/=K .Types
  rule (void -> T)(.Types) => T

  rule <k> return T:Type; => stmt ...</k> <returnType> T </returnType>
  rule <k> return; => stmt ...</k> <returnType> _ </returnType>

  rule {} => block

  rule <task> <k> {S} => block ...</k> <tenv> Rho </tenv> <currEnvVar> _ </currEnvVar> R </task>
       (.Bag => <task> <k> S </k> <tenv> Rho </tenv> <currEnvVar> .Set </currEnvVar> R </task>)

  rule _:Type; => stmt

  rule if (bool) block else block => stmt
  rule while (bool) block => stmt

  rule try block catch(int X:Id) {S} => {int X; S}
  rule try block catch(int X:Id) {} => {int X;}
  rule throw int; => stmt

  rule <k> spawn S => int ...</k> <tenv> Rho </tenv> <currEnvVar> Phi </currEnvVar>
       (.Bag => <task> <k> S </k> <tenv> Rho </tenv> <currEnvVar> Phi </currEnvVar> </task>)
  rule join int; => stmt
  rule acquire _:Type; => stmt
  rule release _:Type; => stmt
  rule rendezvous _:Type; => stmt

  rule _:BlockOrStmtType _:BlockOrStmtType => stmt

  syntax Stmt ::= mkDecls(Params)  [function]
  rule mkDecls(T:Type X:Id, Ps:Params) => T X; mkDecls(Ps)
  rule mkDecls(.Params) => {}

  syntax LValue ::= Id
  rule isLValue(_:Exp[_:Exps]) => true
  syntax Exp ::= LValue  // K should be able to infer this
                         // if not added, then it gets stuck with an Id on k cell

// Instead of the second LValue production above you can use a rule:
//  rule isLValue(_:Exp[_:Exps]) => true

  syntax Exp ::= ltype(Exp)
//  context ltype(HOLE:LValue)
// The above context does not work due to some error, so we write instead
  context ltype(HOLE) requires isLValue(HOLE)

  syntax Types ::= getTypes(Params)  [function]
  rule getTypes(T:Type _:Id) => T, .Types   // I would like to not use .Types
  rule getTypes(T:Type _:Id, P, Ps) => T, getTypes(P,Ps)
  rule getTypes(.Params) => void, .Types

endmodule
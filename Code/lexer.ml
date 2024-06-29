(*
 *  Name : Elowan
 *  Creation : 26-06-2024 23:26:07
 *  Last modified : 26-06-2024 23:26:07
 *  File : lexer.ml
 *)

type lexem_type =
  | LCst of int | LSymb of string
  | LLeft | LRight
  | LWrite
  | LGoto
  | LEnd
  | LMove
  | LIf | LGo
  | LNothing
  | LSemiColon

type lexem = int * lexem_type (* Le num de ligne et le lexem *)

let motcles = [
  LLeft; LRight;
  LWrite;
  LGoto;
  LEnd;
  LMove;
  LIf; LGo;
  LNothing;
  LSemiColon;
]

let lexique = [
  "Left"; "Right";
  "Write";
  "Goto";
  "End";
  "Move";
  "If"; "Go";
  "Nothing";
  ";"
]

let minuscules = "_abcdefghijklmnopqrstuvwxyz"

type automate = {
  mutable nb : int; (* Nombre d'états *)
  final : (int, lexem_type) Hashtbl.t;
  delta : (int * char, int) Hashtbl.t
}

let lexeur = 
  let final = Hashtbl.create 64 in
  let delta = Hashtbl.create 64 in
  {nb = 1; final= final; delta=delta}

let ajouter_transition (q: int) (a: char): int =
  match Hashtbl.find_opt lexeur.delta (q, a) with
  | None -> Hashtbl.add lexeur.delta (q, a) (lexeur.nb);
            lexeur.nb <- lexeur.nb + 1; Hashtbl.find lexeur.delta (q, a) 
  | Some q' -> q'

let ajouter_lexeme (s: string) (l: lexem_type): unit = 
  let q = ref 0 in
  for i=0 to String.length s - 1 do
    q := ajouter_transition !q s.[i]
  done;
  Hashtbl.add lexeur.final !q l

let init () = 
  (* Ajout des lexems *)
  let rec aux l1 l2 = match l1, l2 with 
    | h1::q1, h2::q2  -> ajouter_lexeme h1 h2; aux q1 q2
    | _, _            -> ()
  in aux lexique motcles;

  (* Ajout des contantes *)
  let etat_cst = lexeur.nb in 
  for i=0 to 9 do 
    Hashtbl.add lexeur.delta (0, (string_of_int i).[0]) etat_cst; 
    Hashtbl.add lexeur.delta (etat_cst, (string_of_int i).[0]) etat_cst;
    Hashtbl.add lexeur.final etat_cst (LCst(0));
  done;
  lexeur.nb <- lexeur.nb + 1;

  (* Ajout des variables *)
  let etat_var = lexeur.nb in 
  for i=0 to String.length minuscules - 1 do 
    Hashtbl.add lexeur.delta (0, minuscules.[i]) etat_var; 
    Hashtbl.add lexeur.delta (etat_var, minuscules.[i]) etat_var;
    Hashtbl.add lexeur.final etat_var (LSymb(""));
  done;
  lexeur.nb <- lexeur.nb + 1

let compile_lexem (s:string) (i: int) (j: int) (lex: lexem_type): (lexem_type * int) option =
  match lex with 
    | LCst(_) -> Some (LCst(int_of_string(String.trim (String.sub s i (j-i)))), j)
    | LSymb(_) -> Some (LSymb(String.trim (String.sub s i (j-i))), j)
    | _ -> Some (lex, j)
  
let plus_long_lexem (s:string) (i:int): (lexem_type * int) option =
  let rec pll j q = 
    if String.length s <= j || s.[j] = ' ' || 
      s.[j] = '\t' || s.[j] = '\n' 
    then
      match Hashtbl.find_opt lexeur.final q with 
      | None -> None
      | Some lex -> compile_lexem s (i) (j) lex
    else
      match Hashtbl.find_opt lexeur.final q with
        | None -> 
          (
            match Hashtbl.find_opt lexeur.delta (q, s.[j]) with
              | None -> None
              | Some q' -> pll (j+1) q'
          )
        | Some lex -> 
          (
            match Hashtbl.find_opt lexeur.delta (q, s.[j]) with
              | None -> compile_lexem s (i) (j) lex
              | Some q' -> pll (j+1) q'
          )
  in pll i 0

let analyse (s: string) (line: int): lexem list =
  let n = String.length s in
  let rec aux i acc = match i with 
    | i when i < n -> 
      (
        if s.[i] = ' ' || s.[i] = '\t' || s.[i] = '\n' then aux (i+1) acc
        else
          match plus_long_lexem s (i) with 
            | Some (lex, j) -> aux j ((line, lex)::acc)
            | None -> failwith "Erreur lexicale"
      )
    | _ -> acc
  in aux 0 []

let analyse_fichier (filename:string): lexem list = 
  let ic = open_in_bin filename in

  (* Itère sur toutes les lignes *)
  let rec aux line acc = 
    try
      let s = input_line ic in
      aux (line+1) ((analyse s line)@acc)
    with End_of_file -> (
      close_in ic;
      acc
    )
  in List.rev(aux 1 [])


let _ =
  init();
  analyse_fichier "luring_programs/ex1.lu"
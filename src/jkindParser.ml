(* This file is part of the Kind 2 model checker.

   Copyright (c) 2014 by the Board of Trustees of the University of Iowa

   Licensed under the Apache License, Version 2.0 (the "License"); you
   may not use this file except in compliance with the License.  You
   may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0 

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
   implied. See the License for the specific language governing
   permissions and limitations under the License. 

*)

open Lib

module HH = HString.HStringHashtbl
module HS = HStringSExpr
module D = GenericSMTLIBDriver
module TS = TransSys
module SVMap = StateVar.StateVarMap

module Conv = SMTExpr.Converter(D)
let conv = D.smtlib_string_sexpr_conv
let conv_type_of_sexpr = conv.D.type_of_sexpr
let conv_term_of_sexpr = conv.D.expr_of_string_sexpr conv


let s_define_fun = HString.mk_hstring "define-fun"
let s_declare_fun = HString.mk_hstring "declare-fun"
let s_set_option = HString.mk_hstring "set-option"
let s_T = HString.mk_hstring "T"
let s_pinit = HString.mk_hstring "%init"
let s_assert = HString.mk_hstring "assert"
let s_leq = HString.mk_hstring "<="
let s_and = HString.mk_hstring "and"

let jkind_scope = ["jKind"]

let jkind_options = [
  "-scratch";
  "-no_inv_gen";
  "-no_k_induction";
  "-pdr_max 0";
  "-n 0";
  "-scratch";
  "-solver z3"
]

let jkind_command_line file =
  let jkind = Flags.jkind_bin () in
  String.concat " " (jkind :: jkind_options @ [file; "&> /dev/null"])

(* Remove let bindings by propagating the values *)
let unlet_term term = Term.construct (Term.eval_t (fun t _ -> t) term)


let print_vars_path sys =
  match TS.get_source sys with
  | TS.Lustre nodes ->

    let model_path = Model.path_of_term_list (List.map (fun sv ->
        let tv = Term.mk_var (Var.mk_state_var_instance sv Numeral.zero) in
        sv, [tv;tv;tv;tv]
      ) (TS.state_vars sys)) in


    let fmt = !log_ppf in    
    Format.fprintf fmt "STATE VARS MAPBACK:@.%a"
      (LustrePath.pp_print_path_pt nodes false) model_path;
    Format.fprintf fmt "@.";
    Format.fprintf fmt "END@.";
    
  | _ -> assert false

let print_vars_path sys =
  match TS.get_source sys with
  | TS.Lustre nodes ->

    let lustre_vars =
      LustrePath.reconstruct_lustre_streams nodes (TS.state_vars sys) in
    
    Format.eprintf "STATE VARS MAPBACK:@.";
    SVMap.iter (fun sv lusv ->
        Format.eprintf "%a ->@." StateVar.pp_print_state_var sv;

        List.iter (fun (svlu, parents) ->
            List.iter (fun (svp, n) ->
                Format.eprintf " %a~%d" (LustreIdent.pp_print_ident true) svp n)
              parents;
            Format.eprintf " . %a@." StateVar.pp_print_state_var svlu
          ) lusv
      ) lustre_vars;
    
    Format.eprintf "@.";
    Format.eprintf "END@.";
    
  | _ -> assert false


let jkind_var_of_lustre kind_sv (li, parents) =
  let base_li = StateVar.name_of_state_var li in
  (* Ignore main top level node for jkind *)
  let parents_wo_main = List.tl parents in
  let strs = List.fold_left (fun acc (ni, n) ->
      let bni = List.hd (LustreIdent.scope_of_ident ni) in
      (bni^"~"^(string_of_int n)) :: acc
    ) [base_li] (List.rev parents_wo_main) in
  let str = Format.sprintf "$%s$" (String.concat "." strs) in
  StateVar.mk_state_var
    ~is_input:(StateVar.is_input kind_sv)
    ~is_const:(StateVar.is_const kind_sv)
    ~for_inv_gen:(StateVar.for_inv_gen kind_sv)
    str [] (StateVar.type_of_state_var kind_sv)


let jkind_vars_of_kind2_statevar lustre_vars sv =
  let lus_vs = SVMap.find sv lustre_vars in
  List.map (jkind_var_of_lustre sv) lus_vs





let state_vars_path sys =
  match TS.get_source sys with
  | TS.Lustre nodes ->

    let lustre_vars =
      LustrePath.reconstruct_lustre_streams nodes (TS.state_vars sys) in

    Format.eprintf "STATE VARS MAPBACK:";
    List.iter (fun sv ->
        Format.eprintf "\n%a -> " StateVar.pp_print_state_var sv;
        try
          List.iter (fun sv_jk ->
            Format.eprintf "%a , " StateVar.pp_print_state_var sv_jk;
            ) (jkind_vars_of_kind2_statevar lustre_vars sv)
        with Not_found -> Format.eprintf "(ignored)"
      ) (TS.state_vars sys);
    
    Format.eprintf "@.";
    Format.eprintf "END@.";
    
  | _ -> assert false



type jkind_raw = {
  jk_statevars : StateVar.t list;
  jk_trans : Term.lambda option;
}

let jkind_empty = {
  jk_statevars = [];
  jk_trans = None;
}


let rec vars_of_args acc = function
  | [] -> List.rev acc
  | HS.List [HS.Atom v; ty] :: args ->
    let tyv = conv_type_of_sexpr ty in
    let var = Var.mk_free_var v tyv in
    vars_of_args (var :: acc) args
  | _ -> failwith "Not a variable"


let state_var_name_of_jkdecl h =
  let s = HString.string_of_hstring h in
  try Scanf.sscanf s "$%s@$~1" (fun x -> "$"^x^"$")
  with End_of_file | Scanf.Scan_failure _ -> s

let rec parse acc = function

  (* Ignore set-option *)
  | HS.List (HS.Atom s :: _) :: r when s == s_set_option ->
    parse acc r

  (* Definition of transition relation *)
  | HS.List [HS.Atom s; HS.Atom t; HS.List args;
             HS.Atom _ (* return type *);
             hdef] :: r
    when s == s_define_fun &&
         t == s_T ->

    let argsv = vars_of_args [] args in
    let bvars = List.map (fun v -> Var.hstring_of_free_var v, v) argsv in
    let lamb = Term.mk_lambda argsv (conv_term_of_sexpr bvars hdef) in
    
    parse { acc with jk_trans = Some lamb } r

  (* Ignore %init state variable *)
  | HS.List (HS.Atom s :: HS.Atom i :: HS.List [] :: ty :: []) :: r
    when s == s_declare_fun &&
         i == s_pinit ->
    parse acc r

  (* Declaration of state variable *)
  | HS.List (HS.Atom s :: HS.Atom sv :: HS.List [] :: ty :: []) :: r
    when s == s_declare_fun ->

    let tysv = conv_type_of_sexpr ty in
    let s = state_var_name_of_jkdecl sv in
    let sv = StateVar.mk_state_var s jkind_scope tysv in

    parse { acc with jk_statevars = sv :: acc.jk_statevars } r

  (* Range constraints *)
  | HS.List [HS.Atom ass;
             HS.List [HS.Atom conj;
                      HS.List [HS.Atom leq1; HS.Atom l; HS.Atom t1];
                      HS.List [HS.Atom leq2; HS.Atom t2; HS.Atom u]]
            ] :: r
    when ass == s_assert &&
         conj == s_and &&
         leq1 == s_leq &&
         leq2 == s_leq &&
         t1 == t2 ->

    let s = state_var_name_of_jkdecl t1 in
    let sv = StateVar.state_var_of_string (s, jkind_scope) in
    let l = Numeral.of_string (HString.string_of_hstring l) in
    let u = Numeral.of_string (HString.string_of_hstring u) in
    let range_ty = Type.mk_int_range l u in
    (* Change type of variable *)
    StateVar.change_type_of_state_var sv range_ty;

    parse acc r

  (* Finished parsing *)
  | [] -> acc

  (* Unsupported *)
  | _ -> failwith "Unsupported sexp in jKind output"


(* Parse from input channel *)
let of_channel in_ch =

  let lexbuf = Lexing.from_channel in_ch in
  let sexps = SExprParser.sexps SExprLexer.main lexbuf in

  let jk_statevars, jk_trans =
    match parse jkind_empty sexps with
    | { jk_statevars; jk_trans = Some jk_trans } -> jk_statevars, jk_trans
    | _ -> assert false
  in

  let statevars = List.rev jk_statevars in
  
  let vars_types = List.map StateVar.type_of_state_var statevars in
  
  let statevars0 = List.map (fun sv ->
      Var.mk_state_var_instance sv Numeral.zero)
      statevars in

  let statevars1 = List.map (fun sv ->
      Var.mk_state_var_instance sv Numeral.one)
      statevars in

  let t_statevars0 = List.map Term.mk_var statevars0 in
  let t_statevars1 = List.map Term.mk_var statevars1 in
  
  (* Predicate symbol for initial state predicate *)
  let init_uf_symbol = 
    UfSymbol.mk_uf_symbol
      (LustreIdent.init_uf_string ^ "jKind") 
      vars_types
      Type.t_bool 
  in

  (* Predicate symbol for transition relation predicate *)
  let trans_uf_symbol = 
    UfSymbol.mk_uf_symbol
      (LustreIdent.trans_uf_string ^ "jKind") 
      (vars_types @ vars_types)
      Type.t_bool 
  in

  (* Format.eprintf "LAMBDA:\n%a@." Term.pp_print_lambda jk_trans; *)

  (* List.iter (fun t -> *)
  (*     Format.eprintf "  >> %a@." Term.pp_print_term t) *)
  (*   (Term.t_true :: t_statevars0 @ t_statevars0); *)
  
  let init_term =
    Term.eval_lambda jk_trans (Term.t_true :: t_statevars0 @ t_statevars0)
    |> unlet_term
  in

  let trans_term =
    Term.eval_lambda jk_trans (Term.t_false :: t_statevars0 @ t_statevars1)
    |> unlet_term
  in
  
  let init = init_uf_symbol, (statevars0, init_term) in
  let trans = trans_uf_symbol, (statevars1 @ statevars0, trans_term) in

  TransSys.mk_trans_sys
    jkind_scope
    statevars
    init trans
    (* No subsystems, no properties *)
    [] []
    TransSys.Native



let get_jkind_transsys file =

  (* Make temporary copy of input file *)
  let base = Filename.basename file in
  let tmp = Filename.temp_file base ".lus" in
  file_copy file tmp;

  (* Format.eprintf "TMEP %s @." tmp; *)
  
  (* Run jKind on temporary copy *)
  if Sys.command (jkind_command_line tmp) <> 0 then
    failwith "jKind execution failed";

  (* open dump file and parse *)
  let dump_file = tmp ^ ".bmc.smt2" in
  let in_ch = open_in dump_file in
  let sys = of_channel in_ch in

  (* Close file *)
  close_in in_ch;

  sys




(* 
   Local Variables:
   compile-command: "make -C .. -k"
   indent-tabs-mode: nil
   End: 
*)
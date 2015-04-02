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

(** Extract the transition system fro, the dumpfiles of jKind

    @author Alain Mebsout
*)

(* val state_var_to_jkind : StateVar.t -> string *)

val state_vars_path : TransSys.t -> unit


val jkind_vars_of_kind2_statevar :
  (StateVar.t * (LustreIdent.t * int) list) list StateVar.StateVarMap.t
  -> StateVar.t -> StateVar.t list

val get_jkind_transsys : string -> TransSys.t
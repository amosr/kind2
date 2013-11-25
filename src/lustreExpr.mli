(* This file is part of the Kind verifier

 * Copyright (c) 2007-2009 by the Board of Trustees of the University of Iowa, 
 * here after designated as the Copyright Holder.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the University of Iowa, nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER ''AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *)

type unary_op =
  | Not
  | Uminus

type binary_op =
  | And 
  | Or
  | Xor
  | Impl
  | Mod
  | Minus
  | Plus 
  | Div
  | Times 
  | IntDiv
  | Eq
  | Neq
  | Lte
  | Lt
  | Gte
  | Gt
  | Arrow

type var_op =
  | OneHot

type expr = private
  | Var of LustreIdent.t
  | VarPre of LustreIdent.t
  | True
  | False
  | Int of int
  | Real of float
  | UnaryOp of unary_op * expr
  | BinaryOp of binary_op * (expr * expr)
  | Ite of expr * expr * expr

type t = expr

val t_true : t

val t_false : t

val mk_int : int -> t

val mk_real : float -> t

val mk_var : LustreIdent.t -> t

val mk_var_pre : LustreIdent.t -> t

val mk_unary : unary_op -> t -> t

val mk_binary : binary_op -> t -> t -> t

val mk_ite : t -> t -> t -> t

val mk_not : t -> t

val mk_uminus : t -> t

val mk_and : t -> t -> t 

val mk_or : t -> t -> t 

val mk_xor : t -> t -> t 

val mk_impl : t -> t -> t 

val mk_mod : t -> t -> t 

val mk_minus : t -> t -> t 

val mk_plus : t -> t -> t 

val mk_div : t -> t -> t 

val mk_times : t -> t -> t 

val mk_intdiv : t -> t -> t 

val mk_eq : t -> t -> t 

val mk_neq : t -> t -> t 

val mk_lte : t -> t -> t 

val mk_lt : t -> t -> t 

val mk_gte : t -> t -> t 

val mk_gt : t -> t -> t 

val mk_arraw : t -> t -> t


(* 
   Local Variables:
   compile-command: "make -k"
   indent-tabs-mode: nil
   End: 
*)
  

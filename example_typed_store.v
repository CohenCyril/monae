(* monae: Monadic equational reasoning in Coq                                 *)
(* Copyright (C) 2023 monae authors, license: LGPL-2.1-or-later               *)
Require Import ZArith.
From mathcomp Require Import all_ssreflect.
From mathcomp Require boolp.
From infotheo Require Import ssrZ.
Require monad_model.
From HB Require Import structures.
Require Import monae_lib hierarchy monad_lib typed_store_lib.

(******************************************************************************)
(*                         Typed store examples                               *)
(*                                                                            *)
(*  Inductive ml_type == generated by coqgen                                  *)
(*                                                                            *)
(*  Module MLTypesNat                                                         *)
(*    coq_type_nat          == adapted from code generated by coqgen          *)
(*    coq_type_nat0         == coq_type_nat with identity monad               *)
(*    Definition cycle                                                        *)
(*    Fixpoint fact_ref                                                       *)
(*    Definition fact_for                                                     *)
(*    Fixpoint fibo_ref                                                       *)
(*                                                                            *)
(*  Module MLtypes63                                                          *)
(*    Fixpoint coq_type63   == generated type translation function            *)
(*    Definition fact_for63                                                   *)
(******************************************************************************)

Local Open Scope monae_scope.

(******************************************************************************)
(*                             generated by coqgen                            *)
(******************************************************************************)
Module MLTypes.
Inductive ml_type : Set :=
  | ml_int
  | ml_bool
  | ml_unit
  | ml_ref (_ : ml_type)
  | ml_arrow (_ : ml_type) (_ : ml_type)
  | ml_rlist (_ : ml_type).

Definition ml_type_eq_dec (T1 T2 : ml_type) : {T1=T2}+{T1<>T2}.
revert T2; induction T1; destruct T2;
  try (right; intro; discriminate); try (now left);
  try (case (IHT1_5 T2_5); [|right; injection; intros; contradiction]);
  try (case (IHT1_4 T2_4); [|right; injection; intros; contradiction]);
  try (case (IHT1_3 T2_3); [|right; injection; intros; contradiction]);
  try (case (IHT1_2 T2_2); [|right; injection; intros; contradiction]);
  (case (IHT1 T2) || case (IHT1_1 T2_1)); try (left; now subst);
    right; injection; intros; contradiction.
Defined.

Definition val_nonempty (M : UU0 -> UU0) := tt.

Definition locT := [eqType of nat].

Notation loc := (@loc _ locT).

Inductive rlist (a : Type) (a_1 : ml_type) :=
  | Nil
  | Cons (_ : a) (_ : loc (ml_rlist a_1)).

Definition ml_type_eq_mixin := comparableMixin MLTypes.ml_type_eq_dec.
Canonical ml_type_eqType := Eval hnf in EqType _ ml_type_eq_mixin.

End MLTypes.
(******************************************************************************)

Module MLTypesNat.
Import MLTypes.

Section with_monad.
Context [M : Type -> Type].

Fixpoint coq_type_nat (T : ml_type) : Type :=
  match T with
  | ml_int => nat
  | ml_bool => bool
  | ml_unit => unit
  | ml_arrow T1 T2 => coq_type_nat T1 -> M (coq_type_nat T2)
  | ml_ref T1 => loc T1
  | ml_rlist T1 => rlist (coq_type_nat T1) T1
  end.
End with_monad.

(* use coq_type_nat (typed_store_model.v) *)
HB.instance Definition _ := @isML_universe.Build ml_type
  (Equality.class ml_type_eqType) coq_type_nat ml_unit val_nonempty.

(* alternative: use coq_type_nat0 (monad_model.v) *)
(*Definition coq_type_nat0 := @coq_type_nat idfun.
HB.instance Definition _ := @isML_universe.Build ml_type
  (Equality.class ml_type_eqType) (fun M => @coq_type_nat0) ml_unit
  (fun M => val_nonempty idfun).*)

Section cyclic.
Variables (M : typedStoreMonad ml_type MLTypes.locT).
Local Notation coq_type := (hierarchy.coq_type (MonadTypedStore.sort M)).
Local Open Scope do_notation.

Definition cycle (T : ml_type) (a b : coq_type T)
  : M (coq_type (ml_rlist T)) :=
  do r <- cnew (ml_rlist T) (Nil (coq_type T) T);
  do l <-
  (do v <- cnew (ml_rlist T) (Cons (coq_type T) T b r);
   Ret (Cons (coq_type T) T a v));
  do _ <- cput r l; Ret l.

Definition hd (T : ml_type) (def : coq_type T)
  (param : coq_type (ml_rlist T)) : coq_type T :=
  match param with | Nil => def | Cons a _ => a end.

Lemma hd_is_true :
  crun (do l <- cycle ml_bool true false; Ret (hd ml_bool false l)) = Some true.
Proof.
rewrite bindA.
under eq_bind => tl.
  rewrite !bindA.
  under eq_bind do rewrite !bindA bindretf !bindA bindretf /=.
  rewrite -bindA.
  over.
rewrite -bindA crunret // -bindA_uncurry /= crungetput // bindA.
under eq_bind => tl.
  rewrite !bindA.
  under eq_bind do rewrite bindretf /=.
  over.
by rewrite crungetnew // -(bindskipf (_ >>= _)) crunnewget // crunskip.
Qed.
End cyclic.

Section factorial.
Variable M : typedStoreMonad ml_type MLTypes.locT.
Notation coq_type := (@coq_type M).

Fixpoint fact_ref (r : loc ml_int) (n : nat) : M unit :=
  if n is m.+1 then cget r >>= fun p => cput r (n * p) >> fact_ref r m
  else skip.

Theorem fact_ref_ok n :
  crun (cnew ml_int 1 >>= fun r => fact_ref r n >> cget r) = Some (fact_rec n).
Proof.
set fn := fact_rec n.
set m := n.
set s := 1.
have smn : s * fact_rec m = fn by rewrite mul1n.
elim: m s smn => [|m IH] s /= smn.
  rewrite /fact_ref -smn muln1.
  under eq_bind do rewrite bindskipf.
  by rewrite cnewgetret crunret // crunnew0.
under eq_bind do rewrite bindA.
rewrite cnewget.
under eq_bind do rewrite bindA.
by rewrite cnewput IH // (mulnC m.+1) -mulnA.
Qed.
End factorial.

Section fact_for.
Variable M : typedStoreMonad ml_type MLTypes.locT.
Local Notation coq_type := (hierarchy.coq_type (MonadTypedStore.sort M)).
Local Open Scope do_notation.

Definition fact_for (n : coq_type ml_int) : M (coq_type ml_int) :=
  do v <- cnew ml_int 1;
  do _ <-
  (do u <- Ret 1;
   do v_1 <- Ret n;
   forloop u v_1
     (fun i =>
        do v_1 <- (do v_1 <- cget v; Ret (v_1 * i));
        cput v v_1));
  cget v.

Theorem fact_for_ok n : crun (fact_for n) = Some (fact_rec n).
Proof.
rewrite /fact_for.
under eq_bind do rewrite !bindA !bindretf.
transitivity (crun (cnew ml_int (fact_rec n) >> Ret (fact_rec n) : M _));
  last by rewrite crunret // crunnew0.
congr crun.
rewrite -{1}/(fact_rec 0).
pose m := n.
have -> : 0 = n - m by rewrite subnn.
have : m <= n by [].
elim: m => [|m IH] mn.
  rewrite subn0.
  under eq_bind do rewrite forloop0 ?leqnn // bindretf -cgetret.
  by rewrite cnewget.
rewrite subnSK //.
under eq_bind do (rewrite forloopS; last by apply leq_subr).
under eq_bind do rewrite !bindA.
rewrite cnewget.
under eq_bind do rewrite bindretf.
rewrite cnewput -IH; last by apply ltnW.
by rewrite subnS mulnC -(@prednK (n-m)) // lt0n subn_eq0 -ltnNge.
Qed.
End fact_for.

Section fibonacci.
Variable M : typedStoreMonad ml_type MLTypes.locT.
Local Notation coq_type := (hierarchy.coq_type (MonadTypedStore.sort M)).

Fixpoint fibo_rec n :=
  if n is m.+1 then
    if m is k.+1 then fibo_rec k + fibo_rec m else 1
  else 1.

Fixpoint fibo_ref n (a b : loc ml_int) : M unit :=
  if n is n.+1 then
    cget a >>= (fun x => cget b >>= fun y => cput a y >> cput b (x + y))
           >> fibo_ref n a b
  else skip.

Theorem fibo_ref_ok n :
  crun (cnew ml_int 1 >>=
             (fun a => cnew ml_int 1 >>= fun b => fibo_ref n a b >> cget a))
  = Some (fibo_rec n).
Proof.
set x := 1.
pose y := x.
rewrite -{2}/y.
pose i := n.
rewrite -[in LHS]/i.
have : (x, y) = (fibo_rec (n - i), fibo_rec (n.+1 - i)).
  by rewrite subnn -addn1 addKn.
have : i <= n by [].
elim: i x y => [|i IH] x y Hi.
  rewrite !subn0 => -[-> ->].
  rewrite -/(fibo_rec n.+1).
  under eq_bind do under eq_bind do rewrite /= bindskipf.
  rewrite -cnewchk.
  under eq_bind do rewrite -cgetret cchknewget.
  by rewrite cnewget -bindA crunret // crunnew // crunnew0.
rewrite subSS => -[] Hx Hy.
rewrite -(IH y (x + y) (ltnW Hi)); last first.
  rewrite {}Hx {}Hy; congr pair.
  rewrite subSn 1?ltnW//.
  case: n {IH} => // n in Hi *.
  by rewrite [in RHS]subSn -1?ltnS// subSS subSn -1?ltnS.
rewrite /=.
under eq_bind do under eq_bind do rewrite !bindA.
rewrite -cnewchk.
under eq_bind do rewrite cchknewget.
rewrite cnewget.
under eq_bind do under eq_bind do rewrite !bindA.
under eq_bind do rewrite cnewget.
under eq_bind do under eq_bind do rewrite !bindA.
rewrite -[in LHS]cnewchk.
under eq_bind do rewrite cchknewput.
rewrite cnewput.
by under eq_bind do rewrite cnewput.
Qed.
End fibonacci.

End MLTypesNat.

Require Import PrimInt63.
Require Sint63.

Section Int63.
Definition uint2N (n : int) : nat :=
  if Uint63.to_Z n is Zpos pos then Pos.to_nat pos else 0.
Definition N2int n := Uint63.of_Z (Z.of_nat n).

Lemma ltsbNlesb m n : ltsb m n = ~~ lesb n m.
Proof.
case/boolP: (lesb n m) => /Sint63.lebP nm; apply/Sint63.ltbP => /=;
  by [apply Z.le_ngt | apply Z.nle_gt].
Qed.

Lemma ltsbW m n : ltsb m n -> lesb m n.
Proof. move/Sint63.ltbP/Z.lt_le_incl => mn; by apply/Sint63.lebP. Qed.

Lemma lesb_ltsbS_eq m n : lesb m n -> ltsb n (Uint63.succ m) -> m = n.
Proof.
move/Sint63.lebP => mn /Sint63.ltbP nSm.
move: (nSm).
rewrite Sint63.succ_of_Z -Sint63.is_int; last first.
  split.
    apply Z.le_le_succ_r.
    by case: (Sint63.to_Z_bounded m).
  apply Zlt_le_succ, (Z.le_lt_trans _ _ _ mn), (Z.lt_le_trans _ _ _ nSm).
  by case: (Sint63.to_Z_bounded (Uint63.succ m)).
move/Zlt_le_succ/Zsucc_le_reg => nm.
by apply Sint63.to_Z_inj, Zle_antisym.
Qed.

(* The opposite is not true ! (n = max_int) *)
Lemma ltsbS_lesb m n : ltsb m (Uint63.succ n) -> lesb m n.
Proof.
rewrite -[lesb _ _]negbK -ltsbNlesb => nSm; apply/negP => /[dup] /ltsbW nm.
by rewrite (lesb_ltsbS_eq n m) // => /Sint63.ltbP /Z.lt_irrefl.
Qed.

Lemma uint63_min n : (0 <= Uint63.to_Z n)%Z.
Proof. by case: (Uint63.to_Z_bounded n). Qed.

Lemma uint63_max n : (Uint63.to_Z n < Uint63.wB)%Z.
Proof. by case: (Uint63.to_Z_bounded n). Qed.

Lemma uint2N_pred n : n <> 0%int63 -> uint2N n = (uint2N (Uint63.pred n)).+1.
Proof.
move=> Hn.
rewrite /uint2N Uint63.pred_spec.
case HnZ: (Uint63.to_Z n) => [|m|m].
- rewrite (_ : 0 = Uint63.to_Z 0)%Z // in HnZ.
  move/Uint63.to_Z_inj in HnZ.
  by elim Hn.
- have Hm1 : (0 <= Z.pos m - 1 < Uint63.wB)%Z.
    split. by apply leZsub1, Pos2Z.is_pos.
    apply (Z.lt_trans _ (Z.pos m)).
      by apply leZsub1, Z.le_refl.
    rewrite -HnZ; by apply uint63_max.
  rewrite Zmod_small //.
  case HmZ: (Z.pos m - 1)%Z => [|p|p].
  + by move/Z.sub_move_r: HmZ => /= [] ->.
  + apply Nat2Z.inj => /=.
    rewrite positive_nat_Z Pos2SuccNat.id_succ Pos2Z.inj_succ -HmZ.
    by rewrite (Z.succ_pred (Z.pos m)).
  + by destruct m.
- move: (uint63_min n).
  rewrite HnZ => /Zle_not_lt; elim.
  by apply Zlt_neg_0.
Qed.

Lemma lesb_sub_bounded m n :
  lesb m n -> (0 <= Sint63.to_Z n - Sint63.to_Z m < Uint63.wB)%Z.
Proof.
move/Sint63.lebP => mn.
split. by apply Zle_minus_le_0.
apply
 (Z.le_lt_trans _ (Sint63.to_Z Sint63.max_int - Sint63.to_Z Sint63.min_int))%Z.
  apply leZ_sub.
    by case: (Sint63.to_Z_bounded n).
  by case: (Sint63.to_Z_bounded m).
done.
Qed.

Lemma ltsb_neq m n : ltsb m n -> m <> n.
Proof. by move/Sint63.ltbP/[swap]/(f_equal Sint63.to_Z)-> =>/Z.lt_irrefl. Qed.

(*
Lemma sub0_eq m n : sub m n = 0%int63 -> m = n.
Proof.
rewrite Sint63.sub_of_Z => /(f_equal Uint63.to_Z).
rewrite Uint63.of_Z_spec.
move/Sint63.ltbP in mn.
rewrite Zmod_small.
  rewrite Z.sub_move_r /= => nm.
  rewrite nm in mn.
  by move/Z.lt_irrefl in mn.
by apply /lesb_sub_bounded /Sint63.lebP /Z.lt_le_incl.
Qed.
*)

Lemma ltsb_sub_neq0 m n : ltsb m n -> sub n m <> 0%int63.
Proof.
move=> mn.
rewrite Sint63.sub_of_Z => /(f_equal Uint63.to_Z).
rewrite Uint63.of_Z_spec.
move/Sint63.ltbP in mn.
rewrite Zmod_small.
  rewrite Z.sub_move_r /= => nm.
  rewrite nm in mn.
  by move/Z.lt_irrefl in mn.
by apply /lesb_sub_bounded /Sint63.lebP /Z.lt_le_incl.
Qed.

Lemma sub_succ_pred m n : sub n (Uint63.succ m) = Uint63.pred (sub n m).
Proof.
apply Uint63.to_Z_inj.
rewrite Uint63.sub_spec Uint63.succ_spec Uint63.pred_spec Uint63.sub_spec.
rewrite Zminus_mod Zmod_mod -Zminus_mod Z.sub_add_distr.
apply/esym.
by rewrite Zminus_mod Zmod_mod -Zminus_mod.
Qed.

Lemma uint2N_sub_succ m n : ltsb m n ->
  uint2N (sub n m) = (uint2N (sub n (Uint63.succ m))).+1.
Proof. move/ltsb_sub_neq0 => mn. by rewrite sub_succ_pred uint2N_pred. Qed.

Lemma N2int_succ : {morph N2int : x / x.+1 >-> Uint63.succ x}.
Proof.
move=> x; apply Uint63.to_Z_inj; rewrite Uint63.succ_spec !Uint63.of_Z_spec.
by rewrite Zplus_mod /= Zpos_P_of_succ_nat /Z.succ Zplus_mod Zmod_mod.
Qed.

Lemma N2int_mul : {morph N2int : x y / x * y >-> mul x y}.
Proof.
move=> x y; apply Uint63.to_Z_inj.
by rewrite Uint63.mul_spec !Uint63.of_Z_spec Nat2Z.inj_mul Zmult_mod.
Qed.

Lemma N2int_bounded n :
  (Z.of_nat n <= Sint63.to_Z Sint63.max_int)%Z ->
  (Sint63.to_Z Sint63.min_int <= Z.of_nat n <= Sint63.to_Z Sint63.max_int)%Z.
Proof.
split => //.
apply (Z.le_trans _ 0).
  rewrite -[0%Z]/(Sint63.to_Z 0).
  by case: (Sint63.to_Z_bounded 0).
by apply Zle_0_nat.
Qed.
End Int63.

Module MLtypes63.
Import MLTypes.

(******************************************************************************)
(*                             generated by coqgen                            *)
(******************************************************************************)
Section with_monad.
Context [M : Type -> Type].
Fixpoint coq_type63 (T : ml_type) : Type :=
  match T with
  | ml_int => int
  | ml_bool => bool
  | ml_unit => unit
  | ml_arrow T1 T2 => coq_type63 T1 -> M (coq_type63 T2)
  | ml_ref T1 => loc T1
  | ml_rlist T1 => rlist (coq_type63 T1) T1
  end.
End with_monad.
(******************************************************************************)

HB.instance Definition _ := @isML_universe.Build ml_type
  (Equality.class ml_type_eqType) coq_type63 ml_unit val_nonempty.

(*Canonical ml_type63 := @Build_ML_universe _ coq_type63 ml_unit val_nonempty.*)

Section fact_for_int63.
Variable M : typedStoreMonad ml_type MLTypes.locT.
Local Notation coq_type := (hierarchy.coq_type (MonadTypedStore.sort M)).
Local Open Scope do_notation.

Section forloop63.
Definition forloop63 (n_1 n_2 : int) (b : int -> M unit) : M unit :=
  if Sint63.ltb n_2 n_1 then Ret tt else
  iter (uint2N (sub n_2 n_1)).+1
       (fun (m : M int) => do i <- m; do _ <- b i; Ret (Uint63.succ i))
       (Ret n_1) >> Ret tt.

Lemma forloop63S m n (f : int -> M unit) :
  ltsb m n -> forloop63 m n f = f m >> forloop63 (Uint63.succ m) n f.
Proof.
rewrite /forloop63 => mn.
rewrite ltsbNlesb (ltsbW _ _ mn) /=.
case: ifPn => nSm.
  by move: mn; rewrite ltsbNlesb => /negP; elim; apply ltsbS_lesb.
rewrite ltsbNlesb negbK in nSm.
rewrite uint2N_sub_succ //.
by rewrite iterSr bindretf !bindA iter_bind !bindA.
Qed.

Lemma forloop631 m (f : int -> M unit) :
  forloop63 m m f = f m.
Proof. rewrite /forloop63.
case: (Sint63.ltbP m m) => [/Z.lt_irrefl // | _].
rewrite /= bindA.
rewrite /uint2N Uint63.sub_spec Z.sub_diag Zmod_0_l /=.
by rewrite !(bindretf,bindA) bindmskip.
Qed.

Lemma forloop630 m n (f : int -> M unit) :
  ltsb n m -> forloop63 m n f = skip.
Proof. by rewrite /forloop63 => ->. Qed.
End forloop63.

Definition fact_for63 (n : coq_type ml_int) : M (coq_type ml_int) :=
  do v <- cnew ml_int 1%int63;
  do _ <-
  (do u <- Ret 1%int63;
   do v_1 <- Ret n;
   forloop63 u v_1
     (fun i =>
        do v_1 <- (do v_1 <- cget v; Ret (mul v_1 i));
        cput v v_1));
  cget v.

Section fact_for63_ok.
Variable n : nat.
(* Note: assuming n < max_int rather than n <= max_int is not strictly
   needed, but it simplifies reasoning about loops in concrete code *)
Hypothesis Hn : (Z.of_nat n < Sint63.to_Z Sint63.max_int)%Z.

Let n_bounded :
  (Sint63.to_Z Sint63.min_int <= Z.of_nat n <= Sint63.to_Z Sint63.max_int)%Z.
Proof. by apply N2int_bounded, Z.lt_le_incl. Qed.

Lemma ltsb_succ : ltsb (N2int n) (Uint63.succ (N2int n)).
Proof.
apply/Sint63.ltbP.
rewrite Sint63.succ_spec Sint63.cmod_small.
  by apply/Zle_lt_succ/Z.le_refl.
split.
  apply leZ_addr => //; by case: (Sint63.to_Z_bounded (N2int n)).
apply Z.lt_add_lt_sub_r; by rewrite -Sint63.is_int.
Qed.

Lemma ltsb_subr m : m.+1 < n -> ltsb (N2int (n - m.+1)) (N2int n).
Proof.
move=> Smn.
apply/Sint63.ltbP.
have Hm : n - m.+1 < n.
  rewrite ltn_subLR.
    by rewrite addSn ltnS leq_addl.
  by apply ltnW.
rewrite /N2int -!Sint63.is_int //.
- by apply/inj_lt/ltP.
- move/ltP/inj_lt in Hm.
  by split; apply N2int_bounded, Z.lt_le_incl, (Z.lt_trans _ _ _ Hm).
Qed.

Theorem fact_for63_ok : crun (fact_for63 (N2int n)) = Some (N2int (fact_rec n)).
Proof.
rewrite /fact_for63.
under eq_bind do rewrite !bindA !bindretf.
set fn := N2int (fact_rec n).
transitivity (crun (cnew ml_int fn >> Ret fn : M _));
  last by rewrite crunret // crunnew0.
congr crun.
have {1}-> : (1 = N2int 1)%int63 by [].
rewrite -/(fact_rec 0).
have -> : (1 = Uint63.succ (N2int 0))%int63 by [].
pose m := n.
have -> : 0 = n - m by rewrite subnn.
have : m <= n by [].
elim: m => [|m IH] mn.
  rewrite subn0.
  under eq_bind do rewrite forloop630 (ltsb_succ,bindretf) // -cgetret.
  by rewrite cnewget.
rewrite -N2int_succ subnSK //.
case: m IH mn => [|m] IH mn.
  under eq_bind do rewrite subn0 forloop631 !(ltsb_subr,bindA) //.
  rewrite cnewget.
  under eq_bind do rewrite bindretf -cgetret.
  rewrite cnewput -N2int_mul mulnC -{1}(prednK mn) cnewget subn1.
  by rewrite -/(fact_rec n.-1.+1) prednK.
under eq_bind do rewrite forloop63S !(ltsb_subr,bindA) //.
rewrite cnewget.
under eq_bind do rewrite bindretf.
rewrite cnewput -IH (ltnW,subnS) // -N2int_mul mulnC -(@prednK (n-m.+1)) //.
by rewrite lt0n subn_eq0 -ltnNge.
Qed.
End fact_for63_ok.
End fact_for_int63.

Section eval.
Require Import typed_store_model.

Definition M := [the typedStoreMonad ml_type monad_model.locT_nat of
                 acto ml_type].

Definition Env := typed_store_model.Env ml_type.

Definition empty_env := @typed_store_model.mkEnv ml_type nil.

Definition W T := (Env * T)%type.

Definition it0 : W unit := (empty_env, tt).

Local Open Scope do_notation.

Definition incr (l : loc ml_int) : M int :=
  do x <- cget l; do _ <- cput l (Uint63.succ x); Ret (Uint63.succ x).

Definition evalme := (do l <- @cnew ml_type ml_int 3; incr l)%int63 empty_env.

Eval vm_compute in evalme.

End eval.

End MLtypes63.

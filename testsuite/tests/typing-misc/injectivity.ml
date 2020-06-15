(* TEST
   * expect
*)

(* Syntax *)

type ! 'a t = private 'a ref
type +! 'a t = private 'a
type -!'a t = private 'a -> unit
type + !'a t = private 'a
type - ! 'a t = private 'a -> unit
[%%expect{|
type 'a t = private 'a ref
type +'a t = private 'a
type -'a t = private 'a -> unit
type +'a t = private 'a
type -'a t = private 'a -> unit
|}]
(* Expect doesn't support syntax errors
type -+ 'a t
[%%expect]
type -!! 'a t
[%%expect]
*)

(* Define an injective abstract type, and use it in a GADT
   and a constrained type *)
module M : sig type +!'a t end = struct type 'a t = 'a list end
[%%expect{|
module M : sig type +!'a t end
|}]
type _ t = M : 'a -> 'a M.t t (* OK *)
type 'a u = 'b constraint 'a = 'b M.t
[%%expect{|
type _ t = M : 'a -> 'a M.t t
type 'a u = 'b constraint 'a = 'b M.t
|}]

(* Without the injectivity annotation, the cannot be defined *)
module N : sig type +'a t end = struct type 'a t = 'a list end
[%%expect{|
module N : sig type +'a t end
|}]
type _ t = N : 'a -> 'a N.t t (* KO *)
[%%expect{|
Line 1, characters 0-29:
1 | type _ t = N : 'a -> 'a N.t t (* KO *)
    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Error: In this definition, a type variable cannot be deduced
       from the type parameters.
|}]
type 'a u = 'b constraint 'a = 'b N.t
[%%expect{|
Line 1, characters 0-37:
1 | type 'a u = 'b constraint 'a = 'b N.t
    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Error: In this definition, a type variable cannot be deduced
       from the type parameters.
|}]

(* Of course, the internal type should be injective in this parameter *)
module M : sig type +!'a t end = struct type 'a t = int end (* KO *)
[%%expect{|
Line 1, characters 33-59:
1 | module M : sig type +!'a t end = struct type 'a t = int end (* KO *)
                                     ^^^^^^^^^^^^^^^^^^^^^^^^^^
Error: Signature mismatch:
       Modules do not match:
         sig type 'a t = int end
       is not included in
         sig type +!'a t end
       Type declarations do not match:
         type 'a t = int
       is not included in
         type +!'a t
       Their variances do not agree.
|}]

(* Annotations in type abbreviations allow to check injectivity *)
type !'a t = 'a list
type !'a u = int
[%%expect{|
type 'a t = 'a list
Line 2, characters 0-16:
2 | type !'a u = int
    ^^^^^^^^^^^^^^^^
Error: In this definition, expected parameter variances are not satisfied.
       The 1st type parameter was expected to be injective invariant,
       but it is unrestricted.
|}]
type !'a t = private 'a list
type !'a t = private int
[%%expect{|
type 'a t = private 'a list
Line 2, characters 0-24:
2 | type !'a t = private int
    ^^^^^^^^^^^^^^^^^^^^^^^^
Error: In this definition, expected parameter variances are not satisfied.
       The 1st type parameter was expected to be injective invariant,
       but it is unrestricted.
|}]

(* Can also use to add injectivity in private row types *)
module M : sig type !'a t = private < m : int ; .. > end =
  struct type 'a t = < m : int ; n : 'a > end
type 'a u = M : 'a -> 'a M.t u
[%%expect{|
module M : sig type !'a t = private < m : int; .. > end
type 'a u = M : 'a -> 'a M.t u
|}]
module M : sig type 'a t = private < m : int ; .. > end =
  struct type 'a t = < m : int ; n : 'a > end
type 'a u = M : 'a -> 'a M.t u
[%%expect{|
module M : sig type 'a t = private < m : int; .. > end
Line 3, characters 0-30:
3 | type 'a u = M : 'a -> 'a M.t u
    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Error: In this definition, a type variable cannot be deduced
       from the type parameters.
|}]
module M : sig type !'a t = private < m : int ; .. > end =
  struct type 'a t = < m : int > end
[%%expect{|
Line 2, characters 2-36:
2 |   struct type 'a t = < m : int > end
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Error: Signature mismatch:
       Modules do not match:
         sig type 'a t = < m : int > end
       is not included in
         sig type !'a t = private < m : int; .. > end
       Type declarations do not match:
         type 'a t = < m : int >
       is not included in
         type !'a t
       Their variances do not agree.
|}]

(* Injectivity annotations are inferred correctly for constrained parameters *)
type 'a t = 'b constraint 'a = <b:'b>
type !'b u = <b:'b> t
[%%expect{|
type 'a t = 'b constraint 'a = < b : 'b >
type 'b u = < b : 'b > t
|}]

(* Ignore injectivity for nominal types *)
type !_ t = X
[%%expect{|
type _ t = X
|}]

(* Beware of constrained parameters *)
type (_,_) eq = Refl : ('a,'a) eq
type !'a t = private 'b constraint 'a = < b : 'b > (* OK *)
[%%expect{|
type (_, _) eq = Refl : ('a, 'a) eq
type 'a t = private 'b constraint 'a = < b : 'b >
|}]

type !'a t = private 'b constraint 'a = < b : 'b; c : 'c > (* KO *)
module M : sig type !'a t constraint 'a = < b : 'b; c : 'c > end =
  struct type nonrec 'a t = 'a t end
let inj_t : type a b. (<b:_; c:a> M.t, <b:_; c:b> M.t) eq -> (a, b) eq =
  fun Refl -> Refl
[%%expect{|
Line 1, characters 0-58:
1 | type !'a t = private 'b constraint 'a = < b : 'b; c : 'c > (* KO *)
    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Error: In this definition, expected parameter variances are not satisfied.
       The 1st type parameter was expected to be injective invariant,
       but it is unrestricted.
|}]

(* Motivating examples with GADTs *)

type (_,_) eq = Refl : ('a,'a) eq

module Vec : sig
  type +!'a t
  val make : int -> (int -> 'a) -> 'a t
  val get : 'a t -> int -> 'a
end = struct
  type 'a t = Vec of Obj.t array
  let make n f = Vec (Obj.magic Array.init n f)
  let get (Vec v) n = Obj.obj (Array.get v n)
end

type _ ty =
  | Int : int ty
  | Fun : 'a ty * 'b ty -> ('a -> 'b) ty
  | Vec : 'a ty -> 'a Vec.t ty

type dyn = Dyn : 'a ty * 'a -> dyn

let rec eq_ty : type a b. a ty -> b ty -> (a,b) eq option =
  fun t1 t2 -> match t1, t2 with
  | Int, Int -> Some Refl
  | Fun (t11, t12), Fun (t21, t22) ->
      begin match eq_ty t11 t21, eq_ty t12 t22 with
      | Some Refl, Some Refl -> Some Refl
      | _ -> None
      end
  | Vec t1, Vec t2 ->
      begin match eq_ty t1 t2 with
      | Some Refl -> Some Refl
      | None -> None
      end
  | _ -> None

let undyn : type a. a ty -> dyn -> a option =
  fun t1 (Dyn (t2, v)) ->
    match eq_ty t1 t2 with
    | Some Refl -> Some v
    | None -> None

let v = Vec.make 3 (fun n -> Vec.make n (fun m -> (m*n)))

let int_vec_vec = Vec (Vec Int)

let d = Dyn (int_vec_vec, v)

let Some v' = undyn int_vec_vec d
[%%expect{|
type (_, _) eq = Refl : ('a, 'a) eq
module Vec :
  sig
    type +!'a t
    val make : int -> (int -> 'a) -> 'a t
    val get : 'a t -> int -> 'a
  end
type _ ty =
    Int : int ty
  | Fun : 'a ty * 'b ty -> ('a -> 'b) ty
  | Vec : 'a ty -> 'a Vec.t ty
type dyn = Dyn : 'a ty * 'a -> dyn
val eq_ty : 'a ty -> 'b ty -> ('a, 'b) eq option = <fun>
val undyn : 'a ty -> dyn -> 'a option = <fun>
val v : int Vec.t Vec.t = <abstr>
val int_vec_vec : int Vec.t Vec.t ty = Vec (Vec Int)
val d : dyn = Dyn (Vec (Vec Int), <poly>)
Line 47, characters 4-11:
47 | let Some v' = undyn int_vec_vec d
         ^^^^^^^
Warning 8: this pattern-matching is not exhaustive.
Here is an example of a case that is not matched:
None
val v' : int Vec.t Vec.t = <abstr>
|}]


(* Not directly related: injectivity and constraints *)
type 'a t = 'b constraint 'a = <b : 'b>
class type ['a] ct = object method m : 'b constraint 'a = < b : 'b > end
[%%expect{|
type 'a t = 'b constraint 'a = < b : 'b >
class type ['a] ct = object constraint 'a = < b : 'b > method m : 'b end
|}]

type _ u = M : 'a -> 'a t u (* OK *)
[%%expect{|
type _ u = M : < b : 'a > -> < b : 'a > t u
|}]
type _ v = M : 'a -> 'a ct v (* OK *)
[%%expect{|
type _ v = M : < b : 'a > -> < b : 'a > ct v
|}]

type 'a t = 'b constraint 'a = <b : 'b; c : 'c>
type _ u = M : 'a -> 'a t u (* KO *)
[%%expect{|
type 'a t = 'b constraint 'a = < b : 'b; c : 'c >
Line 2, characters 0-27:
2 | type _ u = M : 'a -> 'a t u (* KO *)
    ^^^^^^^^^^^^^^^^^^^^^^^^^^^
Error: In this definition, a type variable cannot be deduced
       from the type parameters.
|}]

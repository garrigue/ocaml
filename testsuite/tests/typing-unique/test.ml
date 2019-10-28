(* TEST
   * expect
*)

(* Definitions *)

type t [@@unique "foo"]
type a = A [@@unique "alf"]
type b = {b: int} [@@unique "bar"]
type ext = .. [@@unique]
[%%expect{|
type t [@@unique "foo"]
type a = A [@@unique "alf"]
type b = { b : int; } [@@unique "bar"]
type ext = .. [@@unique "ext"]
|}]

(* Re-exporting rules *)

module M = struct type a = A [@@unique "M.a"] end;;
[%%expect{|
module M : sig type a = A [@@unique "M.a"] end
|}]

(* we can abstract *)
module M1 : sig type a end = M;;
[%%expect{|
module M1 : sig type a end
|}]

(* we can abstract keeping identity *)
module M2 : sig type a [@@unique "M.a"] end = M;;
[%%expect{|
module M2 : sig type a [@@unique "M.a"] end
|}]

(* we cannot forget identity of concrete type *)
module M3 : sig type a = A end = M;;
[%%expect{|
Line 1, characters 33-34:
1 | module M3 : sig type a = A end = M;;
                                     ^
Error: Signature mismatch:
       Modules do not match:
         sig type a = M.a = A [@@unique "M.a"] end
       is not included in
         sig type a = A end
       Type declarations do not match:
         type a = M.a = A [@@unique "M.a"]
       is not included in
         type a = A
       Unique identifier "M.a" was removed without abstracting the datatype
|}]

(* we can export an abbreviation of a unique type as unique *)
module M4 : sig type float_array [@@unique "array"] end =
  struct type float_array = float array end
module M5 : sig type 'a my_array [@@unique "array"] end =
  struct type 'a my_array = 'a array end
[%%expect{|
module M4 : sig type float_array [@@unique "array"] end
module M5 : sig type 'a my_array [@@unique "array"] end
|}]

(* beware of injectivity *)
module M6 : sig type 'a my_array [@@unique "array"] end =
  struct type 'a my_array = float array end
[%%expect{|
Line 2, characters 2-43:
2 |   struct type 'a my_array = float array end
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Error: Signature mismatch:
       Modules do not match:
         sig type 'a my_array = float array end
       is not included in
         sig type 'a my_array [@@unique "array"] end
       Type declarations do not match:
         type 'a my_array = float array
       is not included in
         type 'a my_array [@@unique "array"]
       Unique identifier "array" was not present in original declaration
|}]

(* Compatibility *)

module Lists = struct
type 'a list1 = [] | (::) of 'a * 'a list1
type 'a list2 = [] | (::) of 'a * 'a list2 [@@unique "list2"]

type _ typ =
  | Int : int typ
  | Bool : bool typ
  | List : 'a typ -> 'a List.t typ
  | Array : 'a typ -> 'a array typ
  | Queue : 'a typ -> 'a Queue.t typ
  | Stack : 'a typ -> 'a Stack.t typ
  | List1 : 'a typ -> 'a list1 typ
  | List2 : 'a typ -> 'a list2 typ ;;

let rec eq : type a. a typ -> a typ -> bool = fun t1 t2 ->
  match t1, t2 with
  | Int, Int -> true
  | Bool, Bool -> true
  | List a1, List a2 -> eq a1 a2
  | List1 a1, List1 a2 -> eq a1 a2
  | List2 a1, List2 a2 -> eq a1 a2
  | Array a1, Array a2 -> eq a1 a2
  | Queue a1, Queue a2 -> eq a1 a2
  | Stack a1, Stack a2 -> eq a1 a2;;

(* list2 is incompatible with both list and list1 *)
let rec eq : type a. a typ -> a typ -> bool = fun t1 t2 ->
  match t1, t2 with
  | Int, Int -> true
  | Bool, Bool -> true
  | List a1, List a2 -> eq a1 a2
  | List a1, List1 a2 -> false
  | List1 a1, List a2 -> false
  | List1 a1, List1 a2 -> eq a1 a2
  | List2 a1, List2 a2 -> eq a1 a2
  | Array a1, Array a2 -> eq a1 a2
  | Queue a1, Queue a2 -> eq a1 a2
  | Stack a1, Stack a2 -> eq a1 a2
end;;
[%%expect{|
Lines 16-24, characters 2-34:
16 | ..match t1, t2 with
17 |   | Int, Int -> true
18 |   | Bool, Bool -> true
19 |   | List a1, List a2 -> eq a1 a2
20 |   | List1 a1, List1 a2 -> eq a1 a2
21 |   | List2 a1, List2 a2 -> eq a1 a2
22 |   | Array a1, Array a2 -> eq a1 a2
23 |   | Queue a1, Queue a2 -> eq a1 a2
24 |   | Stack a1, Stack a2 -> eq a1 a2..
Warning 8 [partial-match]: this pattern-matching is not exhaustive.
Here is an example of a case that is not matched:
(List _, List1 _)
module Lists :
  sig
    type 'a list1 = [] | (::) of 'a * 'a list1
    type 'a list2 = [] | (::) of 'a * 'a list2 [@@unique "list2"]
    type _ typ =
        Int : int typ
      | Bool : bool typ
      | List : 'a typ -> 'a List.t typ
      | Array : 'a typ -> 'a array typ
      | Queue : 'a typ -> 'a Queue.t typ
      | Stack : 'a typ -> 'a Stack.t typ
      | List1 : 'a typ -> 'a list1 typ
      | List2 : 'a typ -> 'a list2 typ
    val eq : 'a typ -> 'a typ -> bool
  end
|}]

(* Typical example *)

module M : sig type b [@@unique "M.b"] end = struct
  module M1 = struct type a = A [@@unique "M.b"] end
  type b = M1.a
end;;
[%%expect{|
module M : sig type b [@@unique "M.b"] end
|}]

module M : sig type b = A [@@unique "M.b"] end = struct
  module M1 = struct type a = A [@@unique "M.b"] end
  type b = M1.a = A [@@unique "M.b"]
end;;
[%%expect{|
module M : sig type b = A [@@unique "M.b"] end
|}]

module M2 : sig type c [@@unique "M.b"] end = struct
  type c = C [@@unique "M.b"]
end;;
[%%expect{|
module M2 : sig type c [@@unique "M.b"] end
|}]

(* Private types *)

module M : sig type a [@@unique "M.a"] end = struct
  type t = T of int [@@unique "M.a"]
  type a = private t
end
[%%expect{|
module M : sig type a [@@unique "M.a"] end
|}]


(* Injectivy for non-unifiable types *)

type (_,_) eq = Eq : ('a,'a) eq
type 'a t [@@unique "M.t"]
type 'a u [@@unique "M.t"]
type v [@@unique "M.t"];;
[%%expect{|
type (_, _) eq = Eq : ('a, 'a) eq
type 'a t [@@unique "M.t"]
type 'a u [@@unique "M.t"]
type v [@@unique "M.t"]
|}]

let f : (int t, bool u) eq option -> int = function None -> 1;;
[%%expect{|
val f : (int t, bool u) eq option -> int = <fun>
|}]

let g : (int t, v) eq option -> int = function None -> 1;;
[%%expect{|
Line 1, characters 38-56:
1 | let g : (int t, v) eq option -> int = function None -> 1;;
                                          ^^^^^^^^^^^^^^^^^^
Warning 8 [partial-match]: this pattern-matching is not exhaustive.
Here is an example of a case that is not matched:
Some Eq
val g : (int t, v) eq option -> int = <fun>
|}]

module M : sig type x [@@unique "M.t"] end = struct type x = int t end;;
[%%expect{|
module M : sig type x [@@unique "M.t"] end
|}]

module M : sig
  type 'a t [@@unique "M.t"]
  type 'a u [@@unique "M.t"]
end = struct
  type ('a,'b) s [@@unique "M.t"]
  type 'a t = ('a,bool) s
  type 'a u = (int, 'a) s
end;;
[%%expect{|
Lines 4-8, characters 6-3:
4 | ......struct
5 |   type ('a,'b) s [@@unique "M.t"]
6 |   type 'a t = ('a,bool) s
7 |   type 'a u = (int, 'a) s
8 | end..
Error: Signature mismatch:
       Modules do not match:
         sig
           type ('a, 'b) s [@@unique "M.t"]
           type 'a t = ('a, bool) s
           type 'a u = (int, 'a) s
         end
       is not included in
         sig type 'a t [@@unique "M.t"] type 'a u [@@unique "M.t"] end
       Type declarations do not match:
         type 'a t = ('a, bool) s
       is not included in
         type 'a t [@@unique "M.t"]
       Unique identifier "M.t" was not present in original declaration
|}]

(* Application to functors *)

module type S = sig
  type elt
  type t
  val create : elt list -> t
end
module Set(X : sig type t end) : sig
  type 'a t1 constraint 'a = X.t [@@unique "Make.t"]
  include S with type elt = X.t and type t = X.t t1
end = struct
  type elt = X.t
  type 'a t1 = {elems: 'a list} constraint 'a = elt [@@unique "Make.t"]
  type t = elt t1
  let create l = {elems=l}
end;;
[%%expect{|
module type S = sig type elt type t val create : elt list -> t end
module Set :
  functor (X : sig type t end) ->
    sig
      type 'a t1 constraint 'a = X.t [@@unique "Make.t"]
      type elt = X.t
      type t = X.t t1
      val create : elt list -> t
    end
|}]

module Int = struct type t = int end
module Bool = struct type t = bool end;;
[%%expect{|
module Int : sig type t = int end
module Bool : sig type t = bool end
|}]

let f : (Set(Int).t,Set(Bool).t) eq option -> int = fun None -> 1;;
[%%expect{|
val f : (Set(Int).t, Set(Bool).t) eq option -> int = <fun>
|}]


(* More examples *)

(* Failure *)
module M : sig type +'a t end =
  struct type 'a t = Nil | Cons of 'a * 'a t end
type _ ty = M : 'a ty -> 'a M.t ty;;
[%%expect{|
module M : sig type +'a t end
Line 3, characters 0-34:
3 | type _ ty = M : 'a ty -> 'a M.t ty;;
    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Error: In this definition, a type variable cannot be deduced
       from the type parameters.
|}]

(* Workaround *)
module M : sig type +'a t0  and 'a t = M_t of 'a t0 end =
  struct type 'a t0 = Nil | Cons of 'a * 'a t0 and 'a t = M_t of 'a t0 end
type _ ty = M : 'a ty -> 'a M.t ty;;
[%%expect{|
module M : sig type +'a t0 and 'a t = M_t of 'a t0 end
type _ ty = M : 'a ty -> 'a M.t ty
|}]

(* Named type *)
module M : sig type +'a t [@@unique "M.t"] end =
  struct type 'a t = Nil | Cons of 'a * 'a t [@@unique "M.t"] end
type _ ty = M : 'a ty -> 'a M.t ty;;
[%%expect{|
module M : sig type +'a t [@@unique "M.t"] end
type _ ty = M : 'a ty -> 'a M.t ty
|}]

(* Expression *)
module M : sig type +'a t [@@unique "M.t"] val create : 'a list -> 'a t end =
struct
  type 'a t = Nil | Cons of 'a * 'a t [@@unique "M.t"]
  let rec create = function [] -> Nil | a::l -> Cons (a, create l)
end
type _ exp = M : 'a list -> 'a M.t exp | Int : int -> int exp
let eval_int : int exp -> int = function Int x -> x;;
[%%expect{|
module M : sig type +'a t [@@unique "M.t"] val create : 'a list -> 'a t end
type _ exp = M : 'a list -> 'a M.t exp | Int : int -> int exp
val eval_int : int exp -> int = <fun>
|}]
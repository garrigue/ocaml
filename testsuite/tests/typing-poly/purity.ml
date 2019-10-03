let some x = Some x;;
let a = some (fun x -> x);;

let r = ref;;
let c = r (fun x -> x);;
let c' = {contents=fun x -> x};;

type 'a cell = {get: unit -> 'a; set: 'a -> unit};;
let mkcell x = let r = ref x in {get=(fun() -> !r);set=(:=) r};;

let f (mkc : unit -> _ cell) =
  let id = ignore (mkc ()); fun x -> x in
  id true, id 1;;

let p = f mkcell;;

(* Should fail *)
let p' =
  let id = ignore (mkcell ()); fun x -> x in
  id true, id 1;;

(* Let-reduction fails *)
let f2 (mkc : unit -> _ cell) =
  let (_,id) = (mkc (), fun x -> x) in
  id true, id 1;;

let p2 = f2 mkcell;;

(* Fails: cannot generalize because mkcell is impure  *)
let p2 =
  let (_,id) = (mkcell (), fun x -> x) in
  id true, id 1;;


(* Subtle case *)

type mkref = {mkref: 'a. 'a -> 'a ref}

let f x = let r = x.mkref [] in fun y -> r := [y]; List.hd !r;;


(* Modules *)

module type T = sig
  val some : 'a -> 'a option [@@pure]
end;;

module M : T = struct let some x = Some x end;;

(* fails *)
module M' : T = struct let some x = let r = ref x in Some !r end;;

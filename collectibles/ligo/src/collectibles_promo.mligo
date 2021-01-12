#include "../fa2/fa2_interface.mligo"

(**
A promoter who owns some collectible NFT tokens can create an instance of promotion.
The promotion definition contains FA2 address of the NFT collection, FA2 fungible
"money" token used to pay for collectibles and a price per collectible token.

The promotion starts when the promoter transfers one or more collectible NFT tokens
to the promotion contract.

Once promotion is in progress, other participants can transfer money tokens to the
promotion contract. The promotion allocates promoted tokens to the participants and
keeps remaining money balances.

The promotion stops if all promotion tokens are allocated or if the promoter explicitly
stopped it.

At any time when the promotion is in progress or stopped, any participant may request
refund (transfer back) the remaining unspent money balance and/or to disburse
already allocated collectible tokens.

If the promotion has been stopped and not all collectible tokens are allocated, the
promoter should request to disburse remaining collectibles.

 *)

type global_token_id = {
  fa2 : address;
  id : token_id;
}

type promotion_def = {
  promoter : address;
  (* FA2 token used to pay for collectibles *)
  money_token : global_token_id;
  (* FA2 contract that holds promoted collectibles *)
  collectible_fa2 : address;
  (* Price in money tokens per one promoted collectible token *)
  price : nat;
}

(* owner -> money token amount *)
type money_deposits = (address, nat) map

(* owner -> collectible token ids*)
type allocated_collectibles = (address, token_id list) map

type promotion_in_progress = {
  def : promotion_def;
  (* collectibles to promote *)
  collectibles : token_id list;
  (* transferred money reminders *)
  money_deposits : money_deposits;
  allocated_collectibles : allocated_collectibles;
}

type finished_promotion = {
  def : promotion_def;
  (* transferred money reminders *)
  money_deposits : money_deposits;
  allocated_collectibles : allocated_collectibles;
}

type promotion_state =
  | Initial of promotion_def
  | In_progress of promotion_in_progress
  | Finished of finished_promotion


type promotion_entrypoints =
  | Tokens_received of transfer_descriptor_param
  | Refund_money 
  | Disburse_collectibles
  | Stop_promotion

type return_type = (operation list) * promotion_state

let retrieve_collectibles (txs : transfer_destination_descriptor list)
    : token_id list =
  List.fold
    (fun (acc, tx : (token_id list) * transfer_destination_descriptor)->
      if tx.amount = 0n
      then acc
      else if tx.amount > 1n
      then (failwith "NON_NFT_RECEIVED" : token_id list)
      else
        match tx.to_ with
        | None -> acc
        | Some a ->
          if a = Tezos.self_address
          then tx.token_id :: acc
          else acc
        
    ) txs ([] : token_id list)

let validate_no_tokens_received (txs, this_address
    : (transfer_destination_descriptor list) * address) : unit =
  List.iter 
    (fun (tx : transfer_destination_descriptor) ->
      if tx.amount = 0n
      then unit
      else
        match tx.to_ with
        | None -> unit
        | Some a -> 
          if a = this_address
          then failwith ("CANNOT_ACCEPT_TOKENS")
          else unit
    ) txs

let accept_collectibles (tx_param, pdef
    : transfer_descriptor_param * promotion_def) : promotion_state =
  if Tezos.sender <> pdef.collectible_fa2
  then (failwith ("PROMO_COLLECTIBLES_EXPECTED") : promotion_state)
  else
    let collectibles = List.fold 
      (fun (acc, td : (token_id list) * transfer_descriptor) ->
        let is_from_promoter = match td.from_ with
        | None -> false
        | Some a -> if a = pdef.promoter then true else false
        in
        if is_from_promoter
        then 
          let cc = retrieve_collectibles (td.txs) in
          (* concat accumulator and received cc collectibles *)
          List.fold (fun (a, c : (token_id list) * token_id) ->
            c :: a
          ) cc acc
        else
          let u = validate_no_tokens_received (td.txs, Tezos.self_address) in
          acc
      ) tx_param.batch ([] : token_id list) in
    In_progress {
      def = pdef;
      collectibles = collectibles;
      money_deposits = (Map.empty : money_deposits);
      allocated_collectibles = (Map.empty : allocated_collectibles);
    }

type buy_in_progress = {
  buyer: address;
  buyer_money: nat;
  promoter_money: nat;
  promo : promotion_in_progress;
}

let rec allocate_collectibles (p : buy_in_progress) : buy_in_progress =
  match p.promo.collectibles with
  | [] -> p (* ran out of collectibles *)
  | cid :: tail -> 
    (match is_nat(p.buyer_money - p.promo.def.price) with
    | None -> p (* not enough money to buy next collectible *)
    | Some money_reminder ->
      let new_buyer_allocated = match Map.find_opt p.buyer p.promo.allocated_collectibles with
      | None -> [cid]
      | Some buyer_allocated -> cid :: buyer_allocated
      in
      let new_allocated_collectibles =
        Map.update p.buyer (Some new_buyer_allocated) p.promo.allocated_collectibles in
      let new_promo = { p.promo with
        allocated_collectibles = new_allocated_collectibles;
        collectibles = tail;
      } in
      allocate_collectibles {
        buyer = p.buyer;
        buyer_money = money_reminder;
        promoter_money = p.promoter_money + p.promo.def.price;
        promo = new_promo;
      }
    )

let buy_collectibles (buyer, money_amount, promo : address * nat * promotion_in_progress)
    : promotion_in_progress =
  let buyer_money = match Map.find_opt buyer promo.money_deposits with
  | None -> money_amount
  | Some m -> m + money_amount
  in
  let promoter_money = match Map.find_opt promo.def.promoter promo.money_deposits with
  | None -> 0n
  | Some m -> m
  in
  let r = allocate_collectibles {
    buyer = buyer;
    buyer_money = buyer_money;
    promoter_money = promoter_money;
    promo = promo;
  } in
  let new_deposits1 = Map.update r.buyer (Some r.buyer_money) r.promo.money_deposits in
  let new_deposits2 = Map.update r.promo.def.promoter (Some r.promoter_money) new_deposits1 in
  { r.promo with money_deposits = new_deposits2; }

let retrieve_money (txs, buyer, promo
    : (transfer_destination_descriptor list) * address * promotion_in_progress)
    : promotion_in_progress =
  List.fold
    (fun (p, tx : promotion_in_progress * transfer_destination_descriptor) ->
      match tx.to_ with
      | None -> p
      | Some a ->
        if a <> Tezos.self_address
        then p (* skip transfer to other account *)
        else if tx.token_id <> p.def.money_token.id
        then (failwith "PROMO_MONEY_TOKENS_EXPECTED" : promotion_in_progress)
        else buy_collectibles (buyer, tx.amount, p)
    ) txs promo

let accept_money (tx_param, promo
    : transfer_descriptor_param * promotion_in_progress) : promotion_state =
  if Tezos.sender <> promo.def.money_token.fa2
  then (failwith "PROMO_MONEY_TOKENS_EXPECTED" : promotion_state)
  else
    let new_promo = List.fold
      (fun (p, td : promotion_in_progress * transfer_descriptor) ->
        match td.from_ with
        | None ->
          let u = validate_no_tokens_received (td.txs, Tezos.self_address) in
          p
        | Some from_ -> retrieve_money (td.txs, from_, p)
      ) tx_param.batch promo in
    if List.size new_promo.collectibles = 0n
    then Finished {
      def = new_promo.def;
      allocated_collectibles = new_promo.allocated_collectibles;
      money_deposits = new_promo.money_deposits
    }
    else In_progress new_promo
    
let accept_tokens (tx_param, state
    : transfer_descriptor_param * promotion_state) : promotion_state =
  match state with
  | Initial pdef -> accept_collectibles (tx_param, pdef)
  | In_progress promo -> accept_money (tx_param, promo)
  | Finished p -> (failwith "PROMO_FINISHED" : promotion_state)

let disburse_collectibles (allocated_collectibles, collectible_fa2, owner, this
    : allocated_collectibles * address * address * address)
    : (operation list ) * allocated_collectibles =
  match Map.find_opt owner allocated_collectibles with
  | None -> ([] : operation list), allocated_collectibles
  | Some cc -> 
    let tx_destinations : transfer_destination list = List.map
      (fun (cid : token_id) -> {
        to_ = owner;
        token_id = cid;
        amount = 1n;
      }) cc in
    let tx : transfer = {
      from_ = this;
      txs = tx_destinations;
    } in
    let fa2_entry : ((transfer list) contract) option = 
      Tezos.get_entrypoint_opt "%transfer"  collectible_fa2 in
    let transfer_op = match fa2_entry with
    | None -> (failwith "CANNOT_INVOKE_COLLECTIBLE_FA2" : operation)
    | Some c -> Tezos.transaction [tx] 0mutez c
    in
    [transfer_op], Map.remove owner allocated_collectibles

let disburse_collectibles (state : promotion_state) : return_type =
  match state with
  | Initial pdef -> (failwith "PROMO_NOT_STARTED" : return_type)
  | In_progress promo ->
    let ops, new_collectibles =
      disburse_collectibles (promo.allocated_collectibles, promo.def.collectible_fa2, Tezos.sender, Tezos.self_address) in
    ops, In_progress { promo with allocated_collectibles = new_collectibles; }

  | Finished promo ->
    let ops, new_collectibles =
      disburse_collectibles (promo.allocated_collectibles, promo.def.collectible_fa2, Tezos.sender, Tezos.self_address) in
    ops, Finished { promo with allocated_collectibles = new_collectibles; }

let refund_money (money_deposits, money_token, owner, this
    : money_deposits * global_token_id * address * address)
    : (operation list ) * money_deposits =
  match Map.find_opt owner money_deposits with
  | None -> ([] : operation list), money_deposits
  | Some m ->
    let tx : transfer = {
      from_ = this;
      txs = [{to_ = owner; token_id = money_token.id; amount = m; }];
    } in
    let fa2_entry : ((transfer list) contract) option = 
      Tezos.get_entrypoint_opt "%transfer"  money_token.fa2 in
    let transfer_op = match fa2_entry with
    | None -> (failwith "CANNOT_INVOKE_MONEY_FA2" : operation)
    | Some c -> Tezos.transaction [tx] 0mutez c
    in
    [transfer_op], Map.remove owner money_deposits

let refund_money (state : promotion_state) : return_type =
  match state with
  | Initial pdef -> (failwith "PROMO_NOT_STARTED" : return_type)
  | In_progress promo ->
    let ops, new_deposits =
      refund_money (promo.money_deposits, promo.def.money_token, Tezos.sender, Tezos.self_address) in
    ops, In_progress { promo with money_deposits = new_deposits; }
  | Finished promo ->
    let ops, new_deposits =
      refund_money (promo.money_deposits, promo.def.money_token, Tezos.sender, Tezos.self_address) in
    ops, Finished { promo with money_deposits = new_deposits; }

let guard_promoter(promoter, asender : address * address) : unit =
  if promoter = asender
  then unit
  else failwith "NOT_PROMOTER"

let stop_promotion (state : promotion_state) : promotion_state =
  match state with
  | Initial pdef ->
    let u = guard_promoter (pdef.promoter, Tezos.sender) in 
    Finished {
      def = pdef;
      money_deposits = (Map.empty : money_deposits);
      allocated_collectibles = (Map.empty : allocated_collectibles);
    }

  | In_progress promo -> 
    let u = guard_promoter (promo.def.promoter, Tezos.sender) in
    (* return all unallocated collectibles to promoter *)
    let promoter_collectibles =
      match Map.find_opt promo.def.promoter promo.allocated_collectibles with
      | None -> promo.collectibles
      | Some cc ->
        List.fold 
          (fun (acc, c : token_id list * token_id) -> c :: acc )
          promo.collectibles cc
    in
    let allocated_collectibles =
      Map.update promo.def.promoter (Some promoter_collectibles) promo.allocated_collectibles in
    Finished {
      def = promo.def;
      money_deposits = promo.money_deposits;
      allocated_collectibles = allocated_collectibles
    }

  | Finished p -> (failwith "PROMO_FINISHED" : promotion_state)

let main (param, state : promotion_entrypoints * promotion_state) : return_type =
  match param with
  (**
    Accepts either collectible nfts during initial state to start the promotion
    or money tokens when promotion is in progress.
 *)
  | Tokens_received tx_param ->
    let new_state = accept_tokens (tx_param, state) in
    ([] : operation list), new_state

  (*
    Anyone who sent money tokens to a promotion can get a refund if money has
    not being exchanged for nft collectibles.
  *)
  | Refund_money -> refund_money state

  (*
    Anyone who has collectibles allocated by the promotion can request to get
    them transferred to him. If promo was stopped, the promoter can clain remaining
    collectibles.
  *)
  | Disburse_collectibles -> disburse_collectibles state

  (*
    Only the promoter can stop the promotion. All remaining collectibles are
    allocated to the promoter. Promoter and other participants can disburse their
    allocated collectibles and refund unspent money.
  *)
  | Stop_promotion ->
    let new_state = stop_promotion state in
    ([] : operation list), new_state


let example_store : promotion_state = Initial {
    promoter  = ("tz1YPSCGWXwBdTncK2aCctSZAXWvGsGwVJqU" : address);
  money_token = {
    fa2 = ("KT1Ps9gYCnoRbncAb3sw1X4R17MCeGx3Zz1h" : address);
    id = 0n;
  };
  collectible_fa2 = ("KT193LPqieuBfx1hqzXGZhuX2upkkKgfNY9w" : address);
  price = 5n;
}
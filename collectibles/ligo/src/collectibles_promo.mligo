#include "../fa2/fa2_interface.mligo"
#include "../fa2/lib/fa2_convertors.mligo"

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

type promotion_in_progress = {
  def : promotion_def;
  (* collectibles to promote *)
  collectibles : token_id list;
  (* buyer -> money token amount *)
  money_deposits : (address, nat) map;
  (* collectible token id ->  buyer*)
  allocated_collectibles : (token_id, address) map;
}

type finished_promotion = {
  def : promotion_def;
  (* owner -> money token amount *)
  money_deposits : (address, nat) map;
  (* collectible token id -> owner *)
  allocated_collectibles : (token_id, address) map;
}

type promotion_state =
  | Initial of promotion_def
  | In_progress of promotion_in_progress
  | Finished of finished_promotion


type promotion_entrypoints =
  | Tokens_received of transfer_descriptor_param_michelson
  | Refund_money 
  | Disburse_collectibles
  | Cancel_promotion

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

let validate_no_tokens_received (txs : transfer_destination_descriptor list) : unit =
  List.iter 
    (fun (tx : transfer_destination_descriptor) ->
      if tx.amount = 0n
      then unit
      else
        match tx.to_ with
        | None -> unit
        | Some a -> 
          if a = Tezos.self_address
          then failwith ("CANNOT_ACCEPT_TOKENS")
          else unit
    ) txs

let accept_collectibles (tx_param_michelson, pdef
    : transfer_descriptor_param_michelson * promotion_def) : promotion_state =
  if Tezos.sender <> pdef.collectible_fa2
  then (failwith ("PROMO_COLLECTIBLES_EXPECTED") : promotion_state)
  else
    let tx_param = transfer_descriptor_param_from_michelson tx_param_michelson in
    let collectibles = List.fold 
      (fun (acc, td : (token_id list) * transfer_descriptor) ->
        let is_from_promoter = match td.from_ with
        | None -> false
        | Some a -> if a = pdef.promoter then true else false
        in
        if is_from_promoter
        then 
          let cc = retrieve_collectibles (td.txs) in
          List.fold (fun (a, c : (token_id list) * token_id) ->
            c :: a
          ) cc acc
        else
          let u = validate_no_tokens_received td.txs in
          acc
      ) tx_param.batch ([] : token_id list) in
    In_progress {
      def = pdef;
      collectibles = collectibles;
      money_deposits = (Map.empty : (address, nat) map);
      allocated_collectibles = (Map.empty : (token_id, address) map);
    }

let accept_money (tx_param_michelson, promo
    : transfer_descriptor_param_michelson * promotion_in_progress) : promotion_state =
  let tx_param = transfer_descriptor_param_from_michelson tx_param_michelson in
  In_progress promo

let accept_tokens (tx_param_michelson, state
    : transfer_descriptor_param_michelson * promotion_state) : promotion_state =
  match state with
  | Initial pdef -> accept_collectibles (tx_param_michelson, pdef)
  | In_progress promo -> accept_money (tx_param_michelson, promo)
  | Finished p -> (failwith "PROMO_FINISHED" : promotion_state)

let cancel_promotion (state : promotion_state) : promotion_state =
  match state with
  | Initial pdef -> 
    Finished {
      def = pdef;
      money_deposits = (Map.empty : (address, nat) map);
      allocated_collectibles = (Map.empty : (token_id, address) map);
    }

  | In_progress promo -> 
    (* return all unallocated collectibles to promoter *)
    let allocated_collectibles = List.fold
      (fun (acc, cid : ((token_id, address) map) * token_id) ->
        Map.add cid promo.def.promoter acc
      ) promo.collectibles promo.allocated_collectibles in
    Finished {
      def = promo.def;
      money_deposits = promo.money_deposits;
      allocated_collectibles = allocated_collectibles
    }

  | Finished p -> (failwith "PROMO_FINISHED" : promotion_state)

let main (param, state : promotion_entrypoints * promotion_state)
    : (operation list) * promotion_state =
  match param with
  | Tokens_received tx_param_michelson ->
    let new_state = accept_tokens (tx_param_michelson, state) in
    ([] : operation list), new_state

  | Refund_money -> 
    (* refund_money Tezos.sender *)
    ([] : operation list), state
  | Disburse_collectibles -> 
    (* disburse_collectibles Tezos.sender *)
    ([] : operation list), state
  | Cancel_promotion ->
    let new_state = cancel_promotion state in
    ([] : operation list), new_state
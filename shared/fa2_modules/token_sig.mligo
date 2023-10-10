#if !TOKEN_SIG
#define TOKEN_SIG

#include "../fa2/fa2_interface.mligo"

module type TokenSig = sig

  type ledger

  type storage

  val fa2_main : fa2_entry_points * storage -> (operation  list) * storage

end

#endif
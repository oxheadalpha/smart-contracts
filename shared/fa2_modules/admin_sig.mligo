#if !ADMIN_SIG
#define ADMIN_SIG

module type AdminSig = sig

  type storage

  type entrypoints

  val fail_if_not_admin : storage -> unit

  val fail_if_paused : storage -> unit

  val main : entrypoints * storage -> (operation list) * storage

end

#endif

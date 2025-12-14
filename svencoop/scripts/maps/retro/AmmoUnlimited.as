// Mapscript by Paranoid_AF.
void MapInit(){
  g_Hooks.RegisterHook(Hooks::Player::PlayerSpawn, @PlayerSpawn);
}

HookReturnCode PlayerSpawn(CBasePlayer@ pPlayer){
  for(int i = 0; i < 20; i++){
    pPlayer.SetMaxAmmo(i, 100000);
  }
  return HOOK_HANDLED;
}
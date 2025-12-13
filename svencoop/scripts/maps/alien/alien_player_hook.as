//AlienShooter Player hook//
// AmmoUnlimited by Paranoid_AF.
//email:Dr.Abc@foxmail.con//
//请勿擅自修改

#include "point_checkpoint"

void MapInit()
{
	Precache();
	g_Hooks.RegisterHook(Hooks::Player::ClientPutInServer, @PlayerJoin);
	g_Hooks.RegisterHook(Hooks::Player::ClientDisconnect, @PlayerQuit);
	g_Hooks.RegisterHook(Hooks::Player::PlayerSpawn, @AmmoUnlimited);
	
	g_Hooks.RemoveHook( Hooks::Player::PlayerKilled, @AmmoUnlimited );
	g_Hooks.RemoveHook( Hooks::Player::PlayerSpawn, @PlayerJoin );
	RegisterALIEN();
	
	RegisterPointCheckPointEntity();
	g_SurvivalMode.EnableMapSupport();
	
	g_ClassicMode.SetItemMappings( @g_ItemMappings );
	g_ClassicMode.ForceItemRemap( true );
}

HookReturnCode AmmoUnlimited(CBasePlayer@ pPlayer){
  for(int i = 0; i < 20; i++){
    pPlayer.SetMaxAmmo(i, 2000);
  }
  return HOOK_HANDLED;
}

HookReturnCode PlayerQuit(CBasePlayer@ pPlayer)
{
	NetworkMessage m(MSG_ONE, NetworkMessages::SVC_STUFFTEXT, pPlayer.edict());
		m.WriteString("firstperson");
	m.End();
	return HOOK_HANDLED;
}

HookReturnCode PlayerJoin( CBasePlayer@ pPlayer ) 
{
	NetworkMessage m(MSG_ONE, NetworkMessages::SVC_STUFFTEXT, pPlayer.edict());
		m.WriteString("thirdperson;cam_idealyaw -15;cam_idealpitch 0;cam_idealdist 55;cam_snapto 1;cam_followaim 1");
	m.End();
    return HOOK_HANDLED;
}

void ReFirstperson (CBasePlayer@ pPlayer)
{
	NetworkMessage m(MSG_ONE, NetworkMessages::SVC_STUFFTEXT, pPlayer.edict());
		m.WriteString("firstperson");
	m.End();
}

void ActivateSurvival( CBaseEntity@ pActivator, CBaseEntity@ pCaller,
	USE_TYPE useType, float flValue )
{
	g_SurvivalMode.Activate();
}

void DisableSurvival( CBaseEntity@ pActivator, CBaseEntity@ pCaller, 
	USE_TYPE useType, float flValue )
{
    g_SurvivalMode.Disable();
}

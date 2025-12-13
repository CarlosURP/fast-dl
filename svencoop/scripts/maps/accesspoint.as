// Anti-Rush by Outerbeast
#include "anti_rush"
// CheckPoint spawner by Outerbeast
#include "beast/checkpoint_spawner"

const bool blAntiRushEnable = false; // You can change this to have AntiRush mode enabled or disabled
const float flSurvivalVoteAllow = g_EngineFuncs.CVarGetFloat( "mp_survival_voteallow" );

void MapInit() 
{
	ANTI_RUSH::EntityRegister( blAntiRushEnable );
	g_EngineFuncs.CVarSetFloat( "mp_hevsuit_voice", 1 );
}

void TurnOnSurvival(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
{
	g_EngineFuncs.CVarSetFloat( "mp_survival_voteallow", flSurvivalVoteAllow ); // Revert to the original cvar setting as per server

	if( g_SurvivalMode.IsEnabled() && g_SurvivalMode.MapSupportEnabled() && !g_SurvivalMode.IsActive() )
		g_SurvivalMode.Activate( true );
}
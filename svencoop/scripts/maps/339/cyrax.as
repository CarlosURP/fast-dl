// scripts/maps/339/cyrax.as

#include "monsters"
#include "weapons"
#include "weapons/projectile"
#include "monster_qscrag"
#include "monster_nihilrax"
#include "monster_superrax"
#include "monster_human_cyrax"
#include "monster_gasfloater"
#include "monster_zombie_cyrax"
#include "monster_alextafini"
#include "monster_edgrunt"
#include "monster_zombie_sally"

void PluginInit()
{
    g_Module.ScriptInfo.SetAuthor("Sidewinder");
    g_Module.ScriptInfo.SetContactInfo("https://steamcommunity.com/id/tehsnek/");
}

void MapInit()
{
    // Your existing weapon & projectile registration
    Register339Weapons();           // from weapons.as
    q1_RegisterProjectiles();       // from projectile.as

    // Monsters
    q1_RegisterMonster_SCRAG();
    RegisterMonster_Nihilrax();
    RegisterMonster_SuperRax();
    RegisterMonster_Human_Cyrax();
	RegisterMonster_GasFloater();
	RegisterMonster_ZombieCyrax();
	RegisterMonsterAlexTafini(); 
	RegisterMonsterEdGrunt();
	RegisterMonsterZombieSally();

    // Precache the custom entities so squadmaker / monster_zombie_alex replacements work
    g_Game.PrecacheOther("monster_qscrag");
    g_Game.PrecacheOther("monster_nihilrax");
    g_Game.PrecacheOther("monster_superrax");
    g_Game.PrecacheOther("monster_human_cyrax");
	g_Game.PrecacheOther( "monster_gasfloater" );
	g_Game.PrecacheOther( "monster_zombie_cyrax" );
	g_Game.PrecacheOther("monster_alextafini");
	g_Game.PrecacheOther( "monster_edgrunt" );
	g_Game.PrecacheOther( "monster_zombie_sally" );
}

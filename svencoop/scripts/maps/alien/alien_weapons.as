//AlienShooter Weapons Register//
//email:Dr.Abc@foxmail.con//
//请勿擅自修改

#include "../alien/weapon_alien_pistol"
#include "../alien/weapon_alien_mini"
#include "../alien/weapon_alien_shotgun"
#include "../alien/weapon_alien_nade"
#include "../alien/weapon_alien_rpg"

string GetALIENSHOOTERPISTOLName()
{
	return "weapon_alien_pistol";
}

string GetALIENSHOOTERMININame()
{
	return "weapon_alien_mini";
}

string GetALIENSHOOTERNADEName()
{
	return "weapon_alien_nade";
}

string GetALIENSHOOTERSHOTName()
{
	return "weapon_alien_shotgun";
}

string GetALIENSHOOTERRPGName()
{
	return "weapon_alien_rpg";
}

void RegisterALIEN()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "alien_arnade", "alien_arnade" );
	g_CustomEntityFuncs.RegisterCustomEntity( "alien_rpg", "alien_rpg" );
	g_CustomEntityFuncs.RegisterCustomEntity( GetALIENSHOOTERNADEName(), GetALIENSHOOTERNADEName() );
	g_ItemRegistry.RegisterWeapon( GetALIENSHOOTERNADEName(), "alien","ARgrenades" );
	g_CustomEntityFuncs.RegisterCustomEntity( GetALIENSHOOTERSHOTName(), GetALIENSHOOTERSHOTName() );
	g_ItemRegistry.RegisterWeapon( GetALIENSHOOTERSHOTName(), "alien", "buckshot" );
	g_CustomEntityFuncs.RegisterCustomEntity( GetALIENSHOOTERMININame(), GetALIENSHOOTERMININame() );
	g_ItemRegistry.RegisterWeapon( GetALIENSHOOTERMININame(), "alien",556 );
	g_CustomEntityFuncs.RegisterCustomEntity( GetALIENSHOOTERPISTOLName(), GetALIENSHOOTERPISTOLName() );
	g_ItemRegistry.RegisterWeapon( GetALIENSHOOTERPISTOLName(), "alien" );
	g_CustomEntityFuncs.RegisterCustomEntity( GetALIENSHOOTERRPGName(), GetALIENSHOOTERRPGName() );
	g_ItemRegistry.RegisterWeapon( GetALIENSHOOTERRPGName(), "alien","rockets" );
	g_CustomEntityFuncs.RegisterCustomEntity( "item_alien_hugemed", "item_alien_hugemed");
	g_CustomEntityFuncs.RegisterCustomEntity( "item_alien_hugearm", "item_alien_hugearm");
}
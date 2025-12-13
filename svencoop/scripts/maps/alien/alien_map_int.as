//Map Alien Shooter by Dr.Abc//
//email:Dr.Abc@foxmail.con//
//请勿擅自修改


#include "../alien/alien_weapons"
#include "../alien/alien_map_effect"
#include "../alien/alien_player_hook"
#include "../alien/item_alien"

array<ItemMapping@> g_ItemMappings =
{ 
	ItemMapping( "weapon_9mmhandgun", "weapon_alien_pistol" ), 
	ItemMapping( "weapon_m249", "weapon_alien_mini" ),
	ItemMapping( "weapon_shotgun", "weapon_alien_shotgun" )
};

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Dr.Abc" );
	g_Module.ScriptInfo.SetContactInfo( "Dr.Abc@foxmail.com" );
}
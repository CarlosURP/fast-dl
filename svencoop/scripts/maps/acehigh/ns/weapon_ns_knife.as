#include "base"

/* Natural Selection Knife Script
By Meryilla

Models, Sounds, and Sprites by Unknown Worlds

Additional Credit to the below for providing guidance in creating these scripts:

https://anggaranothing.gitlab.io/as/svencoop/# Angelscript for SC Docs
INS2 Weapon Scripts for SC - by Kerncore
Natural Selection Source Code - by Unknown Worlds
*/

namespace NS_KNIFE
{
	
enum kn_anims 
{
	IDLE1 = 0,
	IDLE2,
	ATTACK1,
	ATTACK2,
	DRAW,
	FLOURISH
};	

//Models
const string MODEL_P = "models/ns/p_kn.mdl";
const string MODEL_V = "models/ns/v_kn.mdl";
const string MODEL_W = "models/ns/w_kn.mdl";

//Sounds
const string SND_FIRE1 = "ns/weapons/kn/kn-1.wav";
const string SND_FIRE2 = "ns/weapons/kn/kn-2.wav";
const string SND_HIT1 = "ns/weapons/kn/kn-hit-1.wav";
const string SND_HIT2 = "ns/weapons/kn/kn-hit-2.wav";
const string SND_HIT_WALL = "ns/weapons/kn/kn-hit-wall.wav";
const string SND_DRAW = "ns/weapons/kn/kn-deploy.wav";

array<string> SOUNDS = {
	SND_FIRE1,
	SND_FIRE2,
	SND_HIT1,
	SND_HIT2,
	SND_HIT_WALL,
	SND_DRAW
};

array<string> SND_KNIFE_ATTACK = {
	"ns/weapons/kn/kn-1.wav",
	"ns/weapons/kn/kn-2.wav"
};
array<string> SND_KNIFE_HIT = {
	"ns/weapons/kn/kn-hit-1.wav",
	"ns/weapons/kn/kn-hit-2.wav"
};

//Anim timings
const float DEPLOY_TIME = 1.2f;

//Item info
const int MAX_AMMO = -1;
const int MAX_CLIP = WEAPON_NOCLIP;
const int SLOT = 0;
const int POSITION = 20;
const int DEFAULT_AMMO = 0;

//Stats
const int DAMAGE = 30;
const int RANGE = 35;
const float ROF = 0.65;
const float	XPUNCH = .75;

class weapon_ns_knife : ScriptBasePlayerWeaponEntity, NSBASE::WeaponBase, NSBASE::MeleeWeaponBase
{
	private CBasePlayer@ m_pPlayer
	{
		get const	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set			{ self.m_hPlayer = EHandle( @value ); }
	}
	private int GetBodygroup()
	{
		return 0;
	}

	void Spawn()
	{
		Precache();
		self.m_iDefaultAmmo = DEFAULT_AMMO;
		g_EntityFuncs.SetModel( self, MODEL_W );		
		self.FallInit();
	}

	void Precache()
	{
		g_Game.PrecacheModel( MODEL_P );
		g_Game.PrecacheModel( MODEL_V );
		g_Game.PrecacheModel( MODEL_W );
		
		for( uint i = 0; i < SOUNDS.length(); i++ )
		{
			g_SoundSystem.PrecacheSound( SOUNDS[i] );
			g_Game.PrecacheGeneric( "sound/" + SOUNDS[i] );
		}
		
		for( uint i = 0; i < SND_KNIFE_ATTACK.length(); i++ )
		{
			g_SoundSystem.PrecacheSound( SND_KNIFE_ATTACK[i] );
			g_Game.PrecacheGeneric( "sound/" + SND_KNIFE_ATTACK[i] );
		}
	
		for( uint i = 0; i < SND_KNIFE_HIT.length(); i++ )
		{
			g_SoundSystem.PrecacheSound( SND_KNIFE_HIT[i] );
			g_Game.PrecacheGeneric( "sound/" + SND_KNIFE_HIT[i] );
		}
		
		CommonPrecache();
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= MAX_AMMO;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= MAX_CLIP;
		info.iSlot 		= SLOT;
		info.iPosition 	= POSITION;
		info.iFlags 	= -1;
		info.iWeight 	= 20;

		return true;
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( !BaseClass.AddToPlayer( pPlayer ) )
			return false;
			
		NetworkMessage message( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			message.WriteLong( g_ItemRegistry.GetIdForName( self.pev.classname ) );
		message.End();

		return true;
	}

	bool Deploy()
	{
		return Deploy( MODEL_V, MODEL_P, DRAW, "crowbar", GetBodygroup(), DEPLOY_TIME );
	}

	void Holster( int skipLocal = 0 )
	{
		BaseClass.Holster( skipLocal );
	}	
	
	int	GetIdleAnimation()
	{
		// Only play the poking-finger animation once in awhile and play the knife flourish once in a blue moon, it's a special treat
		int iAnim = 0;
		int iRandomNum = g_PlayerFuncs.SharedRandomLong( m_pPlayer.random_seed, 0, 200 );

		if( iRandomNum == 0 )
		{
			iAnim = FLOURISH;
		}
		else if( iRandomNum < 16 )
		{
			iAnim = IDLE2;	
		}
		else
		{
			iAnim = IDLE1;
		}
		
		return iAnim;	
	}	
			

	void PrimaryAttack()
	{
		Swing( DAMAGE, SND_KNIFE_ATTACK[Math.RandomLong( 0, SND_KNIFE_ATTACK.length() - 1 )], SND_KNIFE_HIT[Math.RandomLong( 0, SND_KNIFE_ATTACK.length() - 1 )], 
			SND_HIT_WALL, ATTACK1, ATTACK2, GetBodygroup(), RANGE, ROF, ROF, ROF );
		
		m_pPlayer.pev.punchangle.x = Math.RandomFloat( -XPUNCH, XPUNCH);

		self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomLong( m_pPlayer.random_seed, 10, 15 );		
	}	
	
	void WeaponIdle()
	{			
		self.ResetEmptySound();
		m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );
		
		
		if( self.m_flTimeWeaponIdle < g_Engine.time )
		{
			self.SendWeaponAnim( GetIdleAnimation(), 0, GetBodygroup() );		
			self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 5, 7 );
		}
	}	
}
void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "NS_KNIFE::weapon_ns_knife", "weapon_ns_knife" );
	g_ItemRegistry.RegisterWeapon( "weapon_ns_knife", "ns" );	
}
}
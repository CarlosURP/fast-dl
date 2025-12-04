#include "base"

/* Natural Selection Machinegun Script
By Meryilla

Models, Sounds, and Sprites by Unknown Worlds

Additional Credit to the below for providing guidance in creating these scripts:

https://anggaranothing.gitlab.io/as/svencoop/# Angelscript for SC Docs
INS2 Weapon Scripts for SC - by Kerncore
Natural Selection Source Code - by Unknown Worlds
*/

namespace NS_MACHINEGUN
{
enum mg_anims 
{
	IDLE1 = 0,
	IDLE2,
	RELOAD,
	SHOOT,
	SHOOT_EMPTY,
	DRAW
};

//Models
const string MODEL_P = "models/ns/p_mg.mdl";
const string MODEL_V = "models/ns/v_mg.mdl";
const string MODEL_W = "models/ns/w_mg.mdl";
const string MODEL_SHELL = "models/ns/shell.mdl";

//Sounds
const string SND_FIRE = "ns/weapons/mg/mg-1.wav";
const string SND_DRAW = "ns/weapons/mg/lmg_draw.wav";
const string SND_CLIP_IN = "ns/weapons/mg/lmg_clipin.wav";
const string SND_CLIP_OUT = "ns/weapons/mg/lmg_clipout.wav";

array<string> SOUNDS = {
	SND_FIRE,
	SND_DRAW,
	SND_CLIP_IN,
	SND_CLIP_OUT
};

//Anim timings
const float flDeployTime = 1.3f;
const float RELOAD_ANIM_TIME = 4.05;
const float RELOAD_TIME = 2.8;

//Item info
const int MAX_AMMO = 250;
const int MAX_CLIP = 50;
const int SLOT = 2;
const int POSITION = 21;
const int DEFAULT_AMMO = MAX_CLIP;

//Stats
const int DAMAGE = 12;
const int RANGE = 4096;
//const float ROF = 0.1;
const float ROF = 0.06;
const float	XPUNCH = 1.4;
const Vector SPREAD = VECTOR_CONE_4DEGREES;


class weapon_ns_machinegun : ScriptBasePlayerWeaponEntity, NSBASE::WeaponBase
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

	private int m_iShell;
	
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
		m_iShell = g_Game.PrecacheModel( MODEL_SHELL );
		
		for( uint i = 0; i < SOUNDS.length(); i++ )
		{
			g_SoundSystem.PrecacheSound( SOUNDS[i] );
			g_Game.PrecacheGeneric( "sound/" + SOUNDS[i] );
		}
		
		CommonPrecache();
	}
	
	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= MAX_AMMO;
		info.iAmmo1Drop	= MAX_CLIP;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= MAX_CLIP;
		info.iSlot 		= SLOT;
		info.iPosition 	= POSITION;
		info.iFlags 	= ITEM_FLAG_NOAUTOSWITCHEMPTY;
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
	
	bool PlayEmptySound()
	{
		return CommonPlayEmptySound();
	}	
	
	bool Deploy()
	{	
		return Deploy( MODEL_V, MODEL_P, DRAW, "mp5", GetBodygroup(), flDeployTime );
	}

	void Holster( int skipLocal = 0 )
	{
		BaseClass.Holster( skipLocal );
	}	
	
	Vector GetProjectileSpread()
	{
		return SPREAD;
	}
	
	int	GetIdleAnimation()
	{
		int iAnim = 0;
		int iRandomNum = g_PlayerFuncs.SharedRandomLong( m_pPlayer.random_seed, 0, 1 );

		switch(iRandomNum)
		{
		case 0:
			iAnim = IDLE1;
			break;
		case 1:
			iAnim = IDLE2;
			break;
		}
		
		return iAnim;
	}	

	void FireProjectiles()
	{
		Vector vecSrc = m_pPlayer.GetGunPosition();
		Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );
		
		// Fire the bullets and apply damage
		m_pPlayer.FireBullets( 1, vecSrc, vecAiming, GetProjectileSpread(), RANGE, BULLET_PLAYER_CUSTOMDAMAGE, 0, DAMAGE );
		
		ShootWeapon( vecSrc, vecAiming, 1, GetProjectileSpread(), 4096, DAMAGE, false, DMG_BULLET | DMG_NEVERGIB );
	}	
	
	
	void PrimaryAttack()
	{
		if( m_pPlayer.pev.waterlevel == 3 )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = g_Engine.time + ROF;
			return;
		}

		if( self.m_iClip <= 0 )
		{
			self.PlayEmptySound();
			self.SendWeaponAnim( SHOOT_EMPTY, 0, GetBodygroup() );
			self.m_flNextPrimaryAttack = g_Engine.time + 1.0;
			return;
		}
			
		--self.m_iClip;
		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;
		
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.SendWeaponAnim( SHOOT, 0, GetBodygroup() );
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, SND_FIRE, Math.RandomFloat( 0.95, 1.0 ), 0.8, 0, 94 + Math.RandomLong( 0, 0xf ) );
		
		FireProjectiles();
		
		m_pPlayer.pev.punchangle.x = Math.RandomFloat( -XPUNCH, XPUNCH);
		
		ShellEject( m_pPlayer, m_iShell, Vector( 16, 5, -4 ) );
		
		self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + ROF;
		self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomLong( m_pPlayer.random_seed, 10, 15 );
			

	}

	void Reload()
	{		
		int iAmmo = m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType );
		if( self.m_iClip == MAX_CLIP || m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			return;
			
		Reload( MAX_CLIP, RELOAD, RELOAD_TIME, RELOAD_ANIM_TIME, GetBodygroup() );
		
		BaseClass.Reload();
	}
	
	void WeaponIdle()
	{
		self.ResetEmptySound();
		m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );

		if( self.m_flTimeWeaponIdle < g_Engine.time && self.m_iClip != 0 )
		{
			self.SendWeaponAnim( GetIdleAnimation(), 0, GetBodygroup() );
				
			self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 5, 7 );
		}
	}	
}
void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "NS_MACHINEGUN::weapon_ns_machinegun", "weapon_ns_machinegun" );
	g_ItemRegistry.RegisterWeapon( "weapon_ns_machinegun", "ns", "9mm", "", "ammo_9mmAR" );
}
}
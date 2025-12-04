#include "base"

/* Natural Selection Welder Script
By Meryilla

Models, Sounds, and Sprites by Unknown Worlds

Additional Credit to the below for providing guidance in creating these scripts:

https://anggaranothing.gitlab.io/as/svencoop/# Angelscript for SC Docs
INS2 Weapon Scripts for SC - by Kerncore
Natural Selection Source Code - by Unknown Worlds
*/

namespace NS_WELDER
{
enum welder_anims 
{
	IDLE1 = 0,
	IDLE2,
	WELD,
	DRAW
};

enum welder_states
{
	WELDER_OFF = 0,
	WELDER_ON
};

//Models
const string MODEL_P = "models/ns/p_welder.mdl";
const string MODEL_V = "models/ns/v_welder.mdl";
const string MODEL_W = "models/ns/w_welder.mdl";


//Sounds
const string SND_WELDING = "ns/weapons/welder/welderidle.wav";
const string SND_HIT = "ns/weapons/welder/welderhit.wav";
const string SND_STOP = "ns/weapons/welder/welderstop.wav";

array<string> SOUNDS = {
	SND_WELDING,
	SND_HIT,
	SND_STOP
};

//Anim timings
const float DEPLOY_TIME = 1.0;

//Item info
const int MAX_AMMO = 100;
const int MAX_CLIP = WEAPON_NOCLIP;
const int SLOT = 0;
const int POSITION = 21;
const int iDefaultAmmo = 20;
const int AMMO_DROP = 20;



//Stats
const int DAMAGE = 4;
const int RANGE = 90;
const float ROF = 0.2;

const int BARREL_LENGTH = 10;
const float REPAIR_ARMOUR = 1;
const float REPAIR_MACHINE = 10;


class weapon_ns_welder : ScriptBasePlayerWeaponEntity, NSBASE::WeaponBase
{
	private CBasePlayer@ m_pPlayer
	{
		get const 	{ return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
		set       	{ self.m_hPlayer = EHandle( @value ); }
	}
	private int GetBodygroup()
	{
		return 0;
	}	
	
	private int m_iState = WELDER_OFF;
	private bool m_blWelding = false;
	private bool m_blAttackButtonDownLastFrame = false;
	
	void Spawn()
	{
		Precache();
		self.m_iDefaultAmmo = iDefaultAmmo;
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
		
		CommonPrecache();
	}
	
	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= MAX_AMMO;
		info.iAmmo1Drop	= AMMO_DROP;
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
		return Deploy( MODEL_V, MODEL_P, DRAW, "mp5", GetBodygroup(), DEPLOY_TIME );
	}

	void Holster( int skipLocal = 0 )
	{
		m_iState = WELDER_OFF;
		SetIsWelding( false );
		StopSounds();
		BaseClass.Holster( skipLocal );
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

		g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle );
		Vector vecEnd = vecSrc + g_Engine.v_forward * RANGE;

		TraceResult tr;
		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, dont_ignore_glass, m_pPlayer.edict(), tr );
		bool blDidWeld = false;

		if( tr.flFraction < 1.0f )
		{
			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );
			//Is it friendly?
			if( !( m_pPlayer.IRelationship( pEntity ) >= 0 ) )
			{
				//Do some shit here i dunno
				if( pEntity.IsPlayer() && ( pEntity.pev.armorvalue < pEntity.pev.armortype ) )
				{
					pEntity.pev.armorvalue += Math.min( REPAIR_ARMOUR, pEntity.pev.armortype - pEntity.pev.armorvalue );
					blDidWeld = true;
				}
				//Allow it to heal NS turrets, but also normal HL sentries + turrets too
				else if( pEntity.IsMachine() && pEntity.pev.health < pEntity.pev.max_health )
				{
					pEntity.pev.health += Math.min( REPAIR_MACHINE, pEntity.pev.max_health - pEntity.pev.health );
					blDidWeld = true;
				}
			}
			//Otherwise just do damage
			else if( pEntity.IsMonster() || pEntity.pev.classname == "func_weldable" )
			{
				pEntity.TakeDamage( self.pev, m_pPlayer.pev, DAMAGE, DMG_BURN );
				blDidWeld = true;
			}

			if( !blDidWeld )
			{
				if( GetIsWelding() )
				{
					//PLAYBACK_EVENT_FULL(0, this->m_pPlayer->edict(), gWelderConstEventID, 0, this->m_pPlayer->pev->origin, (float *)&g_vecZero, 0.0, 0.0, 1, 0, 0, 0 );
					SetIsWelding( false );
					g_SoundSystem.StopSound( m_pPlayer.edict(), CHAN_STREAM, SND_HIT );
					g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_AUTO, SND_STOP, VOL_NORM, ATTN_NORM, 0, 94 + Math.RandomLong( 0, 0xf ) );
				}
			}
			else
			{
				if( !GetIsWelding() )
				{
					//PLAYBACK_EVENT_FULL(0, this->m_pPlayer->edict(), gWelderConstEventID, 0, this->m_pPlayer->pev->origin, (float *)&g_vecZero, 0.0, 0.0, 0, 0, 0, 0 );
					SetIsWelding( true );
					g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_STREAM, SND_HIT, VOL_NORM, ATTN_NORM, 0, 94 + Math.RandomLong( 0, 0xf ) );
				}
				UseAmmo( 1 );
			}
		}
		else
		{
			if( GetIsWelding() )
			{
				//PLAYBACK_EVENT_FULL(0, this->m_pPlayer->edict(), gWelderConstEventID, 0, this->m_pPlayer->pev->origin, (float *)&g_vecZero, 0.0, 0.0, 1, 0, 0, 0 );
				SetIsWelding( false );
				g_SoundSystem.StopSound( m_pPlayer.edict(), CHAN_STREAM, SND_HIT );
				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_AUTO, SND_STOP, VOL_NORM, ATTN_NORM, 0, 94 + Math.RandomLong( 0, 0xf ) );

				UseAmmo( 1 );
			}
		}
	}

	void UseAmmo( int iCount )
	{
		if ( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) >= iCount )
			m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - iCount );
		else
			m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, 0 );
	}
	
	void PrimaryAttack()
	{
		if( m_pPlayer.pev.waterlevel == 3 )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = g_Engine.time + ROF;
			return;
		}

		if( !m_blAttackButtonDownLastFrame )
		{
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, SND_WELDING, VOL_NORM, ATTN_NORM, 0, 94 + Math.RandomLong( 0, 0xf ) );
			m_blAttackButtonDownLastFrame = true;
		}

		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = g_Engine.time + ROF;
			return;
		}

		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

		self.SendWeaponAnim( WELD, 0, GetBodygroup() );

		//TODO: Enable below when Sven has particle system support
		//WelderEffects();

		//TODO: Check if gun position is valid
		FireProjectiles();

		self.m_flTimeWeaponIdle = g_Engine.time + 0.45;
		self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + ROF;
	}


	//TODO: Finish this. This (probably) can't be finished without shoddy workarounds until Sven has support for
	//particle system manipulation via scripts. Trying to replicate using server-side sprites would likely cause
	//too much lag.
	void WelderEffects()
	{
		Vector vecSrc, vecEnd;

		vecSrc = m_pPlayer.GetGunPosition();
		g_EngineFuncs.MakeVectors( m_pPlayer.pev.v_angle );
		vecEnd = vecSrc + g_Engine.v_forward * RANGE;

		TraceResult tr;
		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, dont_ignore_glass, m_pPlayer.edict(), tr );

		if( tr.flFraction < 1.0f )
		{
			// Adjust the trace so it's offset a bit towards the player so particles aren't clipped away
			Vector vecResult = vecSrc + g_Engine.v_forward * ( ( tr.flFraction - 0.1f) * RANGE );

			//TODO: NS suggests some lights are meant to play here but I don't recall this happening in-game. Should we replicate?
			//Smoke effect
			if( Math.RandomLong( 0, 1 ) == 0 )
			{
				//Smoke particles
			}

			//Blue plasma
			if( Math.RandomLong( 0, 1 ) == 0 )
			{
				//Plasma particles
			}
			
			//Blue plasma shower
			if( Math.RandomLong( 0, 8 ) == 0 )
			{
				//Plasma shower particles
			}
		}
		else
		{
			//Smoke effect
			if( Math.RandomLong( 0, 1 ) == 0 )
			{
				//Smoke particles
			}
		}
	}
	
	void StopSounds()
	{
		g_SoundSystem.StopSound( m_pPlayer.edict(), CHAN_WEAPON, SND_WELDING );
		g_SoundSystem.StopSound( m_pPlayer.edict(), CHAN_STREAM, SND_HIT );
	}
	
	void WeaponIdle()
	{
		self.ResetEmptySound();
		m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );

		if( m_blAttackButtonDownLastFrame )
		{
			g_SoundSystem.StopSound( m_pPlayer.edict(), CHAN_WEAPON, SND_WELDING );
			g_SoundSystem.StopSound( m_pPlayer.edict(), CHAN_STREAM, SND_HIT );
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_AUTO, SND_STOP, VOL_NORM, ATTN_NORM, 0, 94 + Math.RandomLong( 0, 0xf ) );
			m_blAttackButtonDownLastFrame = false;
			SetIsWelding( false );
		}

		if( self.m_flTimeWeaponIdle < g_Engine.time && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) != 0 )
		{
			self.SendWeaponAnim( GetIdleAnimation(), 0, GetBodygroup() );
				
			self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 5, 7 );
		}
	}

	bool GetIsWelding()
	{
		return m_blWelding;
	}

	void SetIsWelding( bool blWelding )
	{
		m_blWelding = blWelding;
	}
}
void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "NS_WELDER::weapon_ns_welder", "weapon_ns_welder" );
	g_ItemRegistry.RegisterWeapon( "weapon_ns_welder", "ns", "uranium", "", "ammo_gaussclip" );
}
}
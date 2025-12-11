/***
*
*    Copyright (c) 1996-2001, Valve LLC. All rights reserved.
*    
*    This product contains software technology licensed from Id 
*    Software, Inc. ("Id Technology").  Id Technology (c) 1996 Id Software, Inc. 
*    All Rights Reserved.
*
*    Use, distribution, and modification of this source code and/or resulting
*    object code is restricted to non-commercial enhancements to products from
*    Valve LLC.  All other use, distribution, or modification is prohibited
*    without written permission from Valve LLC.
*
****/

/* 
* Modified version of weapon_hlshotgun.as by Sidewinder ( https://steamcommunity.com/id/tehsnek/ )
*/

const int SHOTGUN_DEFAULT_AMMO   = 6;
const int SHOTGUN_MAX_CARRY      = 125;
const int SHOTGUN_MAX_CLIP       = 2;
const int SHOTGUN_WEIGHT         = 15;

enum m_iShotgunMode
{
	SHOTGUNMODE_NONE = 0,
	SHOTGUNMODE_HIPS,
	SHOTGUNMODE_QUAKE
};

enum SawnoffAnimation
{
	SW_IDLE = 0,
	SW_DRAW,
	SW_RELOAD,
	SW_SHOOT1,
	SW_SHOOT2,
	SW_IDLEB,
	SW_RELOADB,
	SW_SHOOT1B,
	SW_SHOOT2B,
	SW_RELOAD_SINGLE,
	SW_RELOADB_SINGLE,
	SW_CHANGE,
	SW_RECHANGE,
	SW_STOCK
};

class weapon_sawnoff : ScriptBasePlayerWeaponEntity
{
	protected uint m_iAnimationState;
	private CBasePlayer@ m_pPlayer = null;
	private int m_iShotgunMode;
	private int m_iSwing;
	TraceResult m_trHit;
	float m_flNextReload;
	int m_iShell;
	float m_flPumpTime;
	bool m_fPlayPumpSound;
	bool m_fShotgunReload;

	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, "models/cyrax/wpn/w_sawedoff.mdl" );
		
		self.m_iDefaultAmmo = SHOTGUN_DEFAULT_AMMO;
		m_iShotgunMode = SHOTGUNMODE_HIPS;
		self.FallInit();
	}

	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( "models/cyrax/wpn/v_sawedoff.mdl" );
		g_Game.PrecacheModel( "models/cyrax/wpn/w_sawedoff.mdl" );
		g_Game.PrecacheModel( "models/cyrax/wpn/p_sawedoff.mdl" );

		g_SoundSystem.PrecacheSound( "weapons/sawedoff/insert-shell.wav" );
		g_SoundSystem.PrecacheSound( "weapons/sawedoff/shelldrop.wav" );
		g_SoundSystem.PrecacheSound( "weapons/sawedoff/shellout.wav" );
		g_SoundSystem.PrecacheSound( "weapons/sawedoff/tapspan.wav" );
		g_SoundSystem.PrecacheSound( "weapons/sawedoff/close.wav" );
		g_SoundSystem.PrecacheSound( "weapons/sawedoff/fire.wav" );
		g_SoundSystem.PrecacheSound( "weapons/sawedoff/open.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/bat_hitwall1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/draw.wav" );
		g_SoundSystem.PrecacheSound( "items/gunpickup4.wav" );

		g_Game.PrecacheGeneric( "sprites/cyrax/weapon_sawnoff.txt" );
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( !BaseClass.AddToPlayer( pPlayer ) )
			return false;
			
		@m_pPlayer = pPlayer;
		
		NetworkMessage message( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			message.WriteLong( self.m_iId );
		message.End();
		
		return true;
	}
	
	bool PlayEmptySound()
	{
		if( self.m_bPlayEmptySound && m_pPlayer !is null )
		{
			self.m_bPlayEmptySound = false;
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON,
				"hl/weapons/357_cock1.wav", 0.8, ATTN_NORM, 0, PITCH_NORM );
		}
		
		return false;
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1  = SHOTGUN_MAX_CARRY;
		info.iMaxAmmo2  = -1;
		info.iMaxClip   = SHOTGUN_MAX_CLIP;
		info.iSlot      = 2;
		info.iPosition  = 5;
		info.iFlags     = 0;
		info.iWeight    = SHOTGUN_WEIGHT;

		return true;
	}

	bool Deploy()
	{
		if( m_pPlayer !is null )
		{
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON,
				"cyrax/wpn/draw.wav", 1.0, ATTN_NORM, 0, PITCH_NORM );
		}

		return self.DefaultDeploy(
			self.GetV_Model( "models/cyrax/wpn/v_sawedoff.mdl" ),
			self.GetP_Model( "models/cyrax/wpn/p_sawedoff.mdl" ),
			SW_DRAW, "shotgun" );
	}

	float WeaponTimeBase()
	{
		return g_Engine.time;
	}
	
	void Holster( int skipLocal = 0 )
	{
		m_iShotgunMode = SHOTGUNMODE_HIPS;
		BaseClass.Holster( skipLocal );
	}

	void ItemPreFrame()
	{
		BaseClass.ItemPreFrame();
	}

	void ItemPostFrame()
	{
		BaseClass.ItemPostFrame();
	}

	void CreatePelletDecals( const Vector& in vecSrc, const Vector& in vecAiming,
		const Vector& in vecSpread, const uint uiPelletCount )
	{
		if( m_pPlayer is null )
			return;

		TraceResult tr;
		float x, y;
		
		for( uint uiPellet = 0; uiPellet < uiPelletCount; ++uiPellet )
		{
			g_Utility.GetCircularGaussianSpread( x, y );
			
			Vector vecDir = vecAiming 
							+ x * vecSpread.x * g_Engine.v_right 
							+ y * vecSpread.y * g_Engine.v_up;

			Vector vecEnd = vecSrc + vecDir * 2048;
			
			g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

			// Barrel attachment (unused, but kept if you want to add effects later)
			Vector vecAttachOrigin;
			Vector vecAttachAngles;
			g_EngineFuncs.GetAttachment( m_pPlayer.edict(), 0, vecAttachOrigin, vecAttachAngles );

			if( tr.flFraction < 1.0 )
			{
				if( tr.pHit !is null )
				{
					CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
					
					if( pHit is null || pHit.IsBSPModel() )
						g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_BUCKSHOT );
				}
			}
		}
	}

	void PrimaryAttack()
	{
		if( m_pPlayer is null )
			return;

		// don't fire underwater
		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = g_Engine.time + 0.15;
			return;
		}

		if( self.m_iClip <= 0 )
		{
			self.m_flNextPrimaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 0.25;
			self.PlayEmptySound();
			return;
		}

		if( m_iShotgunMode == SHOTGUNMODE_QUAKE && self.m_iClip == 1 )
			self.SendWeaponAnim( SW_SHOOT2B, 0, 0 );
		else if( m_iShotgunMode != SHOTGUNMODE_QUAKE && self.m_iClip == 1 )
			self.SendWeaponAnim( SW_SHOOT2, 0, 0 );
		else if( m_iShotgunMode == SHOTGUNMODE_QUAKE && self.m_iClip == SHOTGUN_MAX_CLIP )
			self.SendWeaponAnim( SW_SHOOT1B, 0, 0 );
		else if( m_iShotgunMode != SHOTGUNMODE_QUAKE && self.m_iClip == SHOTGUN_MAX_CLIP )
			self.SendWeaponAnim( SW_SHOOT1, 0, 0 );
		
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON,
			"weapons/sawedoff/fire.wav", 1.0, 0.6, 0,
			93 + Math.RandomLong( 0, 0x1f ) );
		
		m_pPlayer.m_iWeaponVolume = LOUD_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash  = NORMAL_GUN_FLASH;
		m_pPlayer.pev.effects    |= EF_MUZZLEFLASH;

		--self.m_iClip;

		// player "shoot" animation
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		Vector vecSrc   = m_pPlayer.GetGunPosition() + g_Engine.v_forward * 12;
		Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );

		CreatePelletDecals( vecSrc, vecAiming, VECTOR_CONE_10DEGREES, 7 );
		m_pPlayer.FireBullets( 7, vecSrc, vecAiming, VECTOR_CONE_10DEGREES,
			2048, BULLET_PLAYER_BUCKSHOT, 0, 25, m_pPlayer.pev );

		if( self.m_iClip == 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
		{
			// HEV suit - indicate out of ammo condition
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );
		}

		if( m_iShotgunMode == SHOTGUNMODE_QUAKE )
			m_pPlayer.pev.punchangle.x = -4.0;
		else
			m_pPlayer.pev.punchangle.x = -5.0;

		self.m_flTimeWeaponIdle = g_Engine.time + 10.0;
		self.m_flNextPrimaryAttack =
		self.m_flNextSecondaryAttack =
		self.m_flNextTertiaryAttack  = g_Engine.time + 0.2;
	}

	void SecondaryAttack()
	{
		if( m_pPlayer is null )
			return;

		g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_STATIC,
			"items/gunpickup4.wav", 0.6, 1.0 );

		switch( m_iShotgunMode )
		{
			case SHOTGUNMODE_HIPS:
			{
				m_iShotgunMode = SHOTGUNMODE_QUAKE;
				self.SendWeaponAnim( SW_CHANGE, 0, 0 );
			}
			break;

			case SHOTGUNMODE_QUAKE:
			{
				m_iShotgunMode = SHOTGUNMODE_HIPS;
				self.SendWeaponAnim( SW_RECHANGE, 0, 0 );
			}
			break;
		}

		self.m_flTimeWeaponIdle = g_Engine.time + 2.0;
		self.m_flNextPrimaryAttack =
		self.m_flNextSecondaryAttack =
		self.m_flNextTertiaryAttack  = g_Engine.time + 0.5;
	}

	void TertiaryAttack()
	{
		if( !Swing( 1 ) )
		{
			SetThink( ThinkFunction( this.SwingAgain ) );
			self.pev.nextthink = g_Engine.time + 0.1;
		}
	}

	void SwingAgain()
	{
		Swing( 0 );
	}

	bool Swing( int fFirst )
	{
		// Safety: never run without a valid player
		if( m_pPlayer is null )
			return false;

		bool fDidHit = false;
		TraceResult tr;

		Math.MakeVectors( m_pPlayer.pev.v_angle );
		Vector vecSrc = m_pPlayer.GetGunPosition();
		Vector vecEnd = vecSrc + g_Engine.v_forward * 32;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if( tr.flFraction >= 1.0f )
		{
			g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters,
				head_hull, m_pPlayer.edict(), tr );

			if( tr.flFraction < 1.0f )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				if( pHit is null || pHit.IsBSPModel() )
				{
					g_Utility.FindHullIntersection(
						vecSrc, tr, tr,
						VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX,
						m_pPlayer.edict() );
				}

				vecEnd = tr.vecEndPos;
			}
		}

		// MISS
		if( tr.flFraction >= 1.0f )
		{
			if( fFirst != 0 )
			{
				self.SendWeaponAnim( SW_STOCK );

				self.m_flNextPrimaryAttack   =
				self.m_flNextSecondaryAttack =
				self.m_flNextTertiaryAttack  = g_Engine.time + 1.0f;

				self.m_flTimeWeaponIdle = g_Engine.time + 3.0f;
				m_iShotgunMode = SHOTGUNMODE_HIPS;

				g_SoundSystem.EmitSoundDyn(
					m_pPlayer.edict(),
					CHAN_WEAPON,
					"zombie/claw_miss1.wav",
					1.0f, ATTN_NORM, 0,
					94 + Math.RandomLong( 0, 0xF ) );

				m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 
			}

			return false;
		}

		// HIT
		fDidHit = true;

		CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

		self.SendWeaponAnim( SW_STOCK );
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 

		float flDamage = ( self.m_flCustomDmg > 0 ) ? self.m_flCustomDmg : 15.0f;

		// Safe MultiDamage usage + null guard on target
		g_WeaponFuncs.ClearMultiDamage();

		if( pEntity !is null )
		{
			pEntity.TraceAttack(
				m_pPlayer.pev,
				flDamage,
				g_Engine.v_forward,
				tr,
				DMG_CLUB | DMG_NEVERGIB | DMG_LAUNCH );
		}

		g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

		float flVol     = 1.0f;
		bool fHitWorld  = true;

		self.m_flNextPrimaryAttack   =
		self.m_flNextSecondaryAttack =
		self.m_flNextTertiaryAttack  = g_Engine.time + 1.0f;

		self.m_flTimeWeaponIdle = g_Engine.time + 3.0f;
		m_iShotgunMode = SHOTGUNMODE_HIPS;

		if( pEntity !is null )
		{
			int iClass = pEntity.Classify();

			if( iClass != CLASS_NONE && iClass != CLASS_MACHINE &&
				pEntity.BloodColor() != DONT_BLEED )
			{
				if( pEntity.IsPlayer() )
				{
					// pull them a bit toward you
					pEntity.pev.velocity = pEntity.pev.velocity
						+ ( self.pev.origin - pEntity.pev.origin ).Normalize() * 120.0f;
				}

				// flesh hit sounds
				switch( Math.RandomLong( 0, 2 ) )
				{
					case 0:
						g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON,
							"zombie/claw_strike1.wav", 1.0f, ATTN_NORM ); break;
					case 1:
						g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON,
							"zombie/claw_strike2.wav", 1.0f, ATTN_NORM ); break;
					case 2:
						g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON,
							"zombie/claw_strike3.wav", 1.0f, ATTN_NORM ); break;
				}

				m_pPlayer.m_iWeaponVolume = 128; 

				if( !pEntity.IsAlive() )
				{
					m_pPlayer.m_iWeaponVolume = 512;
					return true;
				}
				else
				{
					flVol = 0.1f;
				}

				fHitWorld = false;
			}
		}

		if( fHitWorld )
		{
			float fvolbar = g_SoundSystem.PlayHitSound(
				tr,
				vecSrc,
				vecSrc + ( vecEnd - vecSrc ) * 2,
				BULLET_PLAYER_CROWBAR );

			// override volume, no texture sounds in MP
			fvolbar = 1.0f;

			g_SoundSystem.EmitSoundDyn(
				m_pPlayer.edict(),
				CHAN_WEAPON,
				"cyrax/wpn/bat_hitwall1.wav",
				fvolbar, ATTN_NORM, 0,
				98 + Math.RandomLong( 0, 3 ) ); 
		}

		m_pPlayer.m_iWeaponVolume = int( flVol * 512.0f ); 

		return fDidHit;
	}

	void Reload()
	{
		if( m_pPlayer is null )
			return;

		if( self.m_iClip == SHOTGUN_MAX_CLIP ||
			m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) == 0 ||
			self.m_fInReload )
			return;

		if( m_iShotgunMode != SHOTGUNMODE_QUAKE )
		{
			if( self.m_iClip == 1 || m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 1 )
				self.DefaultReload( 2, SW_RELOAD_SINGLE, 2.0, 0 );
			else
				self.DefaultReload( 2, SW_RELOAD, 2.0, 0 );
		}
		else
		{
			if( self.m_iClip == 1 || m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 1 )
				self.DefaultReload( 2, SW_RELOADB_SINGLE, 2.0, 0 );
			else
				self.DefaultReload( 2, SW_RELOADB, 2.0, 0 );
		}

		BaseClass.Reload();
	}

	void WeaponIdle()
	{
		if( self.m_flTimeWeaponIdle < g_Engine.time )
		{
			if( m_iShotgunMode != SHOTGUNMODE_QUAKE )
				self.SendWeaponAnim( SW_IDLE, 0, 0 );
			else
				self.SendWeaponAnim( SW_IDLEB, 0, 0 );

			self.m_flTimeWeaponIdle = g_Engine.time + 30.0f / 16.0f * 2.0f;
		}
	}
}

void Register339Sawnoff()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_sawnoff", "weapon_sawnoff" );
	g_ItemRegistry.RegisterWeapon( "weapon_sawnoff", "cyrax", "buckshot", "", "ammo_buckshot", "" );
}

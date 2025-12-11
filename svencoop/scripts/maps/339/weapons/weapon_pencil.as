/*
 * weapon_pencil.as (Black Stylus)
 * Melee stylus weapon (slash + stab).
 * - Primary: quick slash
 * - Secondary: heavy stab with blood puff
 * Uses only v_pencil view model, no W_ or P_ models.
 */

enum pencil_e
{
	PENCIL_IDLE = 0,
	PENCIL_SLASH,
	PENCIL_DRAW,
	PENCIL_STAB,
	PENCIL_STABMISS
};

class weapon_pencil : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;

	TraceResult m_trHit;

	// Damage tuning
	float m_flSlashDamage = 6.0f;   // primary
	float m_flStabDamage  = 14.0f;  // secondary

	void Spawn()
	{
		self.Precache();
		// No world model (invisible pickup; use func_button/game_player_equip)
		self.m_iClip = -1;
		self.FallInit();
	}

	void Precache()
	{
		self.PrecacheCustomModels();

		// View model — stylus
		g_Game.PrecacheModel( "models/cyrax/wpn/v_pencil.mdl" );

		// Sounds
		g_SoundSystem.PrecacheSound( "cyrax/wpn/bat_deploy1.wav" );    // deploy
		g_SoundSystem.PrecacheSound( "cyrax/wpn/pencil_hit.wav" );     // slash hit
		g_SoundSystem.PrecacheSound( "cyrax/wpn/pencil_stab.wav" );    // stab hit
		g_SoundSystem.PrecacheSound( "weapons/knife3.wav" );           // miss

		// Blood sprite
		g_Game.PrecacheModel( "sprites/blood.spr" );

		// HUD
		g_Game.PrecacheGeneric( "sprites/cyrax/weapon_pencil.txt" );
	}

	// Optional helpers (not strictly required, but clarify intent)
	string GetW_Model() { return ""; }
	string GetP_Model() { return ""; }

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 = -1;
		info.iMaxAmmo2 = -1;
		info.iMaxClip  = WEAPON_NOCLIP;
		info.iSlot     = 0;
		info.iPosition = 19;
		info.iWeight   = 0;
		return true;
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( !BaseClass.AddToPlayer( pPlayer ) )
			return false;

		@m_pPlayer = pPlayer;
		return true;
	}

	bool Deploy()
	{
		g_SoundSystem.EmitSoundDyn(
			m_pPlayer.edict(), CHAN_ITEM,
			"cyrax/wpn/bat_deploy1.wav",
			1.0, ATTN_NORM, 0, PITCH_NORM
		);

		// Only view model
		return self.DefaultDeploy(
			"models/cyrax/wpn/v_pencil.mdl",
			"", // no P model
			PENCIL_DRAW,
			"crowbar"
		);
	}

	void Holster( int skipLocal )
	{
		m_pPlayer.pev.viewmodel = "";
		self.m_fInReload = false;
		m_pPlayer.m_flNextAttack = g_WeaponFuncs.WeaponTimeBase() + 0.5f;
	}

	// ========================================================
	// PRIMARY ATTACK (slash)
	// ========================================================
	void PrimaryAttack()
	{
		self.SendWeaponAnim( PENCIL_SLASH );
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		if (DoDamage(m_flSlashDamage, false))
			PlayImpactSound(false); // slash sound
		else
			PlayMissSound();

		self.m_flNextPrimaryAttack = g_Engine.time + 0.35f;
	}

	// ========================================================
	// SECONDARY ATTACK (stab)
	// ========================================================
	void SecondaryAttack()
	{
		// Prevent cheesy air stabs
		if ((m_pPlayer.pev.flags & FL_ONGROUND) == 0)
		{
			PrimaryAttack();
			return;
		}

		self.SendWeaponAnim( PENCIL_STAB );
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		if (DoDamage(m_flStabDamage, true))
		{
			BloodBurst();
			PlayImpactSound(true); // stab sound
		}
		else
		{
			self.SendWeaponAnim( PENCIL_STABMISS );
			PlayMissSound();
		}

		self.m_flNextSecondaryAttack = g_Engine.time + 1.0f;
	}

	// ========================================================
	// HIT TRACE + DAMAGE (crowbar-style, with hull)
	// ========================================================
	bool DoDamage(float flDamage, bool bStab)
	{
		TraceResult tr;
		Math.MakeVectors( m_pPlayer.pev.v_angle );

		Vector vecSrc = m_pPlayer.GetGunPosition();
		Vector vecEnd = vecSrc + g_Engine.v_forward * 48; // a bit more reach

		// First: simple line trace
		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		// If we didn't hit, try a hull trace (thicker hitbox)
		if( tr.flFraction >= 1.0f )
		{
			g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr );
			if( tr.flFraction < 1.0f )
			{
				CBaseEntity@ pHitHull = g_EntityFuncs.Instance( tr.pHit );
				if( pHitHull is null || pHitHull.IsBSPModel() )
				{
					g_Utility.FindHullIntersection(
						vecSrc, tr, tr,
						VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX,
						m_pPlayer.edict() );
				}
			}
		}

		if( tr.flFraction < 1.0f )
		{
			CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
			if( pHit !is null && pHit.IsAlive() )
			{
				g_WeaponFuncs.ClearMultiDamage();
				pHit.TraceAttack(
					m_pPlayer.pev,
					flDamage,
					g_Engine.v_forward,
					tr,
					DMG_SLASH | DMG_NEVERGIB
				);
				g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );
				return true;
			}
		}

		return false;
	}

	// ========================================================
	// SOUND HELPERS
	// ========================================================
	void PlayImpactSound(bool bStab)
	{
		if( bStab )
		{
			g_SoundSystem.EmitSoundDyn(
				m_pPlayer.edict(), CHAN_WEAPON,
				"cyrax/wpn/pencil_stab.wav",
				1, ATTN_NORM, 0, 100 );
		}
		else
		{
			g_SoundSystem.EmitSoundDyn(
				m_pPlayer.edict(), CHAN_WEAPON,
				"cyrax/wpn/pencil_hit.wav",
				1, ATTN_NORM, 0, 100 );
		}
	}

	void PlayMissSound()
	{
		g_SoundSystem.EmitSoundDyn(
			m_pPlayer.edict(), CHAN_WEAPON,
			"weapons/knife3.wav",
			1, ATTN_NORM, 0, 100 );
	}

	// ========================================================
	// BLOOD EFFECT – ONLY ON LIVING BLEEDERS
	// ========================================================
	void BloodBurst()
	{
		TraceResult tr;
		Math.MakeVectors( m_pPlayer.pev.v_angle );

		Vector vecSrc = m_pPlayer.GetGunPosition();
		Vector vecEnd = vecSrc + g_Engine.v_forward * 48;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if( tr.flFraction < 1.0f )
		{
			CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
			if( pHit is null )
				return;

			if( !pHit.IsAlive() )
				return;

			if( pHit.BloodColor() == DONT_BLEED )
				return;

			int cls = pHit.Classify();
			if( cls == CLASS_NONE || cls == CLASS_MACHINE )
				return;

			NetworkMessage bloodMsg( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, tr.vecEndPos );
			bloodMsg.WriteByte( TE_BLOODSPRITE );
			bloodMsg.WriteCoord( tr.vecEndPos.x );
			bloodMsg.WriteCoord( tr.vecEndPos.y );
			bloodMsg.WriteCoord( tr.vecEndPos.z );
			bloodMsg.WriteShort( g_EngineFuncs.ModelIndex( "sprites/blood.spr" ) );
			bloodMsg.WriteShort( g_EngineFuncs.ModelIndex( "sprites/blood.spr" ) );
			bloodMsg.WriteByte( 247 ); // red
			bloodMsg.WriteByte( 15 );
			bloodMsg.End();
		}
	}
}

void Register339Pencil()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_pencil", "weapon_pencil" );
	g_ItemRegistry.RegisterWeapon( "weapon_pencil", "cyrax" );
}

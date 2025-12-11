/* 
* Modified version of the weapon_hlcrowbar.as by Sidewinder ( https://steamcommunity.com/id/tehsnek/ )
* P_ & W_ models by Xurn.
*/

// *** Tuning constants
const float BAT_RANGE        = 56.0f;   // was 48; slightly longer reach
const float BAT_DAMAGE       = 75.0f;   // base damage before customDmg override
const float BAT_HEAVY_DAMAGE = 200.0f;  // charged secondary damage
const float BAT_CHARGE_TIME  = 1.0f;    // seconds to fully charge

enum bat_e
{
	BAT_IDLE = 0,
	BAT_DRAW,
	BAT_HOLSTER,
	BAT_ATTACK1HIT,
	BAT_ATTACK1MISS,
	BAT_ATTACK2MISS,
	BAT_ATTACK2HIT,
	BAT_ATTACK3MISS,
	BAT_ATTACK3HIT,
	BAT_CHARGE                // seq index 9 == idle2 in QC
};

class weapon_bat : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;
	int m_iSwing;
	TraceResult m_trHit;

	// Charge / heavy attack state
	bool  m_bCharging     = false;
	float m_flChargeStart = 0.0f;
	bool  m_bHeavySwing   = false;
	
	void Spawn()
	{
		self.Precache();
		g_EntityFuncs.SetModel( self, self.GetW_Model( "models/cyrax/wpn/w_bat.mdl" ) );
		self.m_iClip       = -1;
		self.m_flCustomDmg = self.pev.dmg;

		self.FallInit(); // get ready to fall down
	}

	void Precache()
	{
		self.PrecacheCustomModels();

		g_Game.PrecacheModel( "models/cyrax/wpn/v_bat.mdl" );
		g_Game.PrecacheModel( "models/cyrax/wpn/w_bat.mdl" );
		g_Game.PrecacheModel( "models/cyrax/wpn/p_bat.mdl" );

		g_SoundSystem.PrecacheSound( "cyrax/wpn/bat_deploy1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/bat_hit1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/bat_hit2.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/bat_hit3.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/bat_hit4.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/bat_hitwall1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/bat_slash1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/bat_slash2.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/bat_stab.wav" ); // used for heavy impact

		g_Game.PrecacheGeneric( "sprites/cyrax/weapon_bat.txt" );
		g_Game.PrecacheModel( "sprites/cyrax/640hud1_bat.spr" );
		g_Game.PrecacheModel( "sprites/cyrax/640hud4_bat.spr" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1  = -1;
		info.iMaxAmmo2  = -1;
		info.iMaxClip   = WEAPON_NOCLIP;
		info.iSlot      = 0;
		info.iPosition  = 6;
		info.iWeight    = 0;
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
		m_bCharging   = false;
		m_bHeavySwing = false;

		return self.DefaultDeploy( self.GetV_Model( "models/cyrax/wpn/v_bat.mdl" ),
								   self.GetP_Model( "models/cyrax/wpn/p_bat.mdl" ),
								   BAT_DRAW, "crowbar" );
	}

	void Holster( int skiplocal = 0 )
	{
		self.m_fInReload = false; // cancel any reload in progress

		m_bCharging   = false;
		m_bHeavySwing = false;

		if( m_pPlayer !is null )
		{
			m_pPlayer.m_flNextAttack = g_WeaponFuncs.WeaponTimeBase() + 0.5;
			m_pPlayer.pev.viewmodel = "";
		}
		
		SetThink( null );
	}

	void ItemPreFrame()
	{
		BaseClass.ItemPreFrame();
	}

	void ItemPostFrame()
	{
		if( m_pPlayer !is null )
		{
			// Handle release of charge
			if( m_bCharging )
			{
				// If the player let go of attack2, do the swing
				if( (m_pPlayer.pev.button & IN_ATTACK2) == 0 )
				{
					m_bCharging = false;

					float held = g_Engine.time - m_flChargeStart;

					// Fully charged → heavy swing
					if( held >= BAT_CHARGE_TIME )
					{
						m_bHeavySwing = true;

						if( !Swing( 1 ) )
						{
							SetThink( ThinkFunction( this.SwingAgain ) );
							self.pev.nextthink = g_Engine.time + 0.1;
						}

						// Heavier cooldown
						self.m_flNextSecondaryAttack = g_Engine.time + 1.0f;
						self.m_flNextPrimaryAttack   = g_Engine.time + 0.75f;
					}
					else
					{
						// Not fully charged → normal swing
						m_bHeavySwing = false;

						if( !Swing( 1 ) )
						{
							SetThink( ThinkFunction( this.SwingAgain ) );
							self.pev.nextthink = g_Engine.time + 0.1;
						}

						self.m_flNextSecondaryAttack = g_Engine.time + 0.5f;
						self.m_flNextPrimaryAttack   = g_Engine.time + 0.5f;
					}
				}
			}
		}

		BaseClass.ItemPostFrame();
	}
	
	void PrimaryAttack()
	{
		// Normal light swing
		m_bHeavySwing = false;
		m_bCharging   = false; // cancel any charge if it was somehow active

		if( !Swing( 1 ) )
		{
			SetThink( ThinkFunction( this.SwingAgain ) );
			self.pev.nextthink = g_Engine.time + 0.1;
		}
	}

	void SecondaryAttack()
	{
		if( m_pPlayer is null )
			return;

		// Start charging only if not already doing it
		if( !m_bCharging )
		{
			m_bCharging     = true;
			m_flChargeStart = g_Engine.time;
			m_bHeavySwing   = false;

			// Play charge-up animation (idle2 seq)
			self.SendWeaponAnim( BAT_CHARGE );

			// Small delay before other attacks
			self.m_flNextPrimaryAttack   = g_Engine.time + 0.1f;
			self.m_flNextSecondaryAttack = g_Engine.time + 0.1f;

			// Optional: subtle loop sound here if you add one
			// g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/bat_slash2.wav", 0.6f, ATTN_NORM );
		}
	}
	
	void Smack()
	{
		g_WeaponFuncs.DecalGunshot( m_trHit, BULLET_PLAYER_CROWBAR );
	}

	void SwingAgain()
	{
		// Follow-up swings are always treated as light
		m_bHeavySwing = false;
		Swing( 0 );
	}

	bool Swing( int fFirst )
	{
		if( m_pPlayer is null )
			return false;

		// Read heavy flag once at start, clear it so it only applies to this swing
		const bool bHeavy = m_bHeavySwing;
		m_bHeavySwing = false;

		bool fDidHit = false;

		TraceResult tr;

		Math.MakeVectors( m_pPlayer.pev.v_angle );
		Vector vecSrc = m_pPlayer.GetGunPosition();
		// Increased range
		Vector vecEnd = vecSrc + g_Engine.v_forward * BAT_RANGE;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if( tr.flFraction >= 1.0 )
		{
			g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr );
			if( tr.flFraction < 1.0 )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				if( pHit is null || pHit.IsBSPModel() )
					g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, m_pPlayer.edict() );
				vecEnd = tr.vecEndPos;
			}
		}

		if( tr.flFraction >= 1.0 )
		{
			// MISS
			if( fFirst != 0 )
			{
				switch( ( m_iSwing++ ) % 3 )
				{
				case 0: self.SendWeaponAnim( BAT_ATTACK1MISS ); break;
				case 1: self.SendWeaponAnim( BAT_ATTACK2MISS ); break;
				case 2: self.SendWeaponAnim( BAT_ATTACK3MISS ); break;
				}

				self.m_flNextPrimaryAttack = g_Engine.time + 0.5;

				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON,
					"cyrax/wpn/bat_slash1.wav", 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0, 0xF ) );

				m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
			}
		}
		else
		{
			// HIT
			fDidHit = true;
			
			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

			// Rotate through all 3 hit anims
			switch( ( m_iSwing++ ) % 3 )
			{
			case 0: self.SendWeaponAnim( BAT_ATTACK1HIT ); break;
			case 1: self.SendWeaponAnim( BAT_ATTACK2HIT ); break;
			case 2: self.SendWeaponAnim( BAT_ATTACK3HIT ); break;
			}

			m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 

			// Damage tuning
			float flDamage;

			if( bHeavy )
			{
				// Charged heavy smash
				flDamage = BAT_HEAVY_DAMAGE;
			}
			else
			{
				flDamage = BAT_DAMAGE;
				if( self.m_flCustomDmg > 0 )
					flDamage = self.m_flCustomDmg;

				// Original "combo" damage scaling – keep only for light hits
				if( self.m_flNextPrimaryAttack + 1 >= g_Engine.time )
					flDamage *= 0.75f;
			}

			g_WeaponFuncs.ClearMultiDamage();

			pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_CLUB | DMG_NEVERGIB );
			g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

			float flVol = 1.0f;
			bool fHitWorld = true;

			if( pEntity !is null )
			{
				self.m_flNextPrimaryAttack = g_Engine.time + 0.30f;

				if( pEntity.Classify() != CLASS_NONE && pEntity.Classify() != CLASS_MACHINE &&
					pEntity.BloodColor() != DONT_BLEED )
				{
					// Small pull effect if you hit players (same as HL crowbar)
					if( pEntity.IsPlayer() )
					{
						pEntity.pev.velocity = pEntity.pev.velocity +
							( self.pev.origin - pEntity.pev.origin ).Normalize() * 120;
					}

					// Meat hit sounds – special heavy sound vs normal
					if( bHeavy )
					{
						g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/bat_stab.wav", 1, ATTN_NORM );
					}
					else
					{
						switch( Math.RandomLong( 0, 3 ) )
						{
						case 0:
							g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/bat_hit1.wav", 1, ATTN_NORM ); break;
						case 1:
							g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/bat_hit2.wav", 1, ATTN_NORM ); break;
						case 2:
							g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/bat_hit3.wav", 1, ATTN_NORM ); break;
						case 3:
							g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/bat_hit4.wav", 1, ATTN_NORM ); break;
						}
					}

					m_pPlayer.m_iWeaponVolume = 128;

					if( !pEntity.IsAlive() )
						return true;
					else
						flVol = 0.1f;

					fHitWorld = false;
				}
			}

			if( fHitWorld )
			{
				float fvolbar = g_SoundSystem.PlayHitSound(
					tr, vecSrc, vecSrc + ( vecEnd - vecSrc ) * 2, BULLET_PLAYER_CROWBAR );
				
				self.m_flNextPrimaryAttack = g_Engine.time + 0.3f;

				fvolbar = 1.0f;

				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON,
					"cyrax/wpn/bat_hitwall1.wav", fvolbar, ATTN_NORM, 0, 80 );
			}

			m_trHit = tr;
			m_pPlayer.m_iWeaponVolume = int( flVol * 512 );
		}

		return fDidHit;
	}
}

void Register339Bat()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_bat", "weapon_bat" );
	g_ItemRegistry.RegisterWeapon( "weapon_bat", "cyrax" );
}

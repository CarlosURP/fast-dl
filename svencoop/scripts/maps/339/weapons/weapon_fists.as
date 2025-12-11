/* 
* Fists weapon for map 339
* Based on weapon_hlcrowbar.as by Sidewinder
*/

enum fists
{
	FIST_IDLE = 0,
	FIST_PUNCH1,
	FIST_PUNCH2,
	FIST_PUNCH3,
	FIST_PUNCH4,
	FIST_IDLE2,
	FIST_LOWER,
	FIST_RAISE
};

class weapon_fists : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;

	TraceResult m_trHit;

	// --------------------------------------------------------
	// Spawn / precache
	// --------------------------------------------------------
	void Spawn()
	{
		self.Precache();

		// Use v_fists as world model (pickup) for now
		g_EntityFuncs.SetModel( self, self.GetW_Model( "models/cyrax/wpn/v_fists.mdl" ) );

		self.m_iClip       = -1;
		self.m_flCustomDmg = self.pev.dmg;

		self.FallInit(); // get ready to fall down
	}

	void Precache()
	{
		self.PrecacheCustomModels();

		// View/world model
		g_Game.PrecacheModel( "models/cyrax/wpn/v_fists.mdl" );

		// Sounds
		g_SoundSystem.PrecacheSound( "cyrax/wpn/fists_deploy1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/fists_hit1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/fists_hit2.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/fists_hit3.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/fists_hit4.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/fists_hitwall1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/fists_slash1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/fists_slash2.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/fists_stab.wav" );

		g_Game.PrecacheGeneric( "sprites/cyrax/weapon_fists.txt" );
	}

	// --------------------------------------------------------
	// Weapon info / add to player
	// --------------------------------------------------------
	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 = -1;
		info.iMaxAmmo2 = -1;
		info.iMaxClip  = WEAPON_NOCLIP;
		info.iSlot     = 0;
		info.iPosition = 10;
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

	float WeaponTimeBase()
	{
		return g_Engine.time;
	}

	// --------------------------------------------------------
	// Deploy / holster / no-drop
	// --------------------------------------------------------
	bool Deploy()
	{
		if( m_pPlayer is null )
			return false;

		g_SoundSystem.EmitSoundDyn(
			m_pPlayer.edict(), CHAN_VOICE,
			"cyrax/wpn/fists_deploy1.wav",
			1.0, ATTN_NORM, 0, PITCH_NORM
		);

		self.m_flTimeWeaponIdle = WeaponTimeBase() + 0.4f;

		// v_fists as view model, NO p_model -> invisible in 3rd person
		return self.DefaultDeploy(
			self.GetV_Model( "models/cyrax/wpn/v_fists.mdl" ),
			"", // no p_ model
			FIST_RAISE,
			"crowbar"
		);
	}

	void Holster( int skiplocal )
	{
		self.m_fInReload = false;

		if( m_pPlayer !is null )
		{
			m_pPlayer.m_flNextAttack = g_WeaponFuncs.WeaponTimeBase() + 0.5f; 
			m_pPlayer.pev.viewmodel  = "";
		}

		SetThink( null );
	}

	// Make fists un-droppable (but still switchable)
	CBasePlayerItem@ DropItem()
	{
		// Returning null prevents a world weapon from spawning
		return null;
	}

	// --------------------------------------------------------
	// Attacks
	// --------------------------------------------------------
	void PrimaryAttack()
	{
		if( !Swing( 1 ) )
		{
			SetThink( ThinkFunction( this.SwingAgain ) );
			self.pev.nextthink = g_Engine.time + 0.1f;
		}
	}

	void SecondaryAttack()
	{
		if( !Swing2( 1 ) )
		{
			SetThink( ThinkFunction( this.SwingAgain2 ) );
			self.pev.nextthink = g_Engine.time + 0.1f;
		}
	}

	void Smack()
	{
		g_WeaponFuncs.DecalGunshot( m_trHit, DECAL_GUNSHOT1 );
	}

	void SwingAgain()
	{
		Swing( 0 );
	}

	void SwingAgain2()
	{
		Swing2( 0 );
	}

	// --------------------------------------------------------
	// Left punch
	// --------------------------------------------------------
	bool Swing( int fFirst )
	{
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
			g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr );
			if( tr.flFraction < 1.0f )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				if( pHit is null || pHit.IsBSPModel() )
					g_Utility.FindHullIntersection(
						vecSrc, tr, tr,
						VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX,
						m_pPlayer.edict()
					);
				vecEnd = tr.vecEndPos;
			}
		}

		if( tr.flFraction >= 1.0f )
		{
			if( fFirst != 0 )
			{
				self.SendWeaponAnim( FIST_PUNCH3 );

				self.m_flNextPrimaryAttack   =
				self.m_flNextSecondaryAttack =
				self.m_flNextTertiaryAttack  = g_Engine.time + 0.5f;

				self.m_flTimeWeaponIdle = WeaponTimeBase() + 0.55f;

				g_SoundSystem.EmitSoundDyn(
					m_pPlayer.edict(), CHAN_WEAPON,
					"cyrax/wpn/fists_slash1.wav",
					1.0, ATTN_NORM, 0,
					94 + Math.RandomLong( 0, 0xF )
				);

				m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
			}
		}
		else
		{
			// Hit something
			fDidHit = true;
			
			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

			self.SendWeaponAnim( FIST_PUNCH1 );
			m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 

			float flDamage = 10.0f;
			if( self.m_flCustomDmg > 0 )
				flDamage = self.m_flCustomDmg;

			g_WeaponFuncs.ClearMultiDamage();
			if( self.m_flNextPrimaryAttack + 1 < g_Engine.time )
				pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_CLUB | DMG_NEVERGIB );  
			else
				pEntity.TraceAttack( m_pPlayer.pev, flDamage * 0.75f, g_Engine.v_forward, tr, DMG_CLUB | DMG_NEVERGIB );
			g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

			float flVol    = 1.0f;
			bool  fHitWorld = true;

			if( pEntity !is null )
			{
				self.m_flNextTertiaryAttack   =
				self.m_flNextPrimaryAttack   =
				self.m_flNextSecondaryAttack  = g_Engine.time + 0.30f;
				self.m_flTimeWeaponIdle       = WeaponTimeBase() + 0.35f;

				if( pEntity.Classify() != CLASS_NONE &&
				    pEntity.Classify() != CLASS_MACHINE &&
				    pEntity.BloodColor() != DONT_BLEED )
				{
					if( pEntity.IsPlayer() )
					{
						pEntity.pev.velocity = pEntity.pev.velocity +
							( self.pev.origin - pEntity.pev.origin ).Normalize() * 120;
					}

					switch( Math.RandomLong( 0, 3 ) )
					{
						case 0: g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/fists_hit1.wav", 1, ATTN_NORM ); break;
						case 1: g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/fists_hit2.wav", 1, ATTN_NORM ); break;
						case 2: g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/fists_hit3.wav", 1, ATTN_NORM ); break;
						case 3: g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/fists_hit4.wav", 1, ATTN_NORM ); break;
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
					tr, vecSrc, vecSrc + ( vecEnd - vecSrc ) * 2,
					BULLET_PLAYER_CROWBAR
				);
				
				self.m_flNextTertiaryAttack   =
				self.m_flNextPrimaryAttack   =
				self.m_flNextSecondaryAttack  = g_Engine.time + 0.30f;
				self.m_flTimeWeaponIdle       = WeaponTimeBase() + 0.35f;
				
				fvolbar = 1.0f;

				g_SoundSystem.EmitSoundDyn(
					m_pPlayer.edict(), CHAN_WEAPON,
					"cyrax/wpn/fists_hitwall1.wav",
					fvolbar, ATTN_NORM, 0,
					98 + Math.RandomLong( 0, 3 )
				);
			}

			m_trHit = tr;
			m_pPlayer.m_iWeaponVolume = int( flVol * 512 ); 
		}
		return fDidHit;
	}

	// --------------------------------------------------------
	// Right punch
	// --------------------------------------------------------
	bool Swing2( int fFirst )
	{
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
			g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr );
			if( tr.flFraction < 1.0f )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				if( pHit is null || pHit.IsBSPModel() )
					g_Utility.FindHullIntersection(
						vecSrc, tr, tr,
						VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX,
						m_pPlayer.edict()
					);
				vecEnd = tr.vecEndPos;
			}
		}

		if( tr.flFraction >= 1.0f )
		{
			if( fFirst != 0 )
			{
				self.SendWeaponAnim( FIST_PUNCH4 );

				self.m_flNextPrimaryAttack   =
				self.m_flNextSecondaryAttack =
				self.m_flNextTertiaryAttack  = g_Engine.time + 0.5f;

				self.m_flTimeWeaponIdle = WeaponTimeBase() + 0.55f;

				g_SoundSystem.EmitSoundDyn(
					m_pPlayer.edict(), CHAN_WEAPON,
					"cyrax/wpn/fists_slash1.wav",
					1.0, ATTN_NORM, 0,
					94 + Math.RandomLong( 0, 0xF )
				);

				m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 
			}
		}
		else
		{
			fDidHit = true;
			
			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

			self.SendWeaponAnim( FIST_PUNCH2 );
			m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 

			float flDamage = 10.0f;
			if( self.m_flCustomDmg > 0 )
				flDamage = self.m_flCustomDmg;

			g_WeaponFuncs.ClearMultiDamage();
			if( self.m_flNextPrimaryAttack + 1 < g_Engine.time )
				pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_CLUB | DMG_NEVERGIB );  
			else
				pEntity.TraceAttack( m_pPlayer.pev, flDamage * 0.75f, g_Engine.v_forward, tr, DMG_CLUB | DMG_NEVERGIB );
			g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

			float flVol    = 1.0f;
			bool  fHitWorld = true;

			if( pEntity !is null )
			{
				self.m_flNextTertiaryAttack   =
				self.m_flNextPrimaryAttack   =
				self.m_flNextSecondaryAttack  = g_Engine.time + 0.30f;
				self.m_flTimeWeaponIdle       = WeaponTimeBase() + 0.35f;

				if( pEntity.Classify() != CLASS_NONE &&
				    pEntity.Classify() != CLASS_MACHINE &&
				    pEntity.BloodColor() != DONT_BLEED )
				{
					if( pEntity.IsPlayer() )
					{
						pEntity.pev.velocity = pEntity.pev.velocity +
							( self.pev.origin - pEntity.pev.origin ).Normalize() * 120;
					}

					switch( Math.RandomLong( 0, 3 ) )
					{
						case 0: g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/fists_hit1.wav", 1, ATTN_NORM ); break;
						case 1: g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/fists_hit2.wav", 1, ATTN_NORM ); break;
						case 2: g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/fists_hit3.wav", 1, ATTN_NORM ); break;
						case 3: g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/fists_hit4.wav", 1, ATTN_NORM ); break;
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
					tr, vecSrc, vecSrc + ( vecEnd - vecSrc ) * 2,
					BULLET_PLAYER_CROWBAR
				);
				
				self.m_flNextTertiaryAttack   =
				self.m_flNextPrimaryAttack   =
				self.m_flNextSecondaryAttack  = g_Engine.time + 0.30f;
				self.m_flTimeWeaponIdle       = WeaponTimeBase() + 0.35f;
				
				fvolbar = 1.0f;

				g_SoundSystem.EmitSoundDyn(
					m_pPlayer.edict(), CHAN_WEAPON,
					"cyrax/wpn/fists_hitwall1.wav",
					fvolbar, ATTN_NORM, 0,
					98 + Math.RandomLong( 0, 3 )
				);
			}

			m_trHit = tr;
			m_pPlayer.m_iWeaponVolume = int( flVol * 512 ); 
		}
		return fDidHit;
	}

	// --------------------------------------------------------
	// Idle
	// --------------------------------------------------------
	void WeaponIdle()
	{
		if( self.m_flTimeWeaponIdle > WeaponTimeBase() )
			return;

		self.SendWeaponAnim( FIST_IDLE );
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 1.0f;
	}
}

void Register339Fists()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_fists", "weapon_fists" );
	g_ItemRegistry.RegisterWeapon( "weapon_fists", "cyrax" );
}

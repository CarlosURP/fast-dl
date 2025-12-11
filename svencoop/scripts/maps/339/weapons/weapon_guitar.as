/* 
 * 339 Guitar – placeholder melee weapon
 * Modified from weapon_hlcrowbar.as (Sidewinder)
 */

enum guitar
{
	GUITAR_IDLE = 0,
	GUITAR_DEPLOY,
	GUITAR_SLASH1,
	GUITAR_SLASH2,
	GUITAR_SLASH3,
	GUITAR_BLOCK
};

class weapon_339guitar : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;

	TraceResult m_trHit;

	void Spawn()
	{
		self.Precache();

		// Use default crowbar world model as a temporary placeholder
		g_EntityFuncs.SetModel( self, self.GetW_Model( "models/w_crowbar.mdl" ) );

		self.m_iClip       = -1;
		self.m_flCustomDmg = ( self.pev.dmg > 0 ) ? self.pev.dmg : 20.0f;

		self.FallInit(); // get ready to fall down
	}

	void Precache()
	{
		self.PrecacheCustomModels();

		// View model: your custom guitar
		g_Game.PrecacheModel( "models/cyrax/wpn/v_guitar.mdl" );

		// Temporary player/world models – stock crowbar
		g_Game.PrecacheModel( "models/p_crowbar.mdl" );
		g_Game.PrecacheModel( "models/w_crowbar.mdl" );

		// Sounds
		g_SoundSystem.PrecacheSound( "cyrax/wpn/katana_slash1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/blunt_hitbod1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/blunt_hitbod2.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/blunt_hitbod3.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/blunt_hit2.wav" );

		g_Game.PrecacheGeneric( "sprites/cyrax/weapon_339guitar.txt" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 = -1;
		info.iMaxAmmo2 = -1;
		info.iMaxClip  = WEAPON_NOCLIP;
		info.iSlot     = 0;
		info.iPosition = 11;
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
		if( m_pPlayer is null )
			return false;

		return self.DefaultDeploy(
			self.GetV_Model( "models/cyrax/wpn/v_guitar.mdl" ),
			self.GetP_Model( "models/p_crowbar.mdl" ),
			GUITAR_DEPLOY,
			"crowbar"
		);
	}

	void Holster( int skiplocal /* = 0 */ )
	{
		self.m_fInReload = false; // cancel any reload in progress.

		if( m_pPlayer !is null )
		{
			m_pPlayer.m_flNextAttack = g_WeaponFuncs.WeaponTimeBase() + 0.5f;
			m_pPlayer.pev.viewmodel  = "";
		}

		SetThink( null );
	}

	void ItemPreFrame()  { BaseClass.ItemPreFrame(); }
	void ItemPostFrame() { BaseClass.ItemPostFrame(); }

	void PrimaryAttack()
	{
		if( m_pPlayer is null )
			return;

		if( !Swing( 1 ) )
		{
			SetThink( ThinkFunction( this.SwingAgain ) );
			self.pev.nextthink = g_Engine.time + 0.1f;
		}
	}

	// Not used yet, kept empty so you can add alt-attacks later
	void SecondaryAttack() {}
	void TertiaryAttack() {}

	void SwingAgain()
	{
		Swing( 0 );
	}

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
				{
					g_Utility.FindHullIntersection(
						vecSrc, tr, tr,
						VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX,
						m_pPlayer.edict()
					);
				}
				vecEnd = tr.vecEndPos;
			}
		}

		if( tr.flFraction >= 1.0f )
		{
			// Miss animation
			if( fFirst != 0 )
			{
				self.SendWeaponAnim( GUITAR_SLASH1 );

				self.m_flNextPrimaryAttack  =
				self.m_flNextSecondaryAttack =
				self.m_flNextTertiaryAttack = g_Engine.time + 0.6f;

				g_SoundSystem.EmitSoundDyn(
					m_pPlayer.edict(), CHAN_WEAPON,
					"cyrax/wpn/katana_slash1.wav",
					1, ATTN_NORM, 0, 94 + Math.RandomLong( 0, 0xF )
				);

				m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 
			}
		}
		else
		{
			// Hit
			fDidHit = true;

			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

			self.SendWeaponAnim( GUITAR_SLASH1 );
			m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 

			float flDamage = ( self.m_flCustomDmg > 0 ) ? self.m_flCustomDmg : 20.0f;

			g_WeaponFuncs.ClearMultiDamage();
			if( self.m_flNextPrimaryAttack + 1 < g_Engine.time )
				pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_CLUB | DMG_NEVERGIB );
			else
				pEntity.TraceAttack( m_pPlayer.pev, flDamage * 0.75f, g_Engine.v_forward, tr, DMG_CLUB | DMG_NEVERGIB );
			g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

			float flVol     = 1.0f;
			bool  fHitWorld = true;

			if( pEntity !is null )
			{
				self.m_flNextPrimaryAttack  =
				self.m_flNextSecondaryAttack =
				self.m_flNextTertiaryAttack = g_Engine.time + 0.6f;

				if( pEntity.Classify() != CLASS_NONE &&
				    pEntity.Classify() != CLASS_MACHINE &&
				    pEntity.BloodColor() != DONT_BLEED )
				{
					// Slight pull for players
					if( pEntity.IsPlayer() )
					{
						pEntity.pev.velocity = pEntity.pev.velocity +
							( self.pev.origin - pEntity.pev.origin ).Normalize() * 120;
					}

					switch( Math.RandomLong( 0, 3 ) )
					{
						case 0:
							g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON,
								"cyrax/wpn/blunt_hitbod1.wav", 1, ATTN_NORM ); break;
						case 1:
							g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON,
								"cyrax/wpn/blunt_hitbod2.wav", 1, ATTN_NORM ); break;
						case 2:
							g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON,
								"cyrax/wpn/blunt_hitbod3.wav", 1, ATTN_NORM ); break;
						case 3:
							g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON,
								"cyrax/wpn/blunt_hitbod1.wav", 1, ATTN_NORM ); break;
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

				self.m_flNextPrimaryAttack  =
				self.m_flNextSecondaryAttack =
				self.m_flNextTertiaryAttack = g_Engine.time + 0.6f;

				fvolbar = 1.0f;

				g_SoundSystem.EmitSoundDyn(
					m_pPlayer.edict(), CHAN_WEAPON,
					"cyrax/wpn/blunt_hit2.wav",
					fvolbar, ATTN_NORM, 0,
					98 + Math.RandomLong( 0, 3 )
				);
			}

			m_trHit = tr;
			m_pPlayer.m_iWeaponVolume = int( flVol * 512 ); 
		}

		return fDidHit;
	}

	void WeaponIdle()
	{
		if( self.m_flTimeWeaponIdle > g_Engine.time )
			return;

		self.SendWeaponAnim( GUITAR_IDLE );
		self.m_flTimeWeaponIdle = g_Engine.time + 1.0f;
	}
}

void Register339Guitar()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_339guitar", "weapon_339guitar" );
	g_ItemRegistry.RegisterWeapon( "weapon_339guitar", "cyrax" );
}

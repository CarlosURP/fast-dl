/* 
 * Short Katana
 * Modified version of weapon_hlcrowbar.as by Sidewinder
 * Original author: https://steamcommunity.com/id/tehsnek/
 */

const float KATANA_RANGE       = 90.0f;  // was 48 – longer reach so it hits big bosses easier
const float KATANA_BASE_DAMAGE = 150.0f;

enum katana_e
{
	KATANA_IDLE = 0,
	KATANA_DRAW,
	KATANA_HOLSTER,
	KATANA_ATTACK1HIT,
	KATANA_ATTACK1MISS,
	KATANA_ATTACK2MISS,
	KATANA_ATTACK2HIT,
	KATANA_ATTACK3MISS,
	KATANA_ATTACK3HIT
};

class weapon_katana_short : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;

	int m_iSwing = 0;
	TraceResult m_trHit;

	void Spawn()
	{
		self.Precache();
		g_EntityFuncs.SetModel( self, self.GetW_Model( "models/cyrax/wpn/w_shortkatana.mdl" ) );

		self.m_iClip       = -1;
		self.m_flCustomDmg = self.pev.dmg;

		// Get ready to fall to the ground if dropped
		self.FallInit();
	}

	void Precache()
	{
		self.PrecacheCustomModels();

		// View / world / player models
		g_Game.PrecacheModel( "models/cyrax/wpn/p_shortkatana.mdl" );
		g_Game.PrecacheModel( "models/cyrax/wpn/v_shortkatana.mdl" );
		g_Game.PrecacheModel( "models/cyrax/wpn/w_shortkatana.mdl" );

		// HUD icon + layout
		g_Game.PrecacheGeneric( "sprites/cyrax/weapon_katana_short.txt" );
		g_Game.PrecacheModel( "sprites/cyrax/640hud1_katana.spr" );
		g_Game.PrecacheModel( "sprites/cyrax/640hud4_katana.spr" );

		// Sounds
		g_SoundSystem.PrecacheSound( "cyrax/wpn/katana_deploy1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/katana_hit1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/katana_hit2.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/katana_hit3.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/katana_hit4.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/katana_hitwall1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/katana_hitwall2.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/katana_slash1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/katana_slash2.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/katana_stab.wav" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 = -1;
		info.iMaxAmmo2 = -1;
		info.iMaxClip  = WEAPON_NOCLIP;
		info.iSlot     = 0;
		info.iPosition = 16;
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
			m_pPlayer.edict(),
			CHAN_WEAPON,
			"cyrax/wpn/katana_deploy1.wav",
			1.0f,
			ATTN_NORM,
			0,
			94 + Math.RandomLong( 0, 0xF )
		);

		return self.DefaultDeploy(
			self.GetV_Model( "models/cyrax/wpn/v_shortkatana.mdl" ),
			self.GetP_Model( "models/cyrax/wpn/p_shortkatana.mdl" ),
			KATANA_DRAW,
			"crowbar"
		);
	}

	void Holster( int skiplocal /* = 0 */ )
	{
		// Cancel any reload in progress
		self.m_fInReload = false;

		m_pPlayer.m_flNextAttack = g_WeaponFuncs.WeaponTimeBase() + 0.5f;

		// Clear viewmodel
		m_pPlayer.pev.viewmodel = "";

		SetThink( null );
	}

	void ItemPreFrame()
	{
		BaseClass.ItemPreFrame();
	}

	void ItemPostFrame()
	{
		BaseClass.ItemPostFrame();
	}
	
	void PrimaryAttack()
	{
		if( !Swing( 1 ) )
		{
			SetThink( ThinkFunction( this.SwingAgain ) );
			self.pev.nextthink = g_Engine.time + 0.1f;
		}
	}

	// Called a bit after impact to place decals
	void Smack()
	{
		g_WeaponFuncs.DecalGunshot( m_trHit, BULLET_PLAYER_CROWBAR );
	}

	void SwingAgain()
	{
		Swing( 0 );
	}

	bool Swing( int fFirst )
	{
		bool fDidHit = false;
		TraceResult tr;

		Math.MakeVectors( m_pPlayer.pev.v_angle );

		Vector vecSrc = m_pPlayer.GetGunPosition();

		// Longer reach than crowbar – tuned for big bosses
		Vector vecEnd = vecSrc + g_Engine.v_forward * KATANA_RANGE;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if( tr.flFraction >= 1.0f )
		{
			g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr );

			if( tr.flFraction < 1.0f )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );

				if( pHit is null || pHit.IsBSPModel() )
					g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, m_pPlayer.edict() );

				vecEnd = tr.vecEndPos;
			}
		}

		if( tr.flFraction >= 1.0f )
		{
			// Miss
			if( fFirst != 0 )
			{
				switch( ( m_iSwing++ ) % 3 )
				{
					case 0: self.SendWeaponAnim( KATANA_ATTACK1MISS ); break;
					case 1: self.SendWeaponAnim( KATANA_ATTACK2MISS ); break;
					case 2: self.SendWeaponAnim( KATANA_ATTACK3MISS ); break;
				}

				self.m_flNextPrimaryAttack = g_Engine.time + 0.5f;

				// Play whiff / slash sound
				switch( Math.RandomLong( 0, 1 ) )
				{
					case 0:
						g_SoundSystem.EmitSoundDyn(
							m_pPlayer.edict(),
							CHAN_WEAPON,
							"cyrax/wpn/katana_slash1.wav",
							1.0f,
							ATTN_NORM,
							0,
							94 + Math.RandomLong( 0, 0xF )
						);
						break;

					case 1:
						g_SoundSystem.EmitSoundDyn(
							m_pPlayer.edict(),
							CHAN_WEAPON,
							"cyrax/wpn/katana_slash2.wav",
							1.0f,
							ATTN_NORM,
							0,
							94 + Math.RandomLong( 0, 0xF )
						);
						break;
				}

				// Player attack animation
				m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
			}
		}
		else
		{
			// Hit
			fDidHit = true;

			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

			switch( ( ( m_iSwing++ ) % 2 ) + 1 )
			{
				case 0: self.SendWeaponAnim( KATANA_ATTACK1HIT ); break;
				case 1: self.SendWeaponAnim( KATANA_ATTACK2HIT ); break;
				case 2: self.SendWeaponAnim( KATANA_ATTACK3HIT ); break;
			}

			// Player attack animation
			m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

			// Base damage (can be overridden by m_flCustomDmg)
			float flDamage = KATANA_BASE_DAMAGE;
			if( self.m_flCustomDmg > 0 )
				flDamage = self.m_flCustomDmg;

			g_WeaponFuncs.ClearMultiDamage();

			if( self.m_flNextPrimaryAttack + 1.0f < g_Engine.time )
			{
				// First swing does full damage
				pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_CLUB );
			}
			else
			{
				// Follow-up swing does reduced damage
				pEntity.TraceAttack( m_pPlayer.pev, flDamage * 0.75f, g_Engine.v_forward, tr, DMG_CLUB );
			}

			g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

			// Play hit sounds
			float flVol = 1.0f;
			bool fHitWorld = true;

			if( pEntity !is null )
			{
				self.m_flNextPrimaryAttack = g_Engine.time + 0.5f; // was 0.25

				if( pEntity.Classify() != CLASS_NONE &&
					pEntity.Classify() != CLASS_MACHINE &&
					pEntity.BloodColor() != DONT_BLEED )
				{
					// If we hit a player, pull them slightly toward the katana
					if( pEntity.IsPlayer() )
					{
						pEntity.pev.velocity = pEntity.pev.velocity +
							( self.pev.origin - pEntity.pev.origin ).Normalize() * 120;
					}

					// Flesh hit sounds
					switch( Math.RandomLong( 0, 3 ) )
					{
						case 0:
							g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/katana_hit1.wav", 1.0f, ATTN_NORM );
							break;
						case 1:
							g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/katana_hit2.wav", 1.0f, ATTN_NORM );
							break;
						case 2:
							g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/katana_hit3.wav", 1.0f, ATTN_NORM );
							break;
						case 3:
							g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/katana_hit4.wav", 1.0f, ATTN_NORM );
							break;
					}

					m_pPlayer.m_iWeaponVolume = 128;

					if( !pEntity.IsAlive() )
						return true;
					else
						flVol = 0.1f;

					fHitWorld = false;
				}
			}

			// World / texture hit sounds
			if( fHitWorld )
			{
				float fvolbar = g_SoundSystem.PlayHitSound(
					tr,
					vecSrc,
					vecSrc + ( vecEnd - vecSrc ) * 2,
					BULLET_PLAYER_CROWBAR
				);

				self.m_flNextPrimaryAttack = g_Engine.time + 0.5f; // was 0.25

				// Override volume here since PlayHitSound returns 0 in multiplayer
				fvolbar = 1.0f;

				// Katana vs wall impact
				switch( Math.RandomLong( 0, 1 ) )
				{
					case 0:
						g_SoundSystem.EmitSoundDyn(
							m_pPlayer.edict(),
							CHAN_WEAPON,
							"cyrax/wpn/katana_hitwall1.wav",
							fvolbar,
							ATTN_NORM,
							0,
							98 + Math.RandomLong( 0, 3 )
						);
						break;

					case 1:
						g_SoundSystem.EmitSoundDyn(
							m_pPlayer.edict(),
							CHAN_WEAPON,
							"cyrax/wpn/katana_hitwall2.wav",
							fvolbar,
							ATTN_NORM,
							0,
							98 + Math.RandomLong( 0, 3 )
						);
						break;
				}
			}

			// Store trace for delayed decal
			m_trHit = tr;
			SetThink( ThinkFunction( this.Smack ) );
			self.pev.nextthink = g_Engine.time + 0.2f;

			m_pPlayer.m_iWeaponVolume = int( flVol * 512.0f );
		}

		return fDidHit;
	}
}

void Register339Katana()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_katana_short", "weapon_katana_short" );
	g_ItemRegistry.RegisterWeapon( "weapon_katana_short", "cyrax" );
}

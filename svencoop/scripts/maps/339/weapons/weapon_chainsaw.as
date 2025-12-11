/* 
 * weapon_chainsaw.as
 * Modified and cleaned-up version of weapon_hlcrowbar.as by Sidewinder
 * Chainsaw:
 *  - Uses uranium as "fuel"
 *  - Higher range than crowbar
 *  - Fast continuous hits
 *  - Idle loop sound when equipped and fueled
 */

const float CHSAW_RANGE           = 56.0f;   // was 32, slightly longer reach
const float CHSAW_DAMAGE          = 15.0f;   // was 10, modest damage bump
const int   CHSAW_MAX_AMMO        = 1000;    // fuel cap
const float CHSAW_ATTACK_DELAY    = 0.04f;   // how fast the saw ticks
const float CHSAW_DEPLOY_TIME     = 0.8f;
const float CHSAW_IDLE_LOOP_DELAY = 1.9f;
const float CHSAW_IDLE_INTERVAL   = 0.1f;

enum chainsaw_e
{
	SAW_IDLE = 0,
	SAW_SHOOT,
	SAW_DEPLOY,
	SAW_HOLSTER
};

class weapon_chainsaw : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;
	private float m_flNextChainsawLoop;
	TraceResult m_trHit;

	void Spawn()
	{
		self.Precache();
		self.m_iDefaultAmmo = CHSAW_MAX_AMMO;
		g_EntityFuncs.SetModel( self, self.GetW_Model( "models/cyrax/wpn/w_chainsaw.mdl" ) );
		self.m_flCustomDmg = self.pev.dmg;
		self.m_iClip = WEAPON_NOCLIP;
		m_flNextChainsawLoop = 0.0f;
		self.FallInit(); // get ready to fall down
	}

	void Precache()
	{
		self.PrecacheCustomModels();

		g_Game.PrecacheModel( "models/cyrax/wpn/p_chainsaw.mdl" );
		g_Game.PrecacheModel( "models/cyrax/wpn/v_chainsaw.mdl" );
		g_Game.PrecacheModel( "models/cyrax/wpn/w_chainsaw.mdl" );

		g_SoundSystem.PrecacheSound( "cyrax/wpn/chainsaw_start.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/chainsaw_idle.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/chainsaw_run.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/chainsaw_hitbod1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/chainsaw_hitbod2.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/chainsaw_hitbod3.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/chainsaw_hit1.wav" );

		g_Game.PrecacheGeneric( "sprites/cyrax/weapon_chainsaw.txt" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1  = CHSAW_MAX_AMMO;
		info.iMaxAmmo2  = -1;
		info.iMaxClip   = WEAPON_NOCLIP;
		info.iSlot      = 0;
		info.iPosition  = 17;
		info.iFlags     = ITEM_FLAG_NOAUTOSWITCHEMPTY;
		info.iWeight    = 0;
		return true;
	}
	
	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( !BaseClass.AddToPlayer( pPlayer ) )
			return false;
			
		@m_pPlayer = pPlayer;

		// Set uranium fuel max
		pPlayer.SetMaxAmmo( "uranium", CHSAW_MAX_AMMO );

		return true;
	}

	float WeaponTimeBase()
	{
		return g_Engine.time;
	}

	void Reload()
	{
		// No reload; fuel is handled via ammo pickups
	}

	bool Deploy()
	{
		if( m_pPlayer is null )
			return false;

		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/chainsaw_start.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM );
		m_flNextChainsawLoop = g_Engine.time + CHSAW_DEPLOY_TIME;
		self.m_flTimeWeaponIdle = WeaponTimeBase() + CHSAW_DEPLOY_TIME;

		return self.DefaultDeploy(
			self.GetV_Model( "models/cyrax/wpn/v_chainsaw.mdl" ),
			self.GetP_Model( "models/cyrax/wpn/p_chainsaw.mdl" ),
			SAW_DEPLOY,
			"minigun"
		);
	}

	void Holster( int skiplocal = 0 )
	{
		self.m_fInReload = false; // cancel any reload in progress

		if( m_pPlayer !is null )
		{
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/chainsaw_idle.wav", 1.0f, ATTN_NORM, SND_STOP, PITCH_NORM );
			m_pPlayer.m_flNextAttack = g_WeaponFuncs.WeaponTimeBase() + 0.5f; 
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
		BaseClass.ItemPostFrame();
	}
	
	// --------- Helper: fuel handling ---------

	bool HasFuel() const
	{
		if( m_pPlayer is null )
			return false;
		return (m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) > 0);
	}

	void ConsumeFuel( int amount = 1 )
	{
		if( m_pPlayer is null )
			return;

		int ammo = m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType );
		ammo -= amount;
		if( ammo < 0 )
			ammo = 0;

		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, ammo );
	}

	// --------- Attack logic ---------

	void PrimaryAttack()
	{
		if( m_pPlayer is null )
		{
			self.m_flNextPrimaryAttack = g_Engine.time + CHSAW_ATTACK_DELAY;
			return;
		}

		if( !HasFuel() )
		{
			// No fuel – give feedback but do NOT swing
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/chainsaw_start.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM );
			self.m_flNextPrimaryAttack   = g_Engine.time + 0.5f;
			self.m_flNextSecondaryAttack = g_Engine.time + 0.5f;
			self.m_flNextTertiaryAttack  = g_Engine.time + 0.5f;
			return;
		}

		// Attempt a swing; if we MISS entirely, still burn a tiny bit of fuel
		if( !Swing( 1 ) )
		{
			ConsumeFuel( 1 );
			SetThink( ThinkFunction( this.SwingAgain ) );
			self.pev.nextthink = g_Engine.time;
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

	bool Swing( int fFirst )
	{
		bool fDidHit = false;

		if( m_pPlayer is null )
			return false;

		TraceResult tr;

		Math.MakeVectors( m_pPlayer.pev.v_angle );
		Vector vecSrc = m_pPlayer.GetGunPosition();
		Vector vecEnd = vecSrc + g_Engine.v_forward * CHSAW_RANGE;

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
			// Pure miss
			if( fFirst != 0 )
			{
				self.SendWeaponAnim( SAW_SHOOT );

				self.m_flNextPrimaryAttack   = g_Engine.time + CHSAW_ATTACK_DELAY;
				self.m_flNextSecondaryAttack = g_Engine.time + CHSAW_ATTACK_DELAY;
				self.m_flNextTertiaryAttack  = g_Engine.time + CHSAW_ATTACK_DELAY;
				m_flNextChainsawLoop         = g_Engine.time + CHSAW_DEPLOY_TIME;
				self.m_flTimeWeaponIdle      = WeaponTimeBase() + CHSAW_DEPLOY_TIME;

				GetSoundEntInstance().InsertSound( bits_SOUND_COMBAT, m_pPlayer.pev.origin, LOUD_GUN_VOLUME, 0.3f, m_pPlayer );

				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/chainsaw_run.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM );
				m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
			}
		}
		else
		{
			// Hit something
			fDidHit = true;
			
			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

			self.SendWeaponAnim( SAW_SHOOT );
			m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

			// Damage
			float flDamage = CHSAW_DAMAGE;
			if( self.m_flCustomDmg > 0 )
				flDamage = self.m_flCustomDmg;

			g_WeaponFuncs.ClearMultiDamage();
			if( pEntity !is null )
				pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_SLASH | DMG_NEVERGIB );  
			g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

			self.m_flNextPrimaryAttack   = g_Engine.time + CHSAW_ATTACK_DELAY;
			self.m_flNextSecondaryAttack = g_Engine.time + CHSAW_ATTACK_DELAY;
			self.m_flNextTertiaryAttack  = g_Engine.time + CHSAW_ATTACK_DELAY;

			m_flNextChainsawLoop    = g_Engine.time + CHSAW_DEPLOY_TIME;
			self.m_flTimeWeaponIdle = WeaponTimeBase() + CHSAW_DEPLOY_TIME;

			// Burn fuel for a valid contact
			ConsumeFuel( 1 );

			float flVol     = 1.0f;
			bool  fHitWorld = true;

			if( pEntity !is null )
			{
				GetSoundEntInstance().InsertSound( bits_SOUND_COMBAT, m_pPlayer.pev.origin, LOUD_GUN_VOLUME, 0.3f, m_pPlayer );

				if( pEntity.Classify() != CLASS_NONE && pEntity.Classify() != CLASS_MACHINE && pEntity.BloodColor() != DONT_BLEED )
				{
					// Slight pull on players
					if( pEntity.IsPlayer() )
					{
						pEntity.pev.velocity = pEntity.pev.velocity + ( self.pev.origin - pEntity.pev.origin ).Normalize() * 120.0f;
					}

					// Body hit sounds
					switch( Math.RandomLong( 0, 2 ) )
					{
						case 0:
							g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/chainsaw_run.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM );
							g_SoundSystem.EmitSoundDyn( pEntity.edict(), CHAN_BODY,   "cyrax/wpn/chainsaw_hitbod1.wav", 1.0f, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
							break;
						case 1:
							g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/chainsaw_run.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM );
							g_SoundSystem.EmitSoundDyn( pEntity.edict(), CHAN_BODY,   "cyrax/wpn/chainsaw_hitbod2.wav", 1.0f, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
							break;
						case 2:
							g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/chainsaw_run.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM );
							g_SoundSystem.EmitSoundDyn( pEntity.edict(), CHAN_BODY,   "cyrax/wpn/chainsaw_hitbod3.wav", 1.0f, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
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

			if( fHitWorld )
			{
				float fvolbar = g_SoundSystem.PlayHitSound(
					tr,
					vecSrc,
					vecSrc + ( vecEnd - vecSrc ) * 2,
					BULLET_PLAYER_CROWBAR
				);

				GetSoundEntInstance().InsertSound( bits_SOUND_COMBAT, m_pPlayer.pev.origin, LOUD_GUN_VOLUME, 0.3f, m_pPlayer );

				self.m_flNextPrimaryAttack   = g_Engine.time + CHSAW_ATTACK_DELAY;
				self.m_flNextSecondaryAttack = g_Engine.time + CHSAW_ATTACK_DELAY;
				self.m_flNextTertiaryAttack  = g_Engine.time + CHSAW_ATTACK_DELAY;
				m_flNextChainsawLoop         = g_Engine.time + CHSAW_DEPLOY_TIME;
				self.m_flTimeWeaponIdle      = WeaponTimeBase() + CHSAW_DEPLOY_TIME;

				// ensure we burned fuel on this attempt
				ConsumeFuel( 1 );
				
				// override volume
				fvolbar = 1.0f;

				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/chainsaw_run.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM );
				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_STATIC, "cyrax/wpn/chainsaw_hit1.wav",    1.0f, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 ) );
			}

			m_trHit = tr;
			SetThink( ThinkFunction( this.Smack ) );
			self.pev.nextthink = g_Engine.time;

			m_pPlayer.m_iWeaponVolume = int( flVol * 512.0f ); 
		}

		return fDidHit;
	}

	void WeaponIdle()
	{
		if( self.m_flTimeWeaponIdle > WeaponTimeBase() )
			return;

		if( m_pPlayer is null )
			return;

		self.m_flTimeWeaponIdle = WeaponTimeBase() + CHSAW_IDLE_INTERVAL;
		
		if( HasFuel() )
		{
			ChainsawLoop();
			self.SendWeaponAnim( SAW_IDLE );
		}
	}

	void ChainsawLoop()
	{
		if( m_pPlayer is null )
			return;

		if( !HasFuel() )
			return;

		if( m_flNextChainsawLoop < g_Engine.time )
		{
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/chainsaw_idle.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM );
			m_flNextChainsawLoop = g_Engine.time + CHSAW_IDLE_LOOP_DELAY;
		}
	}

}

void Register339Chainsaw()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_chainsaw", "weapon_chainsaw" );
	g_ItemRegistry.RegisterWeapon( "weapon_chainsaw", "cyrax", "uranium" );
}

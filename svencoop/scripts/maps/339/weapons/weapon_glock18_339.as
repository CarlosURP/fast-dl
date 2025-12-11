/***
*
*    Glock 18 (339 Cyrax Version)
*    Semi / Full Auto toggle, tuned for 16 dmg and snappy ROF.
*
****/

// Ammo / weapon constants
const int GLOCK_DEFAULT_GIVE = 17;
const int _9MM_MAX_CARRY     = 250;
const int GLOCK_MAX_CLIP     = 17;
const int GLOCK_WEIGHT       = 10;

// Custom tuned damage (NOT using HL skill cvars)
int GetTunedGlockDamage()
{
    // Change this if you ever want to buff/nerf it
    return 16;
}

enum Glock18Animation
{
	GLOCK18_IDLE = 0,
	GLOCK18_RELOAD,
	GLOCK18_DRAW,
	GLOCK18_SHOOT1,
	GLOCK18_SHOOT2,
	GLOCK18_SHOOTEMPTY
};

enum FireModes
{
	MODE_SEMI = 0,
	MODE_AUTO
};

class weapon_glock18_339 : ScriptBasePlayerWeaponEntity
{
	CBasePlayer@ m_pPlayer = null;

	int m_iShell;
	int m_iFireMode;
	
	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, "models/cyrax/wpn/w_glock18.mdl" );
		
		m_iFireMode = MODE_SEMI;
		self.m_iDefaultAmmo = GLOCK_DEFAULT_GIVE;

		self.FallInit();
	}

	void Precache()
	{
		self.PrecacheCustomModels();
		
		g_Game.PrecacheModel( "models/cyrax/wpn/p_glock18.mdl" );
		g_Game.PrecacheModel( "models/cyrax/wpn/v_glock18.mdl" );
		g_Game.PrecacheModel( "models/cyrax/wpn/w_glock18.mdl" );

		m_iShell = g_Game.PrecacheModel( "models/shell.mdl" );

		g_SoundSystem.PrecacheSound( "weapons/glock/clipin.wav" );
		g_SoundSystem.PrecacheSound( "weapons/glock/clipout.wav" );
		g_SoundSystem.PrecacheSound( "weapons/glock/glock-fire.wav" );
		g_SoundSystem.PrecacheSound( "weapons/glock/slideback.wav" );
		g_SoundSystem.PrecacheSound( "weapons/pistol-empty.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/draw.wav" );

		g_Game.PrecacheGeneric( "sprites/cyrax/weapon_glock18_339.txt" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1  = _9MM_MAX_CARRY;
		info.iMaxAmmo2  = -1;
		info.iMaxClip   = GLOCK_MAX_CLIP;
		info.iSlot      = 1;
		info.iPosition  = 4;
		info.iFlags     = 0;
		info.iWeight    = GLOCK_WEIGHT;

		return true;
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
		if( self.m_bPlayEmptySound )
		{
			self.m_bPlayEmptySound = false;
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, "weapons/pistol-empty.wav", 0.8f, ATTN_NORM, 0, PITCH_NORM );
		}
		
		return false;
	}

	bool Deploy()
	{
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/draw.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM );
		return self.DefaultDeploy(
			self.GetV_Model( "models/cyrax/wpn/v_glock18.mdl" ),
			self.GetP_Model( "models/cyrax/wpn/p_glock18.mdl" ),
			GLOCK18_DRAW,
			"onehanded"
		);
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
		// Semi: accurate + decent ROF
		// Auto: bit more spread + faster
		if( m_iFireMode == MODE_SEMI )
		{
			GlockFire( 0.01f, 0.08f, true );
		}
		else
		{
			GlockFire( 0.07f, 0.055f, false );
		}
	}

	void SecondaryAttack()
	{
		switch( m_iFireMode )
		{
			case MODE_SEMI:
			{
				m_iFireMode = MODE_AUTO;
				g_EngineFuncs.ClientPrintf( m_pPlayer, print_center, "Mode: Full auto\n" );
				break;
			}
			case MODE_AUTO:
			{
				m_iFireMode = MODE_SEMI;
				g_EngineFuncs.ClientPrintf( m_pPlayer, print_center, "Mode: Semi auto\n" );
				break;
			}
		}

		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, "weapons/pistol-empty.wav", 0.4f, ATTN_NORM, 0, 130 );

		const float flDelay = 0.45f;
		self.m_flTimeWeaponIdle      = g_Engine.time + flDelay;
		self.m_flNextSecondaryAttack = g_Engine.time + flDelay;
		self.m_flNextPrimaryAttack   = g_Engine.time + flDelay;
	}

	void TertiaryAttack()
	{
		// Reserved for future gimmicks if you want.
	}

	void GlockFire( float flSpread, float flCycleTime, const bool fUseAutoAim )
	{
		if( self.m_iClip <= 0 )
		{
			PlayEmptySound();
			self.m_flNextPrimaryAttack = g_Engine.time + 0.15f;
			return;
		}

		// Semi-auto: only fire on actual button press, not hold
		if( ( ( m_pPlayer.m_afButtonPressed & IN_ATTACK ) == 0 ) && ( m_iFireMode != MODE_AUTO ) )
			return;

		self.m_iClip--;

		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash  = NORMAL_GUN_FLASH;

		g_SoundSystem.EmitSoundDyn(
			m_pPlayer.edict(),
			CHAN_WEAPON,
			"weapons/glock/glock-fire.wav",
			1.0f, ATTN_NORM, 0, PITCH_NORM
		);

		switch( Math.RandomLong( 0, 1 ) )
		{
			case 0:
				self.SendWeaponAnim( ( self.m_iClip <= 0 ) ? GLOCK18_SHOOTEMPTY : GLOCK18_SHOOT1, 0, 0 );
				break;
			case 1:
				self.SendWeaponAnim( ( self.m_iClip <= 0 ) ? GLOCK18_SHOOTEMPTY : GLOCK18_SHOOT2, 0, 0 );
				break;
		}
		
		Vector vecSrc    = m_pPlayer.GetGunPosition();
		Vector vecAiming = fUseAutoAim
			? m_pPlayer.GetAutoaimVector( AUTOAIM_10DEGREES )
			: m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );

		// 🔥 SAME DAMAGE in semi + auto (16 from GetTunedGlockDamage)
		self.FireBullets(
			1,
			vecSrc,
			vecAiming,
			Vector( flSpread, flSpread, flSpread ),
			8192.0f,
			BULLET_PLAYER_9MM,
			2,
			GetTunedGlockDamage(),
			m_pPlayer.pev
		);

		// Recoil: small in semi, slightly stronger in full-auto
		if( m_iFireMode == MODE_AUTO )
		{
			// a tad more kick on full auto
			m_pPlayer.pev.punchangle.x += -2.1f;
		}
		else
		{
			m_pPlayer.pev.punchangle.x += -1.4f;
		}
		
		// Shell eject
		Vector vecOrigin = m_pPlayer.pev.origin
			+ m_pPlayer.pev.view_ofs
			+ g_Engine.v_up      * -12.0f
			+ g_Engine.v_forward *  25.0f
			+ g_Engine.v_right   *  12.0f;

		Vector vecVelocity = m_pPlayer.pev.velocity
			+ g_Engine.v_right   * Math.RandomFloat( 50.0f,  70.0f )
			+ g_Engine.v_up      * Math.RandomFloat(100.0f, 150.0f )
			+ g_Engine.v_forward * 25.0f;

		g_EntityFuncs.EjectBrass( vecOrigin, vecVelocity, m_pPlayer.pev.angles.y, m_iShell, TE_BOUNCE_SHELL );

		self.m_flNextPrimaryAttack   = g_Engine.time + flCycleTime;
		self.m_flNextSecondaryAttack = g_Engine.time + flCycleTime;

		if( self.m_iClip == 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
		{
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );
		}

		self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 10.0f, 15.0f );

		// Optional: only spawn decals on breakables
		TraceResult tr;
		float x, y;
		g_Utility.GetCircularGaussianSpread( x, y );

		Vector vecDir = vecAiming
			+ x * flSpread * g_Engine.v_right
			+ y * flSpread * g_Engine.v_up;

		Vector vecEnd = vecSrc + vecDir * 4096.0f;
		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if( tr.flFraction < 1.0f && tr.pHit !is null )
		{
			CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
			
			if( pHit !is null && pHit.IsBreakable() )
				g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_9MM );
		}
	}

	void Reload()
	{
		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			return;

		if( self.m_iClip == GLOCK_MAX_CLIP )
			return;

		self.DefaultReload( GLOCK_MAX_CLIP, GLOCK18_RELOAD, 1.5f, 0 );
		BaseClass.Reload();
	}

	void WeaponIdle()
	{
		self.ResetEmptySound();

		m_pPlayer.GetAutoaimVector( AUTOAIM_10DEGREES );

		if( self.m_flTimeWeaponIdle > g_Engine.time )
			return;

		self.m_flTimeWeaponIdle = g_Engine.time + 49.0f / 16.0f;

		self.SendWeaponAnim( GLOCK18_IDLE, 0, 0 );
	}
}

void Register339Glock18()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_glock18_339", "weapon_glock18_339" );
	g_ItemRegistry.RegisterWeapon( "weapon_glock18_339", "cyrax", "9mm", "", "ammo_9mmclip", "" );
}

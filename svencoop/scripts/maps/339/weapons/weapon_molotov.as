/* 
* Molotov weapon & fire AoE for map 339
* Tuned for ~100 total burn damage over time.
*/

const int MOLOTOV_DEFAULT_GIVE = 1;
const int MOLOTOV_MAX_CARRY   = 10;
const int MOLOTOV_MAX_CLIP    = WEAPON_NOCLIP;
const int MOLOTOV_WEIGHT      = 20;

// Damage types we want this weapon to apply
const int MOLLY_EXPLOSION_DMGTYPE = DMG_BURN | DMG_SLOWBURN | DMG_BLAST | DMG_NEVERGIB;
const int MOLLY_FIRE_DMGTYPE      = DMG_BURN | DMG_SLOWBURN | DMG_NEVERGIB;

// Sounds
const string MOLLY_FIRE_LOOP_SND  = "cyrax/weapons/molotov/molotov_fire.wav";
const string MOLLY_LIGHT_SND      = "cyrax/weapons/molotov/molotov_light.wav";

enum molotov_e
{
	MOLOTOV_IDLE = 0,
	MOLOTOV_PINPULL,
	MOLOTOV_THROW,
	MOLOTOV_DEPLOY
};

// ------------------------------------------------------
// Molotov bottle projectile
// ------------------------------------------------------
class MOLOTOV_BOTTLE : ScriptBaseMonsterEntity
{
	private bool    m_fRegisteredSound = false;
	private EHandle m_hOwner;
	private float   m_flDie;

	void Spawn()
	{
		Precache();

		self.pev.movetype = MOVETYPE_BOUNCE;
		self.pev.solid    = SOLID_BBOX;
		self.m_bloodColor = DONT_BLEED;

		if( !FNullEnt( self.pev.owner ) )
			m_hOwner = g_EntityFuncs.Instance( self.pev.owner );

		g_EntityFuncs.SetModel( self, "models/cyrax/wpn/w_molotov.mdl" );
		g_EntityFuncs.SetSize( self.pev, Vector( 0, 0, 0 ), Vector( 0, 0, 0 ) );

		// Explosion damage (instant)
		self.pev.dmg = 25.0f;

		m_fRegisteredSound = false;
		m_flDie = g_Engine.time + 10.0f;

		SetThink( ThinkFunction( EntThink ) );
		self.pev.nextthink = g_Engine.time + 0.01f;
	}

	void Precache()
	{
		g_Game.PrecacheModel( "models/cyrax/wpn/w_molotov.mdl" );
		g_SoundSystem.PrecacheSound( "debris/impact_glass.wav" );
		g_SoundSystem.PrecacheSound( "debris/glass2.wav" );
		
		g_Game.PrecacheGeneric( "sprites/cyrax/weapon_molotov.txt" );
		g_Game.PrecacheModel( "sprites/cyrax/640hud3_molotov.spr" );
		g_Game.PrecacheModel( "sprites/cyrax/640hud6_molotov.spr" );

	}

	void ExplodeTouch( CBaseEntity@ pOther )
	{
		BounceSound();
		Detonate();
	}

	void EntThink()
	{
		if ( g_Engine.time > m_flDie )
		{
			g_EntityFuncs.Remove( self );
			return;
		}

		self.StudioFrameAdvance();
		self.pev.angles = Math.VecToAngles( self.pev.velocity );
		self.pev.solid  = SOLID_BBOX;
		self.pev.nextthink = g_Engine.time + 0.1f;
	}

	void Detonate()
	{
		int iContents = g_EngineFuncs.PointContents( self.GetOrigin() );
		TraceResult tr;
		Vector vecSpot = self.pev.origin + Vector( 0, 0, 8 );

		g_Utility.TraceLine( vecSpot, vecSpot + Vector( 0, 0, -40 ), ignore_monsters, self.edict(), tr );

		if( iContents != CONTENTS_WATER )
		{
			int sparkCount = Math.RandomLong( 1, 3 );
			for( int i = 0; i < sparkCount; i++ )
				g_EntityFuncs.Create( "spark_shower", self.pev.origin, tr.vecPlaneNormal, false );
		}

		CreateMollyBurn();

		GetSoundEntInstance().InsertSound( bits_SOUND_COMBAT, self.pev.origin, NORMAL_GUN_VOLUME, 0.3, self );
		g_SoundSystem.EmitSoundDyn(
			self.edict(), CHAN_ITEM,
			"debris/glass2.wav",
			1.0f, ATTN_NORM, 0, 120
		); 

		// IMPORTANT: include DMG_BLAST so "Explosives only" func_breakable reacts
		g_WeaponFuncs.RadiusDamage(
			tr.vecEndPos,
			self.pev,                // inflictor
			self.pev.owner.vars,     // attacker
			self.pev.dmg,            // 25 dmg
			self.pev.dmg * 2.0f,     // radius 50 units
			CLASS_NONE,
			MOLLY_EXPLOSION_DMGTYPE  // includes DMG_BLAST
		);

		g_EntityFuncs.Remove( self );
	}

	void CreateMollyBurn()
	{
		CBaseEntity@ molly_burnpatch = g_EntityFuncs.Create(
			"molotov_aoe",
			self.pev.origin,
			self.pev.angles,
			false,
			self.edict()
		);

		if ( molly_burnpatch !is null )
		{
			molly_burnpatch.pev.angles.z = 0;
			molly_burnpatch.pev.angles.x = 0;
		}
	}

	void BounceSound()
	{
		g_SoundSystem.EmitSoundDyn(
			self.edict(), CHAN_VOICE,
			"debris/impact_glass.wav",
			1.0f, ATTN_NORM, 0, 120
		);
	}

	void cSetTouch()
	{
		SetTouch( TouchFunction( ExplodeTouch ) );
	}

	void cSetThink()
	{
		SetThink( ThinkFunction( EntThink ) );
	}

	void Remove()
	{
		SetThink( null );
		self.pev.effects |= EF_NODRAW;
		g_EntityFuncs.Remove( self );
	}
}

// ------------------------------------------------------
// Molotov fire AoE (lingering flames)
// ------------------------------------------------------
class molotov_aoe : ScriptBaseMonsterEntity
{
	private float m_flNextIdleSound;
	private float m_flNextBurnSprite;
	private float m_flDie;
	private EHandle m_hOwner;
	int m_iMolotovAoESprite;

	void Spawn()
	{
		Precache();

		// You can swap to an invisible model if desired
		g_EntityFuncs.SetModel( self, "models/cyrax/wpn/w_molotov.mdl" );
		g_EntityFuncs.SetOrigin( self, self.pev.origin );
		g_EntityFuncs.SetSize( self.pev, Vector( -16, -16, 0 ), Vector( 16, 16, 72 ) );

		self.pev.solid    = SOLID_NOT;
		self.pev.movetype = MOVETYPE_STEP;
		self.m_bloodColor = DONT_BLEED;
		self.m_MonsterState = MONSTERSTATE_NONE;

		self.pev.flags     |= FL_NOTARGET;
		self.pev.takedamage = DAMAGE_NO;
		self.pev.health     = 0.5f; // future: can be used for extinguish logic
		m_flDie             = g_Engine.time + 10.0f; // 10s lifetime
		m_flNextIdleSound   = 0.0f;
		m_flNextBurnSprite  = 0.0f;

		g_EntityFuncs.DispatchKeyValue( self.edict(), "displayname", "Molotov AoE" );

		self.m_fCanFearCreatures = false; 
		self.m_afCapability      = bits_CAP_HEAR;
		self.pev.view_ofs        = Vector( 0, 0, 50 );
		self.m_flFieldOfView     = 0.0f;

		self.MonsterInit();

		SetThink( ThinkFunction( MonsterThink ) );
		self.pev.nextthink = g_Engine.time + 0.1f;
	}

	void Precache()
	{
		m_iMolotovAoESprite = g_Game.PrecacheModel( "sprites/cyrax/flame2.spr" );
		g_Game.PrecacheModel( "models/cyrax/wpn/w_molotov.mdl" );

		// Looping fire sound
		g_SoundSystem.PrecacheSound( MOLLY_FIRE_LOOP_SND );

		// Ignite / light sound at pin pull (new path requested)
		g_SoundSystem.PrecacheSound( MOLLY_LIGHT_SND );
	}

	int Classify()
	{
		return CLASS_PLAYER_ALLY;
	}

	bool CheckRangeAttack1( float flDot, float flDist ) { return false; }
	bool CheckRangeAttack2( float flDot, float flDist ) { return false; }
	bool CheckMeleeAttack1( float flDot, float flDist ) { return false; }
	bool CanCheckAttacks()                              { return false; }

	void SetYawSpeed()
	{
		self.pev.yaw_speed = 180;
	}

	void MonsterThink()
	{
		BaseClass.Think();

		// Visual sprites + fire loop
		if( m_flNextBurnSprite < g_Engine.time )
		{
			// fire loop sound (loop channel)
			g_SoundSystem.EmitSoundDyn(
				self.edict(), CHAN_STATIC,
				MOLLY_FIRE_LOOP_SND,
				VOL_NORM, ATTN_NORM, 0, 100
			);

			Vector origin  = self.pev.origin + Vector( 0, 0, 120.0 );
			Vector origin2 = self.pev.origin + Vector( 30, 0,  80.0 );
			Vector origin3 = self.pev.origin + Vector( -30, 0, 80.0 );

			NetworkMessage message( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, origin );
				message.WriteByte( TE_SPRITE );
				message.WriteCoord( origin.x );
				message.WriteCoord( origin.y );
				message.WriteCoord( origin.z );
				message.WriteShort( m_iMolotovAoESprite );
				message.WriteByte( 14 );
				message.WriteByte( 128 );
			message.End();

			NetworkMessage message2( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, origin2 );
				message2.WriteByte( TE_SPRITE );
				message2.WriteCoord( origin2.x );
				message2.WriteCoord( origin2.y );
				message2.WriteCoord( origin2.z );
				message2.WriteShort( m_iMolotovAoESprite );
				message2.WriteByte( 12 );
				message2.WriteByte( 128 );
			message2.End();

			NetworkMessage message3( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, origin3 );
				message3.WriteByte( TE_SPRITE );
				message3.WriteCoord( origin3.x );
				message3.WriteCoord( origin3.y );
				message3.WriteCoord( origin3.z );
				message3.WriteShort( m_iMolotovAoESprite );
				message3.WriteByte( 12 );
				message3.WriteByte( 128 );
			message3.End();

			m_flNextBurnSprite = g_Engine.time + 0.7225f;
		}

		// Damage entities standing in the fire
		CBaseEntity@ pEntity = null;
		while( ( @pEntity = g_EntityFuncs.FindEntityInSphere( pEntity, self.pev.origin, 120, "*", "classname" ) ) !is null )
		{
			if( pEntity.pev.takedamage != DAMAGE_NO )
			{
				// ~1 dmg per 0.1s tick → ~10 DPS → ~100 total over 10s
				pEntity.TakeDamage(
					self.pev,
					self.pev, // attacker; can later swap to owner if needed
					1.0f,
					MOLLY_FIRE_DMGTYPE
				);
			}
		}

		// Lifetime check
		if( m_flDie < g_Engine.time )
		{
			g_EntityFuncs.Remove( self );
			return;
		}

		// Ensure stable tick rate for predictable DPS (~0.1s)
		self.pev.nextthink = g_Engine.time + 0.1f;
	}

	void RunAI()
	{
		IdleSound();
		BaseClass.RunAI();
	}

	void IdleSound()
	{
		if( m_flNextIdleSound < g_Engine.time )
		{
			g_SoundSystem.EmitSoundDyn(
				self.edict(), CHAN_VOICE,
				MOLLY_FIRE_LOOP_SND,
				VOL_NORM, ATTN_NORM, 0, 100
			);
			m_flNextIdleSound = g_Engine.time + 1.0f;
		}
	}

	void DeathSound()  {}
	void PainSound()   {}
	void AlertSound()  {}

	void FollowerUse( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
	}
}

// ------------------------------------------------------
// Helper to spawn the thrown bottle
// ------------------------------------------------------
MOLOTOV_BOTTLE@ ThrowTimed( entvars_t@ pevOwner, Vector& in vecStart, Vector& in vecVelocity, float time )
{
	CBaseEntity@ preEnt = g_EntityFuncs.CreateEntity( "molotov_bottle", null, false );
	MOLOTOV_BOTTLE@ pGrenade = cast<MOLOTOV_BOTTLE@>( CastToScriptClass( preEnt ) );
	
	if ( pGrenade is null )
		return null;

	pGrenade.Spawn();

	pGrenade.pev.origin   = vecStart;
	pGrenade.pev.velocity = vecVelocity;
	g_EngineFuncs.VecToAngles( pGrenade.pev.velocity, pGrenade.pev.angles );

	CBaseEntity@ pOwner = g_EntityFuncs.Instance( pevOwner );
	if ( pOwner !is null )
	{
		@pGrenade.pev.owner = pOwner.edict();
	}

	pGrenade.cSetTouch(); // Bounce then explode
	pGrenade.cSetThink();
	pGrenade.pev.nextthink = g_Engine.time + 0.1f;

	pGrenade.pev.dmg = 25.0f;

	return pGrenade;
}

// ------------------------------------------------------
// Player weapon
// ------------------------------------------------------
class weapon_molotov : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;
	
	float m_flStartThrow;
	float m_flReleaseThrow;
	
	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, "models/cyrax/wpn/w_molotov.mdl" );
		
		self.m_iDefaultAmmo = MOLOTOV_DEFAULT_GIVE;
		self.FallInit(); // get ready to fall down.
	}
	
	void Precache()
	{
		g_Game.PrecacheModel( "models/cyrax/wpn/p_molotov.mdl" );
		g_Game.PrecacheModel( "models/cyrax/wpn/v_molotov.mdl" );
		g_Game.PrecacheModel( "models/cyrax/wpn/w_molotov.mdl" );
		
		g_Game.PrecacheOther( "molotov_bottle" );
		g_Game.PrecacheOther( "molotov_aoe" );

		// Sounds
		g_SoundSystem.PrecacheSound( MOLLY_LIGHT_SND );
		g_SoundSystem.PrecacheSound( MOLLY_FIRE_LOOP_SND );
		
		g_Game.PrecacheGeneric( "sprites/hl_weapons/weapon_hlhandgrenade.txt" );
	}
	
	float WeaponTimeBase()
	{
		return g_Engine.time;
	}
	
	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1  = MOLOTOV_MAX_CARRY;
		info.iAmmo1Drop = 1;
		info.iMaxAmmo2  = -1;
		info.iMaxClip   = MOLOTOV_MAX_CLIP;
		info.iSlot      = 4;
		info.iPosition  = 8;
		info.iFlags     = ITEM_FLAG_LIMITINWORLD | ITEM_FLAG_EXHAUSTIBLE;
		info.iWeight    = MOLOTOV_WEIGHT;
		
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
		m_flReleaseThrow = -1;
		return self.DefaultDeploy(
			self.GetV_Model( "models/cyrax/wpn/v_molotov.mdl" ),
			self.GetP_Model( "models/cyrax/wpn/p_molotov.mdl" ),
			MOLOTOV_DEPLOY,
			"crowbar" );
	}

	void Holster( int skiplocal )
	{
		m_pPlayer.m_flNextAttack = WeaponTimeBase() + 0.5;

		m_flStartThrow   = 0;
		m_flReleaseThrow = -1;
	}

	void ItemPreFrame()  { BaseClass.ItemPreFrame(); }
	void ItemPostFrame() { BaseClass.ItemPostFrame(); }
	
	void InactiveItemPostFrame()
	{
		if ( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) == 0 )
		{
			self.DestroyItem();
			self.pev.nextthink = g_Engine.time + 0.1;
		}
	}
	
	void PrimaryAttack()
	{
		if ( m_flStartThrow == 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) > 0 )
		{
			m_flStartThrow   = g_Engine.time;
			m_flReleaseThrow = 0;
			
			self.SendWeaponAnim( MOLOTOV_PINPULL );
			self.m_flTimeWeaponIdle = WeaponTimeBase() + 0.5;

			// Ignite / light sound when pulling pin
			g_SoundSystem.EmitSoundDyn(
				m_pPlayer.edict(), CHAN_WEAPON,
				MOLLY_LIGHT_SND,
				VOL_NORM, ATTN_NORM, 0, PITCH_NORM
			);
		}
	}

	void SecondaryAttack() {}
	void Reload()          {}
	
	void WeaponIdle()
	{
		if ( m_flReleaseThrow == 0 && m_flStartThrow > 0 )
			m_flReleaseThrow = g_Engine.time;
		
		if ( self.m_flTimeWeaponIdle > WeaponTimeBase() )
			return;
		
		if ( m_flStartThrow > 0 )
		{
			Vector angThrow = m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle;
			
			if ( angThrow.x < 0 )
				angThrow.x = -10 + angThrow.x * ( ( 90 - 10 ) / 90.0 );
			else
				angThrow.x = -10 + angThrow.x * ( ( 90 + 10 ) / 90.0 );
			
			float flVel = ( 90 - angThrow.x ) * 4;
			if ( flVel > 500 )
				flVel = 500;
			
			g_EngineFuncs.MakeVectors( angThrow );

			Vector vecSrc   = m_pPlayer.pev.origin + m_pPlayer.pev.view_ofs + g_Engine.v_forward * 16;
			Vector vecThrow = g_Engine.v_forward * flVel + m_pPlayer.pev.velocity;
			
			MOLOTOV_BOTTLE@ pGrenade = ThrowTimed( m_pPlayer.pev, vecSrc, vecThrow, 999.0 );
			
			self.SendWeaponAnim( MOLOTOV_THROW );
			m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
			
			m_flReleaseThrow = 0;
			m_flStartThrow   = 0;
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.5;
			self.m_flTimeWeaponIdle    = WeaponTimeBase() + 0.5;

			m_pPlayer.m_rgAmmo(
				self.m_iPrimaryAmmoType,
				m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - 1 );
			
			if ( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) == 0 )
			{
				self.m_flTimeWeaponIdle     =
				self.m_flNextSecondaryAttack =
				self.m_flNextPrimaryAttack   = WeaponTimeBase() + 0.5;
			}
			return;
		}
		else if ( m_flReleaseThrow > 0 )
		{
			m_flStartThrow = 0;
			
			if ( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) > 0 )
			{
				self.SendWeaponAnim( MOLOTOV_DEPLOY );
			}
			else
			{
				self.RetireWeapon();
				return;
			}
			
			self.m_flTimeWeaponIdle = WeaponTimeBase() +
				g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 10, 15 );
			m_flReleaseThrow = -1;
			return;
		}
		
		if ( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) > 0 )
		{
			int   iAnim;
			float flRand = g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 0, 1 );
			if ( flRand <= 0.75f )
			{
				iAnim = MOLOTOV_IDLE;
				self.m_flTimeWeaponIdle = WeaponTimeBase() +
					g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 10, 15 );
			}
			else
			{
				iAnim = MOLOTOV_IDLE;
				self.m_flTimeWeaponIdle = WeaponTimeBase() + 75.0f / 30.0f;
			}
			
			self.SendWeaponAnim( iAnim );
		}
	}

	bool CanHaveDuplicates()
	{
		return true;
	}
}

void Register339Molotov()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "molotov_aoe",    "molotov_aoe" );
	g_CustomEntityFuncs.RegisterCustomEntity( "MOLOTOV_BOTTLE", "molotov_bottle" );
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_molotov", "weapon_molotov" );
	g_ItemRegistry.RegisterWeapon( "weapon_molotov", "cyrax", "molotovs" );
	g_Game.PrecacheOther( "molotov_aoe" );
	g_Game.PrecacheOther( "molotov_bottle" );
}

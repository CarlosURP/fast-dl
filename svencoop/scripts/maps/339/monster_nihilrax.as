// monster_nihilrax.as  (scripts/maps/339/monster_nihilrax.as)
//
// Nihilrax – floating belly beam boss
//  * Larger + lowered hitbox for melee
//  * Belly "bounce" push so players can't stand inside him
//  * Melee-assist: if player is very close and swinging, we fake a hit
//  * Only player(-owned) damage can hurt him (immune to monsters)
//  * Standing deep in his belly deals damage over time

const string NIHILRAX_MODEL        = "models/cyrax/nihilrax.mdl";

// Sounds
const string NIHILRAX_IDLE         = "cyrax/monsters/sackrax_sing01.wav";
const string NIHILRAX_ATTACK_MAIN  = "cyrax/raxx/rax_howl1.wav";           // original howl
const string NIHILRAX_ATTACK_1     = "cyrax/monsters/rax_attack01.wav";    // same set as human_cyrax
const string NIHILRAX_ATTACK_2     = "cyrax/monsters/rax_attack02.wav";    // same set as human_cyrax
const string NIHILRAX_DEATH        = "cyrax/nih_die.wav";

// Use default HL impact sounds for now (you can swap these to custom later)
const string NIHILRAX_IMPACT_MELEE = "weapons/cbar_hitbod1.wav";
const string NIHILRAX_IMPACT_BEAM  = "weapons/cbar_hitbod2.wav";

// Barks every 10–15s
const string NIHILRAX_BARK_1       = "cyrax/raxx/rax_sonofabitch.wav";
const string NIHILRAX_BARK_2       = "cyrax/raxx/rax_jackass.wav";
const float  NIHILRAX_BARK_MIN     = 10.0f;
const float  NIHILRAX_BARK_MAX     = 15.0f;

// FX assets
const string NIHILRAX_GIBS_HUMAN   = "models/hgibs.mdl";
const string NIHILRAX_GIBS_ALIEN   = "models/agibs.mdl";
const string NIHILRAX_DEATH_SPR    = "sprites/cyrax/bloodspray.spr";
const string NIHILRAX_BEAM_SPR     = "sprites/laserbeam.spr";

// How long the death anim + fade lasts
const float NIHILRAX_DEATH_DURATION   = 25.0f;

// Movement
const float NIHILRAX_DRIFT_SPEED      = 138.0f;  // 15% faster than original 120

// Attack tuning
const float NIHILRAX_INSTANT_DMG      = 15.0f;
const float NIHILRAX_CHARGED_DMG      = 35.0f;
const float NIHILRAX_MELEE_DMG        = 25.0f;

// Distance for his own melee
const float NIHILRAX_MELEE_RANGE      = 96.0f;
const float NIHILRAX_INSTANT_COOLDOWN = 2.5f;
const float NIHILRAX_CHARGED_COOLDOWN = 3.5f;
const float NIHILRAX_MELEE_COOLDOWN   = 1.8f;
const float NIHILRAX_CHARGE_TIME      = 0.8f;

// Extra melee assist tuning – helps player melee register
const float NIHILRAX_MELEE_ASSIST_RADIUS = 120.0f;   // close bubble around belly
const float NIHILRAX_MELEE_ASSIST_DMG    = 6.0f;     // small bonus hit

// Belly push tuning
const float NIHILRAX_PUSH_RADIUS        = 128.0f;    // OUTSIDE visible belly
const float NIHILRAX_PUSH_Z_MIN         = -160.0f;
const float NIHILRAX_PUSH_Z_MAX         =  160.0f;

// If you REALLY get inside the gut
// This is applied once per think (0.1s), so 8 dmg → ~80 DPS.
const float NIHILRAX_BELLY_INNER_RADIUS = 64.0f;
const float NIHILRAX_BELLY_DMG          = 8.0f;      // per 0.1s inside

// Attack type enum
enum NihilraxAttackType
{
	NIHILRAX_ATK_NONE = 0,
	NIHILRAX_ATK_BEAM_INSTANT,
	NIHILRAX_ATK_BEAM_CHARGED,
	NIHILRAX_ATK_MELEE
};

class monster_nihilrax : ScriptBaseMonsterEntity
{
	// Core state
	private float m_flNextAttack   = 0.0f;
	private float m_flHoverPhase   = 0.0f;
	private float m_flBaseZ        = 0.0f;
	private float m_flDeathEndTime = 0.0f; // when to fully remove the monster

	// Attack state
	NihilraxAttackType m_iPlannedAttack = NIHILRAX_ATK_NONE;
	bool   m_bCharging       = false;
	float  m_flChargeEndTime = 0.0f;
	EHandle m_hChargeTarget;

	// Idle bark timing
	float m_flNextBarkTime   = 0.0f;

	// Cached sequences
	int m_iIdleSeq       = -1;
	int m_iFlySeq        = -1;
	int m_iAttack1Seq    = -1;
	int m_iMeleeSeq      = -1;
	int m_iDeathSeq      = -1;

	// --- Unstuck helper state ---
	Vector m_vecLastPos;
	float  m_flNextStuckCheck = 0.0f;

	void Spawn()
	{
		Precache();

		g_EntityFuncs.SetModel( self, NIHILRAX_MODEL );

		// BIG, LOWERED HULL:
		g_EntityFuncs.SetSize(
			self.pev,
			Vector( -112, -112, -140 ),   // min
			Vector(  112,  112,  160 )    // max
		);

		// Slight visual scale tweak is okay, hull stays as above
		self.pev.scale      = 0.9f;

		self.pev.movetype   = MOVETYPE_FLY;
		self.pev.solid      = SOLID_SLIDEBOX;
		self.pev.flags     |= FL_MONSTER;
		self.pev.takedamage = DAMAGE_YES; // needed so TraceAttack/TakeDamage are called

		self.m_bloodColor   = BLOOD_COLOR_RED;

		// Standard engine health (we filter who can damage in TakeDamage)
		self.pev.health     = 3000.0f;
		self.pev.max_health = self.pev.health;

		self.m_afCapability = bits_CAP_RANGE_ATTACK1;
		self.SetClassification( CLASS_ALIEN_MILITARY );

		// Cache sequences from QC (NO *_open anims – keeps head closed)
		m_iIdleSeq     = self.LookupSequence( "idle1" );
		if ( m_iIdleSeq < 0 )
			m_iIdleSeq = self.LookupSequence( "float" ); // fallback

		m_iFlySeq      = self.LookupSequence( "fly" );
		if ( m_iFlySeq < 0 )
			m_iFlySeq  = self.LookupSequence( "walk" );

		m_iAttack1Seq  = self.LookupSequence( "attack1" );
		if ( m_iAttack1Seq < 0 )
			m_iAttack1Seq = self.LookupSequence( "attack1_custom" );

		m_iMeleeSeq    = self.LookupSequence( "throw" );
		if ( m_iMeleeSeq < 0 )
			m_iMeleeSeq = self.LookupSequence( "attack1_custom" );

		m_iDeathSeq    = self.LookupSequence( "death" );

		// Start idle
		if ( m_iIdleSeq != -1 )
		{
			self.pev.sequence = m_iIdleSeq;
			self.pev.frame    = 0;
			self.ResetSequenceInfo();
		}

		self.MonsterInit();

		m_flBaseZ        = self.pev.origin.z;
		m_flNextAttack   = g_Engine.time + 2.0f;
		m_flHoverPhase   = Math.RandomFloat( -10.0f, 10.0f );
		m_flNextBarkTime = g_Engine.time + Math.RandomFloat( NIHILRAX_BARK_MIN, NIHILRAX_BARK_MAX );

		// init unstuck tracking
		m_vecLastPos        = self.pev.origin;
		m_flNextStuckCheck  = g_Engine.time + 1.0f;

		SetThink( ThinkFunction( this.NihlThink ) );
		self.pev.nextthink = g_Engine.time + 0.1f;
	}

	void Precache()
	{
		g_Game.PrecacheModel( NIHILRAX_MODEL );
		g_Game.PrecacheModel( NIHILRAX_BEAM_SPR );

		// FX stuff
		g_Game.PrecacheModel( NIHILRAX_GIBS_HUMAN );
		g_Game.PrecacheModel( NIHILRAX_GIBS_ALIEN );
		g_Game.PrecacheModel( NIHILRAX_DEATH_SPR );

		g_SoundSystem.PrecacheSound( NIHILRAX_IDLE );
		g_SoundSystem.PrecacheSound( NIHILRAX_ATTACK_MAIN );
		g_SoundSystem.PrecacheSound( NIHILRAX_ATTACK_1 );
		g_SoundSystem.PrecacheSound( NIHILRAX_ATTACK_2 );
		g_SoundSystem.PrecacheSound( NIHILRAX_DEATH );

		g_SoundSystem.PrecacheSound( NIHILRAX_BARK_1 );
		g_SoundSystem.PrecacheSound( NIHILRAX_BARK_2 );

		// Impact sounds
		g_SoundSystem.PrecacheSound( NIHILRAX_IMPACT_MELEE );
		g_SoundSystem.PrecacheSound( NIHILRAX_IMPACT_BEAM );
	}

	// -----------------------------------------------------
	// Damage helpers: what counts as a player(-owned) hit?
	// -----------------------------------------------------
	bool IsFromPlayerOrPlayerOwned( entvars_t@ pevSrc )
	{
		if ( pevSrc is null )
			return false;

		CBaseEntity@ pEnt = g_EntityFuncs.Instance( pevSrc );
		if ( pEnt is null )
			return false;

		// Direct player entity
		CBasePlayer@ pPlr = cast<CBasePlayer@>( pEnt );
		if ( pPlr !is null )
			return true;

		// Check owner chain for projectiles
		if ( pEnt.pev.owner !is null )
		{
			CBaseEntity@ pOwner = g_EntityFuncs.Instance( pEnt.pev.owner );
			if ( pOwner !is null )
			{
				CBasePlayer@ pOwnerPlr = cast<CBasePlayer@>( pOwner );
				if ( pOwnerPlr !is null )
					return true;
			}
		}

		return false;
	}

	// -----------------------------------------------------
	// TraceAttack – only let player(-owned) hits build damage
	// -----------------------------------------------------
	void TraceAttack( entvars_t@ pevAttacker, float flDamage, Vector vecDir,
	                  TraceResult &in ptr, int bitsDamageType )
	{
		if ( IsFromPlayerOrPlayerOwned( pevAttacker ) )
		{
			// Normal damage + decals for player hits
			BaseClass.TraceAttack( pevAttacker, flDamage, vecDir, ptr, bitsDamageType );
		}
		else
		{
			// Non-player hits: optional visuals only (0 damage into MultiDamage)
			BaseClass.TraceAttack( pevAttacker, 0.0f, vecDir, ptr, bitsDamageType );
		}
	}

	// -----------------------------------------------------
	// TakeDamage – filter out non-player damage
	// -----------------------------------------------------
	float TakeDamage( entvars_t@ pevInflictor, entvars_t@ pevAttacker,
	                  float flDamage, int bitsDamageType )
	{
		// Only let player or player-owned sources do real damage.
		if ( !IsFromPlayerOrPlayerOwned( pevAttacker ) &&
		     !IsFromPlayerOrPlayerOwned( pevInflictor ) )
		{
			return 0.0f;
		}

		return BaseClass.TakeDamage( pevInflictor, pevAttacker, flDamage, bitsDamageType );
	}

	// =====================================================
	// Small helpers for animations
	// =====================================================
	void SetFlyAnim()
	{
		if ( m_iFlySeq == -1 )
			return;

		if ( self.pev.sequence != m_iFlySeq )
		{
			self.pev.sequence = m_iFlySeq;
			self.pev.frame    = 0;
			self.ResetSequenceInfo();
		}
	}

	void SetIdleAnim()
	{
		if ( m_iIdleSeq == -1 )
			return;

		if ( self.pev.sequence != m_iIdleSeq )
		{
			self.pev.sequence = m_iIdleSeq;
			self.pev.frame    = 0;
			self.ResetSequenceInfo();
		}
	}

	void SetInstantAttackAnim()
	{
		if ( m_iAttack1Seq == -1 )
			return;

		self.pev.sequence = m_iAttack1Seq;
		self.pev.frame    = 0;
		self.ResetSequenceInfo();
	}

	// We reuse the same closed-head attack anim for charged shots
	void SetChargedAttackAnim()
	{
		SetInstantAttackAnim();
	}

	void SetMeleeAnim()
	{
		if ( m_iMeleeSeq == -1 )
			return;

		self.pev.sequence = m_iMeleeSeq;
		self.pev.frame    = 0;
		self.ResetSequenceInfo();
	}

	// =====================================================
	// Helper: play one of the three attack sounds (START sound)
	// =====================================================
	void PlayAttackSound()
	{
		int roll = Math.RandomLong( 0, 2 );
		string snd;

		if ( roll == 0 )
			snd = NIHILRAX_ATTACK_1;
		else if ( roll == 1 )
			snd = NIHILRAX_ATTACK_2;
		else
			snd = NIHILRAX_ATTACK_MAIN;

		g_SoundSystem.EmitSoundDyn(
			self.edict(), CHAN_WEAPON,
			snd, 1.0f, ATTN_NORM, 0, PITCH_NORM
		);
	}

	// Periodic idle barks
	void MaybeDoIdleBark()
	{
		if ( g_Engine.time < m_flNextBarkTime )
			return;

		m_flNextBarkTime = g_Engine.time + Math.RandomFloat( NIHILRAX_BARK_MIN, NIHILRAX_BARK_MAX );

		string snd = ( Math.RandomLong( 0, 1 ) == 0 ) ? NIHILRAX_BARK_1 : NIHILRAX_BARK_2;

		g_SoundSystem.EmitSoundDyn(
			self.edict(), CHAN_VOICE,
			snd, 1.0f, ATTN_NORM, 0, PITCH_NORM
		);
	}

	// =====================================================
	// Player overlap "belly bounce" – strongly push players out
	// Also applies damage over time if you're deep in the gut.
	// =====================================================
	void PushOverlappingPlayers()
	{
		const float R         = NIHILRAX_PUSH_RADIUS;
		const float R_SQ      = R * R;
		const float INNERR    = NIHILRAX_BELLY_INNER_RADIUS;
		const float INNERR_SQ = INNERR * INNERR;

		// Belly center a bit above origin so it matches the gut visually
		Vector bellyCenter = self.pev.origin + Vector( 0, 0, 40 );

		for ( int i = 1; i <= g_Engine.maxClients; ++i )
		{
			CBasePlayer@ pPlr = g_PlayerFuncs.FindPlayerByIndex( i );
			if ( pPlr is null || !pPlr.IsConnected() || !pPlr.IsAlive() )
				continue;

			Vector plCenter = pPlr.Center();
			Vector delta    = plCenter - bellyCenter;

			float dz = delta.z;
			if ( dz < NIHILRAX_PUSH_Z_MIN || dz > NIHILRAX_PUSH_Z_MAX )
				continue;

			// XY distance squared
			float distSq = delta.x * delta.x + delta.y * delta.y;
			if ( distSq >= R_SQ )
				continue; // outside belly radius

			// true 2D distance in XY
			Vector flat( delta.x, delta.y, 0 );
			float dist = flat.Length();

			Vector pushDir;

			if ( dist < 1.0f )
			{
				// Player basically at our center: push them sideways based on facing
				Vector f, r, u;
				g_EngineFuncs.AngleVectors( Vector( 0, self.pev.angles.y, 0 ), f, r, u );
				pushDir = ( Math.RandomLong( 0, 1 ) == 0 ) ? r : -r;
				pushDir.z = 0;
				pushDir.Normalize();
			}
			else
			{
				// Normalized 2D direction
				pushDir = flat * (1.0f / dist);
			}

			// How far to pop them out so they're clearly outside the hull
			float pushOut = (R - dist) + 16.0f;
			if ( pushOut < 16.0f )
				pushOut = 16.0f;

			// Hard position correction + some velocity for bounce
			pPlr.pev.origin   = pPlr.pev.origin + pushDir * pushOut;
			pPlr.pev.velocity = pPlr.pev.velocity + pushDir * 220.0f + Vector( 0, 0, 80.0f );

			// If they were REALLY too deep in the gut, do a bit of damage (looping)
			if ( distSq < INNERR_SQ )
			{
				pPlr.TakeDamage( self.pev, self.pev, NIHILRAX_BELLY_DMG, DMG_CRUSH );
			}
		}
	}

	// =====================================================
	// Melee assist – if player is close + attacking, fake a small hit
	// =====================================================
	void MeleeAssistCheck()
	{
		Vector myCenter = self.Center();

		for ( int i = 1; i <= g_Engine.maxClients; ++i )
		{
			CBasePlayer@ pPlr = g_PlayerFuncs.FindPlayerByIndex( i );
			if ( pPlr is null || !pPlr.IsConnected() || !pPlr.IsAlive() )
				continue;

			// Only while they're holding primary attack
			if ( (pPlr.pev.button & IN_ATTACK) == 0 )
				continue;

			Vector toBoss = myCenter - pPlr.Center();

			// distance check (squared, no sqrt)
			float distSq    = toBoss.x * toBoss.x + toBoss.y * toBoss.y + toBoss.z * toBoss.z;
			float radiusSq  = NIHILRAX_MELEE_ASSIST_RADIUS * NIHILRAX_MELEE_ASSIST_RADIUS;

			if ( distSq > radiusSq )
				continue;

			// Make sure there is line of sight from player gun to Nihilrax center
			TraceResult tr;
			g_Utility.TraceLine( pPlr.GetGunPosition(), myCenter, dont_ignore_monsters, pPlr.edict(), tr );
			if ( tr.pHit !is self.edict() )
				continue;

			// Direction from Nihilrax to player for damage knockback
			Vector dirToBoss = toBoss;
			dirToBoss.Normalize();

			// Tiny "free" hit to make melee feel consistent
			g_WeaponFuncs.ClearMultiDamage();
			self.TraceAttack(
				pPlr.pev,
				NIHILRAX_MELEE_ASSIST_DMG,
				dirToBoss,
				tr,
				DMG_CLUB | DMG_SLASH
			);
			g_WeaponFuncs.ApplyMultiDamage( pPlr.pev, pPlr.pev );
		}
	}

	// =====================================================
	// Main AI think (movement + targeting + shooting)
	// =====================================================
	void NihlThink()
	{
		// Simple up/down hover (small amplitude so he doesn't bury himself)
		m_flHoverPhase += 0.5f;
		if ( m_flHoverPhase > 8.0f )
			m_flHoverPhase = -8.0f;

		float hover = m_flHoverPhase;

		Vector org = self.pev.origin;
		org.z = m_flBaseZ + hover;
		self.pev.origin = org;

		// Barks while alive
		if ( self.pev.deadflag == DEAD_NO && self.pev.health > 0.0f )
			MaybeDoIdleBark();

		// Find closest visible player
		CBasePlayer@ pPlayer = GetClosestVisiblePlayer( 2048.0f );
		if ( pPlayer !is null )
		{
			Vector dir  = pPlayer.Center() - self.Center();
			float dist  = dir.Length();

			// Face the player (no pitch)
			dir.z = 0;
			if ( dir.Length() > 0.0f )
				self.pev.angles.y = Math.VecToYaw( dir );

			// Use flying anim when we're actively tracking
			SetFlyAnim();

			// Slow drift toward player if far away
			if ( dist > 400.0f )
			{
				dir = dir.Normalize() * NIHILRAX_DRIFT_SPEED;
				self.pev.velocity.x = dir.x;
				self.pev.velocity.y = dir.y;
			}
			else
			{
				self.pev.velocity.x = 0;
				self.pev.velocity.y = 0;
			}

			// Charged attack in progress?
			if ( m_bCharging )
			{
				if ( g_Engine.time >= m_flChargeEndTime )
				{
					// Fire the charged beam now
					CBaseEntity@ pT = m_hChargeTarget;
					CBasePlayer@ pChargeTarget = cast<CBasePlayer@>( pT );
					if ( pChargeTarget is null || !pChargeTarget.IsAlive() )
					{
						@pChargeTarget = pPlayer; // fallback to current target
					}

					FireChargedBeam( pChargeTarget );
					m_bCharging       = false;
					m_iPlannedAttack  = NIHILRAX_ATK_NONE;
					m_flNextAttack    = g_Engine.time + NIHILRAX_CHARGED_COOLDOWN;
				}
				else
				{
					// While charging, pulse a magenta light
					Vector c = self.Center() + Vector(0,0,32);
					NetworkMessage glow( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, c );
					glow.WriteByte( TE_DLIGHT );
					glow.WriteCoord( c.x );
					glow.WriteCoord( c.y );
					glow.WriteCoord( c.z );
					glow.WriteByte( 30 );  // radius
					glow.WriteByte( 255 ); // r
					glow.WriteByte( 60 );  // g
					glow.WriteByte( 255 ); // b
					glow.WriteByte( 3 );   // life (tenths)
					glow.WriteByte( 0 );   // decay
					glow.End();
				}
			}
			else
			{
				// Ready to start a new attack?
				if ( g_Engine.time >= m_flNextAttack )
				{
					DecideAndStartAttack( pPlayer, dist );
				}
			}
		}
		else
		{
			// No target, stop drifting and clear attack state
			self.pev.velocity.x = 0;
			self.pev.velocity.y = 0;
			m_bCharging         = false;
			m_iPlannedAttack    = NIHILRAX_ATK_NONE;
			SetIdleAnim();
		}

		// Push players off his belly so they can't walk through (and belly DoT)
		PushOverlappingPlayers();

		// Give a little helping hand to close-range melee
		MeleeAssistCheck();

		// Try to wiggle free if he's stuck on geometry
		CheckUnstuck();

		// Advance animation (normal speed while alive)
		self.StudioFrameAdvance( 0.1f );

		self.pev.nextthink = g_Engine.time + 0.1f;
	}

	// -----------------------------------------------------
	// Unstuck helper – nudges him sideways if not moving
	// -----------------------------------------------------
	void CheckUnstuck()
	{
		if ( g_Engine.time < m_flNextStuckCheck )
			return;

		m_flNextStuckCheck = g_Engine.time + 0.5f; // check twice per second

		float dist = (self.pev.origin - m_vecLastPos).Length();
		m_vecLastPos = self.pev.origin;

		// If he basically hasn't moved and has a target, shove him
		if ( dist < 8.0f && self.m_hEnemy.IsValid() )
		{
			// Get sideways vector based on facing yaw
			Vector forward, right, up;
			g_EngineFuncs.AngleVectors( Vector(0, self.pev.angles.y, 0), forward, right, up );

			// Randomly choose left or right
			if ( Math.RandomLong( 0, 1 ) == 0 )
				right = -right;

			// Shove sideways and a bit up
			Vector vel = right * 220.0f + Vector( 0, 0, 100.0f );

			// Don’t completely overwrite existing velocity – add to it
			self.pev.velocity = self.pev.velocity + vel;
		}
	}

	// Decide which attack to use and start it immediately / start charging
	void DecideAndStartAttack( CBasePlayer@ pPlayer, float dist )
	{
		if ( pPlayer is null || !pPlayer.IsAlive() )
			return;

		float r = Math.RandomFloat( 0, 1 );

		// Pick attack type based on distance + randomness
		if ( dist < 128.0f )
		{
			// Close: mostly melee, sometimes instant beam
			if ( r < 0.65f )
				m_iPlannedAttack = NIHILRAX_ATK_MELEE;
			else
				m_iPlannedAttack = NIHILRAX_ATK_BEAM_INSTANT;
		}
		else if ( dist < 600.0f )
		{
			// Mid: mix of all 3
			if ( r < 0.40f )
				m_iPlannedAttack = NIHILRAX_ATK_BEAM_INSTANT;
			else if ( r < 0.80f )
				m_iPlannedAttack = NIHILRAX_ATK_BEAM_CHARGED;
			else
				m_iPlannedAttack = NIHILRAX_ATK_MELEE;
		}
		else
		{
			// Long: beams only
			if ( r < 0.50f )
				m_iPlannedAttack = NIHILRAX_ATK_BEAM_INSTANT;
			else
				m_iPlannedAttack = NIHILRAX_ATK_BEAM_CHARGED;
		}

		// Execute behaviour
		if ( m_iPlannedAttack == NIHILRAX_ATK_MELEE )
		{
			DoMeleeAttack( pPlayer );
			m_flNextAttack   = g_Engine.time + NIHILRAX_MELEE_COOLDOWN;
			m_iPlannedAttack = NIHILRAX_ATK_NONE;
		}
		else if ( m_iPlannedAttack == NIHILRAX_ATK_BEAM_INSTANT )
		{
			FireInstantBeam( pPlayer );
			m_flNextAttack   = g_Engine.time + NIHILRAX_INSTANT_COOLDOWN;
			m_iPlannedAttack = NIHILRAX_ATK_NONE;
		}
		else if ( m_iPlannedAttack == NIHILRAX_ATK_BEAM_CHARGED )
		{
			StartChargeAttack( pPlayer );
		}
	}

	// =====================================================
	// Target search
	// =====================================================
	CBasePlayer@ GetClosestVisiblePlayer( float flMaxDist )
	{
		CBasePlayer@ pBest = null;
		float bestDistSq = flMaxDist * flMaxDist;

		for ( int i = 1; i <= g_Engine.maxClients; ++i )
		{
			CBasePlayer@ pPlr = g_PlayerFuncs.FindPlayerByIndex( i );
			if ( pPlr is null || !pPlr.IsConnected() || !pPlr.IsAlive() )
				continue;

			Vector delta = pPlr.Center() - self.Center();

			float distSq = delta.x * delta.x + delta.y * delta.y + delta.z * delta.z;
			if ( distSq > bestDistSq )
				continue;

			// Simple LOS check
			TraceResult tr;
			g_Utility.TraceLine( self.Center(), pPlr.Center(), dont_ignore_monsters, self.edict(), tr );
			if ( tr.flFraction < 1.0f && tr.pHit !is pPlr.edict() )
				continue;

			bestDistSq = distSq;
			@pBest = pPlr;
		}

		return pBest;
	}

	// =====================================================
	// Instant beam, charged beam, melee, FX, death code
	// (unchanged from your version except using engine health)
	// =====================================================

	void FireInstantBeam( CBasePlayer@ pTarget )
	{
		if ( pTarget is null || !pTarget.IsAlive() )
			return;

		SetInstantAttackAnim();
		PlayAttackSound();

		Vector start = self.Center() + Vector( 0, 0, 16 );
		Vector end   = pTarget.Center();

		TraceResult tr;
		g_Utility.TraceLine( start, end, dont_ignore_monsters, self.edict(), tr );

		int sprIndex = g_EngineFuncs.ModelIndex( NIHILRAX_BEAM_SPR );

		// Core beam
		NetworkMessage core( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, start );
		core.WriteByte( TE_BEAMENTPOINT );
		core.WriteShort( self.entindex() );
		core.WriteCoord( tr.vecEndPos.x );
		core.WriteCoord( tr.vecEndPos.y );
		core.WriteCoord( tr.vecEndPos.z );
		core.WriteShort( sprIndex );
		core.WriteByte( 0 );
		core.WriteByte( 25 );
		core.WriteByte( 8 );
		core.WriteByte( 10 );
		core.WriteByte( 0 );
		core.WriteByte( 80 );
		core.WriteByte( 220 );
		core.WriteByte( 255 );
		core.WriteByte( 255 );
		core.WriteByte( 60 );
		core.End();

		// Wrap beam
		NetworkMessage wrap( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, start );
		wrap.WriteByte( TE_BEAMENTPOINT );
		wrap.WriteShort( self.entindex() );
		wrap.WriteCoord( tr.vecEndPos.x );
		wrap.WriteCoord( tr.vecEndPos.y );
		wrap.WriteCoord( tr.vecEndPos.z );
		wrap.WriteShort( sprIndex );
		wrap.WriteByte( 0 );
		wrap.WriteByte( 25 );
		wrap.WriteByte( 8 );
		wrap.WriteByte( 16 );
		wrap.WriteByte( 6 );
		wrap.WriteByte( 140 );
		wrap.WriteByte( 255 );
		wrap.WriteByte( 255 );
		wrap.WriteByte( 220 );
		wrap.WriteByte( 90 );
		wrap.End();

		// Cyan flash
		NetworkMessage flash( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, start );
		flash.WriteByte( TE_DLIGHT );
		flash.WriteCoord( start.x );
		flash.WriteCoord( start.y );
		flash.WriteCoord( start.z );
		flash.WriteByte( 20 );
		flash.WriteByte( 80 );
		flash.WriteByte( 220 );
		flash.WriteByte( 255 );
		flash.WriteByte( 5 );
		flash.WriteByte( 0 );
		flash.End();

		if ( tr.pHit !is null )
		{
			CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
			if ( pHit !is null )
			{
				Vector dir = ( end - start ).Normalize();

				g_WeaponFuncs.ClearMultiDamage();
				pHit.TraceAttack( self.pev, NIHILRAX_INSTANT_DMG, dir, tr, DMG_ENERGYBEAM );
				g_WeaponFuncs.ApplyMultiDamage( self.pev, self.pev );

				g_SoundSystem.EmitSoundDyn(
					self.edict(), CHAN_BODY,
					NIHILRAX_IMPACT_BEAM,
					1.0f, ATTN_NORM, 0, PITCH_NORM
				);

				pTarget.pev.punchangle.x -= 6.0f;
				pTarget.pev.punchangle.y += Math.RandomFloat( -3.0f, 3.0f );

				if ( pHit.BloodColor() != DONT_BLEED )
					g_EntityFuncs.SpawnRandomGibs( pHit.pev, 3, 3 );
			}
		}
	}

	void StartChargeAttack( CBasePlayer@ pTarget )
	{
		if ( pTarget is null || !pTarget.IsAlive() )
			return;

		m_bCharging       = true;
		m_flChargeEndTime = g_Engine.time + NIHILRAX_CHARGE_TIME;
		m_hChargeTarget   = pTarget;

		SetChargedAttackAnim();
		PlayAttackSound();

		Vector c = self.Center() + Vector( 0, 0, 32 );
		NetworkMessage glow( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, c );
		glow.WriteByte( TE_DLIGHT );
		glow.WriteCoord( c.x );
		glow.WriteCoord( c.y );
		glow.WriteCoord( c.z );
		glow.WriteByte( 28 );
		glow.WriteByte( 255 );
		glow.WriteByte( 60 );
		glow.WriteByte( 255 );
		glow.WriteByte( 8 );
		glow.WriteByte( 0 );
		glow.End();
	}

	void FireChargedBeam( CBasePlayer@ pTarget )
	{
		if ( pTarget is null || !pTarget.IsAlive() )
			return;

		Vector start = self.Center() + Vector( 0, 0, 16 );
		Vector end   = pTarget.Center();

		TraceResult tr;
		g_Utility.TraceLine( start, end, dont_ignore_monsters, self.edict(), tr );

		int sprIndex = g_EngineFuncs.ModelIndex( NIHILRAX_BEAM_SPR );

		// Core beam
		NetworkMessage core( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, start );
		core.WriteByte( TE_BEAMENTPOINT );
		core.WriteShort( self.entindex() );
		core.WriteCoord( tr.vecEndPos.x );
		core.WriteCoord( tr.vecEndPos.y );
		core.WriteCoord( tr.vecEndPos.z );
		core.WriteShort( sprIndex );
		core.WriteByte( 0 );
		core.WriteByte( 25 );
		core.WriteByte( 10 );
		core.WriteByte( 28 );
		core.WriteByte( 2 );
		core.WriteByte( 255 );
		core.WriteByte( 60 );
		core.WriteByte( 255 );
		core.WriteByte( 255 );
		core.WriteByte( 50 );
		core.End();

		// Outer wrap
		NetworkMessage wrap( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, start );
		wrap.WriteByte( TE_BEAMENTPOINT );
		wrap.WriteShort( self.entindex() );
		wrap.WriteCoord( tr.vecEndPos.x );
		wrap.WriteCoord( tr.vecEndPos.y );
		wrap.WriteCoord( tr.vecEndPos.z );
		wrap.WriteShort( sprIndex );
		wrap.WriteByte( 0 );
		wrap.WriteByte( 25 );
		wrap.WriteByte( 10 );
		wrap.WriteByte( 34 );
		wrap.WriteByte( 10 );
		wrap.WriteByte( 255 );
		wrap.WriteByte( 120 );
		wrap.WriteByte( 255 );
		wrap.WriteByte( 220 );
		wrap.WriteByte( 80 );
		wrap.End();

		// Big flash
		NetworkMessage flash( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, start );
		flash.WriteByte( TE_DLIGHT );
		flash.WriteCoord( start.x );
		flash.WriteCoord( start.y );
		flash.WriteCoord( start.z );
		flash.WriteByte( 40 );
		flash.WriteByte( 255 );
		flash.WriteByte( 60 );
		flash.WriteByte( 255 );
		flash.WriteByte( 10 );
		flash.WriteByte( 0 );
		flash.End();

		if ( tr.pHit !is null )
		{
			CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
			if ( pHit !is null )
			{
				Vector dir = ( end - start ).Normalize();

				g_WeaponFuncs.ClearMultiDamage();
				pHit.TraceAttack( self.pev, NIHILRAX_CHARGED_DMG, dir, tr, DMG_ENERGYBEAM );
				g_WeaponFuncs.ApplyMultiDamage( self.pev, self.pev );

				g_SoundSystem.EmitSoundDyn(
					self.edict(), CHAN_BODY,
					NIHILRAX_IMPACT_BEAM,
					1.0f, ATTN_NORM, 0, PITCH_NORM
				);

				pTarget.pev.punchangle.x -= 10.0f;
				pTarget.pev.punchangle.y += Math.RandomFloat( -4.0f, 4.0f );

				if ( pHit.BloodColor() != DONT_BLEED )
					g_EntityFuncs.SpawnRandomGibs( pHit.pev, 4, 4 );
			}
		}
	}

	void DoMeleeAttack( CBasePlayer@ pTarget )
	{
		if ( pTarget is null || !pTarget.IsAlive() )
			return;

		float dist = (pTarget.pev.origin - self.pev.origin).Length();
		if ( dist > NIHILRAX_MELEE_RANGE )
			return;

		SetMeleeAnim();
		PlayAttackSound();

		Vector dir = (pTarget.pev.origin - self.pev.origin).Normalize();

		pTarget.TakeDamage(
			self.pev,
			self.pev,
			NIHILRAX_MELEE_DMG,
			DMG_SLASH | DMG_CLUB
		);

		pTarget.pev.velocity = pTarget.pev.velocity + dir * 350.0f + Vector( 0, 0, 80.0f );

		g_SoundSystem.EmitSoundDyn(
			self.edict(), CHAN_BODY,
			NIHILRAX_IMPACT_MELEE,
			1.0f, ATTN_NORM, 0, PITCH_NORM
		);

		pTarget.pev.punchangle.x -= 8.0f;
		pTarget.pev.punchangle.y += Math.RandomFloat( -5.0f, 5.0f );

		if ( pTarget.BloodColor() != DONT_BLEED )
			g_EntityFuncs.SpawnRandomGibs( pTarget.pev, 5, 5 );

		Vector c = self.Center();
		NetworkMessage flash( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, c );
		flash.WriteByte( TE_DLIGHT );
		flash.WriteCoord( c.x );
		flash.WriteCoord( c.y );
		flash.WriteCoord( c.z );
		flash.WriteByte( 32 );
		flash.WriteByte( 255 );
		flash.WriteByte( 160 );
		flash.WriteByte( 60 );
		flash.WriteByte( 6 );
		flash.WriteByte( 0 );
		flash.End();
	}

	void SpawnDeathFX()
	{
		Vector pos = self.Center();

		int spr = g_EngineFuncs.ModelIndex( NIHILRAX_DEATH_SPR );

		NetworkMessage expl( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, pos );
		expl.WriteByte( TE_EXPLOSION );
		expl.WriteCoord( pos.x );
		expl.WriteCoord( pos.y );
		expl.WriteCoord( pos.z );
		expl.WriteShort( spr );
		expl.WriteByte( 45 );
		expl.WriteByte( 6 );
		expl.WriteByte( 0 );
		expl.End();

		dictionary keys;
		keys["origin"]      = pos.ToString();
		keys["model"]       = NIHILRAX_DEATH_SPR;
		keys["rendermode"]  = "5";          // kRenderTransAdd
		keys["renderamt"]   = "255";
		keys["scale"]       = "0.7";
		keys["framerate"]   = "10";
		keys["spawnflags"]  = "1";          // SF_SPRITE_STARTON
		keys["rendercolor"] = "255 60 60";

		g_EntityFuncs.CreateEntity( "env_sprite", keys, true );

		g_EntityFuncs.SpawnRandomGibs( self.pev, 16, 16 );
	}

	void Killed( entvars_t@ pevAttacker, int iGib )
	{
		if ( self.pev.deadflag == DEAD_DYING || self.pev.deadflag == DEAD_DEAD )
			return;

		g_SoundSystem.EmitSoundDyn(
			self.edict(), CHAN_VOICE,
			NIHILRAX_DEATH, 1.0f, ATTN_NORM, 0, PITCH_NORM
		);

		SpawnDeathFX();

		if ( m_iDeathSeq != -1 )
		{
			self.pev.sequence = m_iDeathSeq;
			self.pev.frame    = 0;
			self.ResetSequenceInfo();
		}

		self.pev.takedamage = DAMAGE_NO;
		self.pev.velocity   = g_vecZero;
		self.pev.movetype   = MOVETYPE_FLY;
		self.pev.solid      = SOLID_NOT;

		self.pev.deadflag = DEAD_DYING;

		self.pev.rendermode = kRenderTransAlpha;
		self.pev.renderamt  = 255;

		m_flDeathEndTime = g_Engine.time + NIHILRAX_DEATH_DURATION;

		CBaseEntity@ pAttacker = g_EntityFuncs.Instance( pevAttacker );
		self.SUB_UseTargets( pAttacker is null ? self : pAttacker, USE_TOGGLE, 0.0f );

		SetThink( ThinkFunction( this.NihlDeathThink ) );
		self.pev.nextthink = g_Engine.time + 0.1f;
	}

	void NihlDeathThink()
	{
		if ( m_flDeathEndTime <= 0.0f )
		{
			self.pev.renderamt = 0.0f;
			self.pev.deadflag  = DEAD_DEAD;
			g_EntityFuncs.Remove( self );
			return;
		}

		self.StudioFrameAdvance( 0.05f ); // ~half speed

		if ( self.m_fSequenceFinished )
		{
			self.pev.frame = 0;
			self.ResetSequenceInfo();
		}

		float flTimeLeft = m_flDeathEndTime - g_Engine.time;
		if ( flTimeLeft <= 0.0f )
		{
			self.pev.renderamt = 0.0f;
			self.pev.deadflag  = DEAD_DEAD;
			g_EntityFuncs.Remove( self );
			return;
		}

		float flFrac = flTimeLeft / NIHILRAX_DEATH_DURATION;
		if ( flFrac < 0.0f ) flFrac = 0.0f;
		if ( flFrac > 1.0f ) flFrac = 1.0f;

		self.pev.renderamt = 255.0f * flFrac;

		self.pev.nextthink = g_Engine.time + 0.05f;
	}
}

// Register entity so you can use classname "monster_nihilrax"
void RegisterMonster_Nihilrax()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "monster_nihilrax", "monster_nihilrax" );
}

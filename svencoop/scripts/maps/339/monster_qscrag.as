#include "monsters"
#include "weapons/projectile"

const string Q1_SCRAG_MODEL = "models/cyrax/m_scrag.mdl";

const string Q1_SCRAG_IDLE  = "cyrax/monsters/scrag/idle.wav";
const string Q1_SCRAG_SIGHT = "cyrax/monsters/scrag/sight.wav";
const string Q1_SCRAG_PAIN  = "cyrax/monsters/scrag/pain.wav";
const string Q1_SCRAG_DEATH = "cyrax/monsters/scrag/death.wav";
const string Q1_SCRAG_SHOOT = "cyrax/monsters/scrag/shoot.wav";
const string Q1_SCRAG_HIT   = "cyrax/monsters/scrag/hit.wav";

enum Q1_SCRAG_EVENTS
{
	SCRAG_START_ATTACK = 1,
	SCRAG_END_ATTACK   = 2,
	SCRAG_IDLE_SOUND   = 3
}

class monster_qscrag : ScriptBaseMonsterEntity, monster_qgeneric
{
	void Spawn()
	{
		Precache();

		g_EntityFuncs.SetModel( self, Q1_SCRAG_MODEL );
		g_EntityFuncs.SetSize( self.pev, Vector( -16, -16, -24 ), Vector( 16, 16, 40 ) );
		self.m_bloodColor = BLOOD_COLOR_RED;

		// 🔦 small built-in light so he’s visible in dark red/blinking areas
		self.pev.effects |= EF_DIMLIGHT; // use EF_BRIGHTLIGHT if you want stronger light

		self.pev.health   = 150;
		self.pev.solid    = SOLID_SLIDEBOX;
		self.pev.movetype = MOVETYPE_FLY;

		self.m_MonsterState = MONSTERSTATE_NONE;
		self.m_FormattedName = "Raxspawn";

		self.pev.pain_finished = 0.0f;

		m_iGibHealth = -50;

		FlyMonsterInit();
	}

	void Precache()
	{
		g_Game.PrecacheModel( Q1_SCRAG_MODEL );
		g_Game.PrecacheModel( "models/cyrax/spike.mdl" );

		g_SoundSystem.PrecacheSound( Q1_SCRAG_IDLE );
		g_SoundSystem.PrecacheSound( Q1_SCRAG_SIGHT );
		g_SoundSystem.PrecacheSound( Q1_SCRAG_DEATH );
		g_SoundSystem.PrecacheSound( Q1_SCRAG_SHOOT );
		g_SoundSystem.PrecacheSound( Q1_SCRAG_PAIN );
		g_SoundSystem.PrecacheSound( Q1_SCRAG_HIT );
	}

	void MonsterIdle()
	{
		m_iAttackState  = ATTACK_NONE;
		m_iAIState      = STATE_IDLE;
		SetActivity( ACT_IDLE );
		m_flMonsterSpeed = 0;
	}

	void MonsterSight()
	{
		g_SoundSystem.EmitSoundDyn(
			self.edict(), CHAN_VOICE,
			Q1_SCRAG_SIGHT,
			Math.RandomFloat( 0.95f, 1.0f ),
			ATTN_NORM, 0,
			93 + Math.RandomLong( 0, 0xF )
		);
	}

	void MonsterWalk()
	{
		m_iAttackState  = ATTACK_NONE;
		m_iAIState      = STATE_WALK;
		SetActivity( ACT_WALK );
		m_flMonsterSpeed = 8;
	}

	void MonsterSide()
	{
		m_iAIState      = STATE_RUN;
		SetActivity( ACT_RUN );
		m_flMonsterSpeed = 8;
	}

	void MonsterRun()
	{
		m_iAIState      = STATE_RUN;
		SetActivity( ACT_RUN );
		m_flMonsterSpeed = 16;
	}

	bool MonsterCheckAttack()
	{
		if ( g_Engine.time < m_flAttackFinished )
			return false;

		if ( !m_fEnemyVisible )
			return false;

		if ( m_iEnemyRange == RANGE_FAR )
		{
			if ( m_iAttackState != ATTACK_STRAIGHT )
			{
				m_iAttackState = ATTACK_STRAIGHT;
				MonsterRun();
			}
			return false;
		}

		CBaseEntity@ pTarg = m_hEnemy;

		// see if any entities are in the way of the shot
		Vector spot1 = self.EyePosition();
		Vector spot2 = pTarg.EyePosition();

		TraceResult tr;
		g_Utility.TraceLine( spot1, spot2, dont_ignore_monsters, dont_ignore_glass, self.edict(), tr );

		if ( tr.pHit !is pTarg.edict() )
		{
			// don't have a clear shot, so move to a side
			if ( m_iAttackState != ATTACK_STRAIGHT )
			{
				m_iAttackState = ATTACK_STRAIGHT;
				MonsterRun();
			}
			return false;
		}

		float chance = 0.0f;

		if ( m_iEnemyRange == RANGE_MELEE )
			chance = 0.9f;
		else if ( m_iEnemyRange == RANGE_NEAR )
			chance = 0.6f;
		else if ( m_iEnemyRange == RANGE_MID )
			chance = 0.2f;
		else
			chance = 0.0f;

		if ( Math.RandomFloat( 0, 1 ) < chance )
		{
			m_iAttackState = ATTACK_MISSILE;
			return true;
		}

		if ( m_iEnemyRange == RANGE_MID )
		{
			if ( m_iAttackState != ATTACK_STRAIGHT )
			{
				m_iAttackState = ATTACK_STRAIGHT;
				MonsterRun();
			}
		}
		else
		{
			if ( m_iAttackState != ATTACK_SLIDING )
			{
				m_iAttackState = ATTACK_SLIDING;
				MonsterSide();
			}
		}

		return false;
	}

	void MonsterMissileAttack()
	{
		m_iAIState = STATE_ATTACK;
		SetActivity( ACT_MELEE_ATTACK1 );
	}

	void MonsterAttackFinished()
	{
		AttackFinished( 2 );

		if ( m_iEnemyRange >= RANGE_MID || !m_fEnemyVisible )
		{
			m_iAttackState = ATTACK_STRAIGHT;
			MonsterRun();
		}
		else
		{
			m_iAttackState = ATTACK_SLIDING;
			MonsterSide();
		}
	}

	void MonsterPain( CBaseEntity@ pAttacker, float flDamage )
	{
		if ( Math.RandomLong( 0, 5 ) < 2 )
		{
			g_SoundSystem.EmitSoundDyn(
				self.edict(), CHAN_VOICE,
				Q1_SCRAG_PAIN,
				Math.RandomFloat( 0.95f, 1.0f ),
				ATTN_NORM, 0,
				93 + Math.RandomLong( 0, 0xF )
			);
		}

		if ( Math.RandomLong( 0, 70 ) > flDamage )
			return;

		m_iAIState = STATE_PAIN;
		SetActivity( ACT_BIG_FLINCH );
	}

	void MonsterTimedIdleSound()
	{
		if ( self.pev.radsuit_finished < g_Engine.time )
		{
			g_SoundSystem.EmitSoundDyn(
				self.edict(), CHAN_VOICE,
				Q1_SCRAG_IDLE,
				Math.RandomFloat( 0.95f, 1.0f ),
				ATTN_IDLE, 0,
				93 + Math.RandomLong( 0, 0xF )
			);

			self.pev.radsuit_finished = g_Engine.time + Math.RandomFloat( 2, 8 );
		}
	}

	void MonsterFastFire()
	{
		if ( !m_hEnemy )
			return;

		CBaseEntity@ pEnemy = m_hEnemy;

		g_EngineFuncs.MakeVectors( self.pev.angles );

		Vector vecSrc, vecOffset;

		vecSrc    = self.pev.origin + Vector( 0, 0, 30 ) + g_Engine.v_forward * 14 + g_Engine.v_right * 14;
		vecOffset = -8 * g_Engine.v_right;
		q1_ScragDelaySpike( self, pEnemy, vecSrc, vecOffset, 0.8f );

		vecSrc    = self.pev.origin + Vector( 0, 0, 30 ) + g_Engine.v_forward * 14 + g_Engine.v_right * -14;
		vecOffset = 8 * g_Engine.v_right;
		q1_ScragDelaySpike( self, pEnemy, vecSrc, vecOffset, 0.3f );
	}

	bool MonsterHasMissileAttack() { return true; }
	bool MonsterHasMeleeAttack()   { return false; }
	bool MonsterHasPain()          { return true; }

	void MonsterKilled( entvars_t@ pevAttacker, int iGib )
	{
		if ( ShouldGibMonster( iGib ) )
		{
			g_SoundSystem.EmitSoundDyn(
				self.edict(), CHAN_VOICE,
				"cyrax/gib.wav",
				Math.RandomFloat( 0.95f, 1.0f ),
				ATTN_NORM, 0,
				93 + Math.RandomLong( 0, 0xF )
			);

			g_EntityFuncs.SpawnRandomGibs( self.pev, 1, 1 );
			g_EntityFuncs.Remove( self );
			return;
		}

		self.pev.velocity.x = Math.RandomFloat( -200, 200 );
		self.pev.velocity.y = Math.RandomFloat( -200, 200 );
		self.pev.velocity.z = Math.RandomFloat(  100, 200 );
		self.pev.movetype   = MOVETYPE_TOSS;
		self.pev.flags     &= ~( FL_ONGROUND | FL_FLY );

		// corpse bbox tweak
		g_EntityFuncs.SetSize( self.pev, Vector( -16, -16, -16 ), Vector( 16, 16, 16 ) );

		g_SoundSystem.EmitSoundDyn(
			self.edict(), CHAN_VOICE,
			Q1_SCRAG_DEATH,
			Math.RandomFloat( 0.95f, 1.0f ),
			ATTN_NORM, 0,
			93 + Math.RandomLong( 0, 0xF )
		);
	}

	void HandleAnimEvent( MonsterEvent@ pEvent )
	{
		switch ( pEvent.event )
		{
			case SCRAG_START_ATTACK:
				MonsterFastFire();
				break;

			case SCRAG_END_ATTACK:
				MonsterAttackFinished();
				break;

			case SCRAG_IDLE_SOUND:
				MonsterTimedIdleSound();
				break;

			default:
				BaseClass.HandleAnimEvent( pEvent );
		}
	}
}

void q1_RegisterMonster_SCRAG()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "monster_qscrag", "monster_qscrag" );
}

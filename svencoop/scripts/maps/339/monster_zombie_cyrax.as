// monster_zombie_cyrax.as
//
// Cyrax zombie:
// - Behaves like a simple Half-Life zombie: slow chase + melee slashes
// - Uses custom model: models/cyrax/people/zombie_cyrax.mdl
// - Scale: 0.8
// - Attack sounds: rax_youreabitch2.wav / rax_attack02.wav
// - Death sound: rax_damage01.wav
// - NO idle zombie groans (silent idle)
//
// Sound paths (under sound/):
//   cyrax/raxx/rax_youreabitch2.wav
//   cyrax/raxx/rax_attack02.wav
//   cyrax/raxx/rax_damage01.wav
//
// Extra impact sound on hit:
//   weapons/cbar_hitbod1.wav  (HL crowbar body hit, can be swapped)

#include "monsters"

const string CYRAX_ZOMBIE_MODEL        = "models/cyrax/people/zombie_cyrax.mdl";

const string CYRAX_ZOMBIE_ATTACK1_SND  = "cyrax/raxx/rax_youreabitch2.wav";
const string CYRAX_ZOMBIE_ATTACK2_SND  = "cyrax/raxx/rax_attack02.wav";
const string CYRAX_ZOMBIE_DEATH_SND    = "cyrax/raxx/rax_damage01.wav";

// Impact sound when the melee actually connects
const string CYRAX_ZOMBIE_IMPACT_SND   = "weapons/cbar_hitbod1.wav"; // change to custom if you want

class monster_zombie_cyrax : ScriptBaseMonsterEntity
{
    // State flags
    bool  m_fAttacking        = false;
    bool  m_fDidHitThisSwing  = false;
    bool  m_bWasMoving        = false;
    bool  m_bHitPending       = false;

    float m_flNextAttackTime  = 0.0f;
    float m_flAttackEndTime   = 0.0f;
    float m_flHitTime         = 0.0f;

    EHandle m_hAttackTarget;

    // Movement / combat tuning
    float m_flWalkSpeed       = 55.0f;  // shambling speed
    float m_flAttackRange     = 64.0f;  // melee range
    float m_flAttackCooldown  = 1.5f;   // time between swings
    float m_flAttackDuration  = 1.0f;   // logical attack duration
    float m_flDamagePerHit    = 20.0f;  // slash damage

    // Sequences
    int m_iIdleSeq    = -1;
    int m_iWalkSeq    = -1;
    int m_iAttack1Seq = -1;
    int m_iAttack2Seq = -1;

    // Ensure death sound only plays once
    bool m_bDidDeathSound = false;

    void Spawn()
    {
        Precache();

        g_EntityFuncs.SetModel( self, CYRAX_ZOMBIE_MODEL );
        g_EntityFuncs.SetSize( self.pev, Vector( -16, -16, 0 ), Vector( 16, 16, 72 ) );

        self.pev.solid      = SOLID_SLIDEBOX;
        self.pev.movetype   = MOVETYPE_STEP;
        self.pev.flags     |= FL_MONSTER;
        self.pev.takedamage = DAMAGE_AIM;

        // Approx HL zombie health
        self.pev.health     = 300.0f;

        // Scale down
        self.pev.scale      = 0.8f;

        self.m_bloodColor    = BLOOD_COLOR_RED;
        self.m_flFieldOfView = 0.5f; // ~60 degrees
        self.m_afCapability  = bits_CAP_HEAR;
        self.m_FormattedName = "Cyraxx";

        // Look up sequences from your QC
        m_iIdleSeq    = self.LookupSequence( "idle1" );
        if ( m_iIdleSeq < 0 ) m_iIdleSeq = 0;

        m_iWalkSeq    = self.LookupSequence( "walk" );
        if ( m_iWalkSeq < 0 ) m_iWalkSeq = m_iIdleSeq;

        m_iAttack1Seq = self.LookupSequence( "attack1" );
        if ( m_iAttack1Seq < 0 ) m_iAttack1Seq = m_iIdleSeq;

        m_iAttack2Seq = self.LookupSequence( "attack2" );
        if ( m_iAttack2Seq < 0 ) m_iAttack2Seq = m_iAttack1Seq;

        SetIdleAnim();

        self.MonsterInit();

        SetThink( ThinkFunction( ZombieThink ) );
        self.pev.nextthink = g_Engine.time + 0.1f;
    }

    void Precache()
    {
        g_Game.PrecacheModel( CYRAX_ZOMBIE_MODEL );

        g_SoundSystem.PrecacheSound( CYRAX_ZOMBIE_ATTACK1_SND );
        g_SoundSystem.PrecacheSound( CYRAX_ZOMBIE_ATTACK2_SND );
        g_SoundSystem.PrecacheSound( CYRAX_ZOMBIE_DEATH_SND );
        g_SoundSystem.PrecacheSound( CYRAX_ZOMBIE_IMPACT_SND );
    }

    int Classify()
    {
        // Hostile to players
        return CLASS_ALIEN_MONSTER;
    }

    // --- Suppress HL zombie vocalizations ---

    void IdleSound()  { /* no idle groans */ }
    void AlertSound() { /* no alert */ }
    void PainSound()  { /* no pain */ }

    void DeathSound()
    {
        if ( m_bDidDeathSound )
            return;

        m_bDidDeathSound = true;

        g_SoundSystem.EmitSoundDyn(
            self.edict(), CHAN_VOICE,
            CYRAX_ZOMBIE_DEATH_SND,
            1.0f, ATTN_NORM, 0, PITCH_NORM
        );
    }

    void Killed( entvars_t@ pevAttacker, int iGib )
    {
        // Let baseclass mark deadflag, handle gibs, etc.
        BaseClass.Killed( pevAttacker, iGib );

        // Play death sound once
        DeathSound();

        // Stop all movement and thinking so he doesn't keep walking in place
        self.pev.velocity = g_vecZero;
        self.pev.movetype = MOVETYPE_NONE;
        SetThink( null );
    }

    // --- Animation helpers ---

    void SetIdleAnim()
    {
        if ( m_iIdleSeq < 0 ) return;
        self.pev.sequence  = m_iIdleSeq;
        self.pev.frame     = 0;
        self.pev.framerate = 0.7f;
        self.ResetSequenceInfo();
    }

    void SetWalkAnim()
    {
        if ( m_iWalkSeq < 0 ) return;
        self.pev.sequence  = m_iWalkSeq;
        self.pev.frame     = 0;
        self.pev.framerate = 1.0f;
        self.ResetSequenceInfo();
    }

    void SetAttackAnim()
    {
        // Randomly pick between attack1/attack2 when both exist
        int seq = m_iAttack1Seq;
        if ( m_iAttack2Seq >= 0 && Math.RandomLong( 0, 1 ) == 1 )
            seq = m_iAttack2Seq;

        if ( seq < 0 )
            return;

        self.pev.sequence  = seq;
        self.pev.frame     = 0;
        self.pev.framerate = 1.0f;
        self.ResetSequenceInfo();
    }

    // --- Utility: find nearest player ---

    CBasePlayer@ FindNearestPlayer( float flRadius )
    {
        CBasePlayer@ pBest    = null;
        float bestDistSq      = flRadius * flRadius;

        for ( int i = 1; i <= g_Engine.maxClients; ++i )
        {
            CBasePlayer@ pPlr = g_PlayerFuncs.FindPlayerByIndex( i );
            if ( pPlr is null || !pPlr.IsAlive() )
                continue;

            Vector d = pPlr.pev.origin - self.pev.origin;
            float distSq = d.x*d.x + d.y*d.y + d.z*d.z;

            if ( distSq < bestDistSq )
            {
                bestDistSq = distSq;
                @pBest = pPlr;
            }
        }

        return pBest;
    }

    // --- Attack logic (zombie slash) ---

    void DoMeleeAttack( CBaseEntity@ pTarget )
    {
        if ( pTarget is null || !pTarget.IsAlive() )
            return;

        m_fAttacking        = true;
        m_fDidHitThisSwing  = false;
        m_flNextAttackTime  = g_Engine.time + m_flAttackCooldown;
        m_flAttackEndTime   = g_Engine.time + m_flAttackDuration;

        m_flHitTime         = g_Engine.time + (m_flAttackDuration * 0.5f);
        m_bHitPending       = true;
        m_hAttackTarget     = pTarget;

        self.pev.velocity   = g_vecZero;

        SetAttackAnim();

        // Random of your two attack sounds (voice lines)
        string atkSnd =
            ( Math.RandomLong( 0, 1 ) == 0 ) ?
            CYRAX_ZOMBIE_ATTACK1_SND :
            CYRAX_ZOMBIE_ATTACK2_SND;

        g_SoundSystem.EmitSoundDyn(
            self.edict(), CHAN_WEAPON,
            atkSnd,
            1.0f, ATTN_NORM, 0, PITCH_NORM
        );
    }

    void TryApplyMeleeHit()
    {
        if ( !m_bHitPending )
            return;

        if ( g_Engine.time < m_flHitTime )
            return;

        m_bHitPending = false;

        CBaseEntity@ pTarget = m_hAttackTarget;
        if ( pTarget is null || !pTarget.IsAlive() )
            return;

        Vector d = pTarget.pev.origin - self.pev.origin;
        float dist = d.Length();

        if ( dist <= m_flAttackRange + 16.0f )
        {
            Vector dir = d.Normalize();

            pTarget.TakeDamage(
                self.pev,
                self.pev,
                m_flDamagePerHit,
                DMG_SLASH
            );

            // 🔊 Impact sound on hit
            g_SoundSystem.EmitSoundDyn(
                self.edict(),
                CHAN_BODY,
                CYRAX_ZOMBIE_IMPACT_SND,
                1.0f,
                ATTN_NORM,
                0,
                PITCH_NORM
            );

            // Small shove
            pTarget.pev.velocity = pTarget.pev.velocity + dir * 50.0f;

            m_fDidHitThisSwing = true;
        }
    }

    // --- Main think ---

    void ZombieThink()
    {
        // If he's dead, do nothing
        if ( self.pev.deadflag != DEAD_NO || self.pev.health <= 0 )
            return;

        self.StudioFrameAdvance( 0.1f );

        if ( m_fAttacking )
        {
            AttackThink();
        }
        else
        {
            ChaseThink();
        }

        self.pev.nextthink = g_Engine.time + 0.1f;
    }

    void AttackThink()
    {
        self.pev.velocity = g_vecZero;

        TryApplyMeleeHit();

        if ( g_Engine.time >= m_flAttackEndTime )
        {
            m_fAttacking       = false;
            m_fDidHitThisSwing = false;
            m_bHitPending      = false;
            m_hAttackTarget    = null;

            SetIdleAnim();
            m_bWasMoving = false;
        }
    }

    void ChaseThink()
    {
        CBasePlayer@ pEnemy = FindNearestPlayer( 2048.0f );

        if ( pEnemy is null )
        {
            self.pev.velocity = g_vecZero;

            if ( m_bWasMoving )
            {
                SetIdleAnim();
                m_bWasMoving = false;
            }
            return;
        }

        Vector toEnemy = pEnemy.pev.origin - self.pev.origin;
        toEnemy.z = 0;

        float dist = toEnemy.Length();

        Vector dir;
        if ( dist > 1.0f )
            dir = toEnemy / dist;
        else
            dir = Vector( 1, 0, 0 );

        // Face target
        self.pev.angles.y = Math.VecToYaw( dir );

        // If close and cooldown ready: attack
        if ( dist <= m_flAttackRange && g_Engine.time >= m_flNextAttackTime )
        {
            DoMeleeAttack( pEnemy );
            return;
        }

        // Otherwise, walk towards player
        self.pev.velocity = dir * m_flWalkSpeed;

        bool bMovingNow = ( self.pev.velocity.Length() > 1.0f );

        if ( bMovingNow != m_bWasMoving )
        {
            if ( bMovingNow )
                SetWalkAnim();
            else
                SetIdleAnim();

            m_bWasMoving = bMovingNow;
        }
    }

    float TakeDamage( entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType )
    {
        // Ignore all further damage once dead to prevent repeated death events
        if ( self.pev.deadflag != DEAD_NO )
            return 0.0f;

        float ret = BaseClass.TakeDamage( pevInflictor, pevAttacker, flDamage, bitsDamageType );
        return ret;
    }
}

// Registration helper
void RegisterMonster_ZombieCyrax()
{
    g_CustomEntityFuncs.RegisterCustomEntity( "monster_zombie_cyrax", "monster_zombie_cyrax" );
}

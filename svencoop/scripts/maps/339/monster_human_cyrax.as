// monster_human_cyrax.as
//
// Human cyrax monster:
// - Chases player like a simple zombie
// - Uses "Attack" sequence as melee attack
// - Deals 8 damage per hit
// - At 50% HP runs away from the player for 8 seconds before disappearing
//   while sound/cyrax/raxx/rax_begging.wav plays
// - When he starts fleeing, he also fires trigger_relay "retreat_logic"
//
// Model: models/cyrax/people/scientist_cyrax_tshirt.mdl

#include "monsters"

const string CYRAX_HUMAN_MODEL   = "models/cyrax/people/scientist_cyrax_hoodie.mdl";
const string CYRAX_BEG_SOUND     = "cyrax/raxx/rax_begging.wav";
const string CYRAX_ATTACK_SND1   = "cyrax/monsters/rax_attack01.wav";
const string CYRAX_ATTACK_SND2   = "cyrax/monsters/rax_attack02.wav";

// Impact sound when melee connects
const string CYRAX_IMPACT_SND    = "weapons/cbar_hitbod1.wav"; // change to custom if you want

class monster_human_cyrax : ScriptBaseMonsterEntity
{
    // --- State flags ---
    bool  m_fFleeing          = false;
    bool  m_fAttacking        = false;
    bool  m_fDidHitThisSwing  = false;
    bool  m_bWasMoving        = false; // last frame movement state (for anim switching)

    float m_flFleeEndTime     = 0.0f;
    float m_flNextAttackTime  = 0.0f;
    float m_flAttackEndTime   = 0.0f;
    float m_flHalfHealth      = 0.0f;

    // When to actually apply the hit during the attack anim
    float m_flHitTime         = 0.0f;
    bool  m_bHitPending       = false;
    EHandle m_hAttackTarget;

    // Movement / combat tuning
    float m_flWalkSpeed       = 90.5f;   // shambling speed (+15% from 70)
    float m_flRunSpeed        = 225.0f;  // flee speed
    float m_flAttackRange     = 68.0f;   // melee range
    float m_flAttackCooldown  = 1.0f;    // time between swings
    float m_flAttackDuration  = 0.8f;    // logical attack duration (animation window)

    // Sequence indices (for stable anims)
    int m_iIdleSeq    = -1;
    int m_iWalkSeq    = -1;
    int m_iRunSeq     = -1;
    int m_iAttackSeq  = -1;

    // Ensure retreat relay only fires once
    bool m_bRetreatLogicFired = false;

    void Spawn()
    {
        Precache();

        g_EntityFuncs.SetModel( self, CYRAX_HUMAN_MODEL );
        g_EntityFuncs.SetSize( self.pev, Vector( -16, -16, 0 ), Vector( 16, 16, 72 ) );

        self.pev.solid      = SOLID_SLIDEBOX;
        self.pev.movetype   = MOVETYPE_STEP;
        self.pev.flags     |= FL_MONSTER;
        self.pev.takedamage = DAMAGE_AIM;

        self.pev.health     = 300.0f;
        m_flHalfHealth      = self.pev.health * 0.5f;

        // scale down to 0.8
        self.pev.scale      = 0.8f;

        self.m_bloodColor    = BLOOD_COLOR_RED;
        self.m_flFieldOfView = 0.5f; // roughly 60 degrees field of view

        // Keep it simple: just hearing, no special door capabilities
        self.m_afCapability  = bits_CAP_HEAR;

        self.m_FormattedName = "Cyraxx";

        // Look up sequences once so we don't spam SetActivity
        m_iIdleSeq   = self.LookupSequence( "idle1" );
        if ( m_iIdleSeq < 0 ) m_iIdleSeq = self.LookupSequence( "idle" );
        if ( m_iIdleSeq < 0 ) m_iIdleSeq = 0;

        m_iWalkSeq   = self.LookupSequence( "walk" );
        if ( m_iWalkSeq < 0 ) m_iWalkSeq = self.LookupSequence( "walk_scared" );
        if ( m_iWalkSeq < 0 ) m_iWalkSeq = m_iIdleSeq;

        m_iRunSeq    = self.LookupSequence( "run1" );
        if ( m_iRunSeq < 0 ) m_iRunSeq = self.LookupSequence( "run" );
        if ( m_iRunSeq < 0 ) m_iRunSeq = m_iWalkSeq;

        m_iAttackSeq = self.LookupSequence( "Attack" );
        if ( m_iAttackSeq < 0 ) m_iAttackSeq = self.LookupSequence( "Attack" );
        if ( m_iAttackSeq < 0 ) m_iAttackSeq = m_iIdleSeq;

        // Start idle anim
        SetIdleAnim();

        self.MonsterInit();

        SetThink( ThinkFunction( CyraxThink ) );
        self.pev.nextthink = g_Engine.time + 0.1f;
    }

    void Precache()
    {
        g_Game.PrecacheModel( CYRAX_HUMAN_MODEL );
        g_SoundSystem.PrecacheSound( CYRAX_BEG_SOUND );
        g_SoundSystem.PrecacheSound( CYRAX_ATTACK_SND1 );
        g_SoundSystem.PrecacheSound( CYRAX_ATTACK_SND2 );
        g_SoundSystem.PrecacheSound( CYRAX_IMPACT_SND );
    }

    int Classify()
    {
        // Hostile like a zombie
        return CLASS_ALIEN_MONSTER;
    }

    // --- Animation helpers ---

    void SetIdleAnim()
    {
        if ( m_iIdleSeq < 0 ) return;

        self.pev.sequence  = m_iIdleSeq;
        self.pev.frame     = 0;
        self.pev.framerate = 0.8f; // nice and readable
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

    void SetRunAnim()
    {
        if ( m_iRunSeq < 0 ) return;

        self.pev.sequence  = m_iRunSeq;
        self.pev.frame     = 0;
        self.pev.framerate = 1.0f;
        self.ResetSequenceInfo();
    }

    void SetAttackAnim()
    {
        if ( m_iAttackSeq < 0 ) return;

        self.pev.sequence  = m_iAttackSeq;
        self.pev.frame     = 0;
        self.pev.framerate = 1.0f; // 2x speed like you wanted
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

    // --- Flee behaviour when under 50% HP ---

    void StartFlee()
    {
        if ( m_fFleeing )
            return;

        m_fFleeing          = true;
        m_fAttacking        = false;
        m_fDidHitThisSwing  = false;
        m_bHitPending       = false;
        m_hAttackTarget     = null;
        self.pev.velocity   = g_vecZero;

        m_flFleeEndTime     = g_Engine.time + 8.0f;

        // Play begging sound once
        g_SoundSystem.EmitSoundDyn(
            self.edict(), CHAN_VOICE,
            CYRAX_BEG_SOUND,
            1.0f, ATTN_NORM, 0, 100
        );

        // Scared run animation
        SetRunAnim();

        // Fire retreat_logic only once when he starts fleeing
        if ( !m_bRetreatLogicFired )
        {
            m_bRetreatLogicFired = true;
            // Fire all entities with targetname "retreat_logic"
            g_EntityFuncs.FireTargets( "retreat_logic", self, self, USE_TOGGLE, 0.0f, 0 );
        }
    }

    // --- Melee attack logic (Attack anim with delayed hit) ---

    void DoMeleeAttack( CBaseEntity@ pTarget )
    {
        if ( pTarget is null || !pTarget.IsAlive() )
            return;

        m_fAttacking        = true;
        m_fDidHitThisSwing  = false;
        m_flNextAttackTime  = g_Engine.time + m_flAttackCooldown;
        m_flAttackEndTime   = g_Engine.time + m_flAttackDuration;

        // Hit will occur halfway through the attack window
        m_flHitTime         = g_Engine.time + (m_flAttackDuration * 0.3f);
        m_bHitPending       = true;
        m_hAttackTarget     = pTarget;

        // Stop moving while attacking
        self.pev.velocity   = g_vecZero;

        // Force Attack / attack sequence at 2x speed
        SetAttackAnim();

        // Play one of the attack sounds when he starts the swing
        string atkSnd = (Math.RandomLong(0, 1) == 0) ? CYRAX_ATTACK_SND1 : CYRAX_ATTACK_SND2;
        g_SoundSystem.EmitSoundDyn(
            self.edict(), CHAN_WEAPON,
            atkSnd,
            1.0f, ATTN_NORM, 0, 100
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

        if ( dist <= m_flAttackRange + 16.0f ) // little forgiveness
        {
            Vector dir = d.Normalize();

            pTarget.TakeDamage(
                self.pev,
                self.pev,
                8.0f,   // damage
                DMG_SLASH
            );

            // 🔊 Impact sound when hit connects
            g_SoundSystem.EmitSoundDyn(
                self.edict(),
                CHAN_BODY,
                CYRAX_IMPACT_SND,
                1.0f,
                ATTN_NORM,
                0,
                PITCH_NORM
            );

            // Tiny shove
            pTarget.pev.velocity = pTarget.pev.velocity + dir * 50.0f;

            m_fDidHitThisSwing = true;
        }
    }

    // --- Main think ---

    void CyraxThink()
    {
        if ( self.pev.deadflag != DEAD_NO || self.pev.health <= 0 )
            return;

        // Flee trigger: HP <= 50% of original
        if ( !m_fFleeing && self.pev.health <= m_flHalfHealth )
        {
            StartFlee();
        }

        // Animate based on pev.framerate / sequence
        self.StudioFrameAdvance( 0.1f );

        if ( m_fFleeing )
        {
            FleeThink();
        }
        else if ( m_fAttacking )
        {
            AttackThink();
        }
        else
        {
            ChaseThink();
        }

        self.pev.nextthink = g_Engine.time + 0.1f;
    }

    void FleeThink()
    {
        if ( g_Engine.time >= m_flFleeEndTime )
        {
            // Disappear from the game
            g_EntityFuncs.Remove( self );
            return;
        }

        CBasePlayer@ pEnemy = FindNearestPlayer( 2048.0f );
        if ( pEnemy is null )
        {
            self.pev.velocity = g_vecZero;
            // keep whatever anim is playing
            return;
        }

        // Run directly away from the player
        Vector dir = self.pev.origin - pEnemy.pev.origin;
        dir.z = 0;

        float len = dir.Length();
        if ( len > 1.0f )
            dir = dir / len;
        else
            dir = Vector( 1, 0, 0 ); // arbitrary fallback

        self.pev.velocity   = dir * m_flRunSpeed;
        self.pev.angles.y   = Math.VecToYaw( dir );
        // anim already set to run in StartFlee()
    }

    void AttackThink()
    {
        // Stay still while attacking
        self.pev.velocity = g_vecZero;

        // Check if it's time to apply the melee hit
        TryApplyMeleeHit();

        if ( g_Engine.time >= m_flAttackEndTime )
        {
            m_fAttacking       = false;
            m_fDidHitThisSwing = false;
            m_bHitPending      = false;
            m_hAttackTarget    = null;

            // back to idle once attack is done
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

            // switch to idle if we were moving before
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
            dir = Vector( 1, 0, 0 ); // arbitrary

        // Face the enemy
        self.pev.angles.y = Math.VecToYaw( dir );

        // If close enough and cooldown ready: attack
        if ( dist <= m_flAttackRange && g_Engine.time >= m_flNextAttackTime )
        {
            DoMeleeAttack( pEnemy );
            return;
        }

        // Otherwise, walk toward the player
        self.pev.velocity = dir * m_flWalkSpeed;

        bool bMovingNow = ( self.pev.velocity.Length() > 1.0f );

        // Only change anim when movement state actually changes
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
        float ret = BaseClass.TakeDamage( pevInflictor, pevAttacker, flDamage, bitsDamageType );

        // Re-check flee trigger in case one big hit pushed us under 50%
        if ( !m_fFleeing && self.pev.health > 0 && self.pev.health <= m_flHalfHealth )
        {
            StartFlee();
        }

        return ret;
    }
}

// Registration helpers (support both names)
void RegisterMonster_HumanCyrax()
{
    g_CustomEntityFuncs.RegisterCustomEntity( "monster_human_cyrax", "monster_human_cyrax" );
}

void RegisterMonster_Human_Cyrax()
{
    RegisterMonster_HumanCyrax();
}

// ---------------------------
// monster_superrax.as
// ---------------------------

#include "monsters"

const string SUPER_RAX_MODEL         = "models/cyrax/superrax.mdl";

const string SUPER_RAX_ATTACK_SND    = "cyrax/monsters/rax_attack01.wav";
const string SUPER_RAX_DEATH_SND     = "cyrax/raxx/rax_plz.wav";
const string SUPER_RAX_IDLE_SND      = "cyrax/raxx/raxcomegetme.wav";

// Impact sound when melee connects
const string SUPER_RAX_IMPACT_SND    = "weapons/cbar_hitbod1.wav"; // change to custom if you want

// SPEED / COMBAT SETTINGS
const float SUPER_RAX_BASE_SPEED     = 120.0f;
const float SUPER_RAX_RUN_SPEED      = SUPER_RAX_BASE_SPEED * 1.20f;  // +20% move speed
const float SUPER_RAX_MELEE_RANGE    = 72.0f;
const float SUPER_RAX_MELEE_DMG      = 20.0f;

// How long the attack animation is "locked in" (seconds)
const float SUPER_RAX_ATTACK_ANIM_TIME  = 1.3f;

// Dash settings (short burst forward using runshort)
const float SUPER_RAX_DASH_SPEED        = 320.0f;
const float SUPER_RAX_DASH_DURATION     = 0.5f;
const float SUPER_RAX_DASH_TRIGGER_MIN  = 96.0f;   // don't dash if already right in their face
const float SUPER_RAX_DASH_TRIGGER_MAX  = 256.0f;  // mid-range engage
const float SUPER_RAX_DASH_COOLDOWN     = 4.0f;    // seconds between dashes

// Victory state duration after killing a player
const float SUPER_RAX_VICTORY_TIME      = 4.0f;

class monster_superrax : ScriptBaseMonsterEntity
{
    private float m_flNextAttackTime = 0.0f;
    private float m_flNextIdleSound  = 0.0f;

    // dynamic light timer
    private float m_flNextLightTime  = 0.0f;

    int  m_iWalkSeq     = -1;
    int  m_iIdleSeq     = -1;
    int  m_iAttackSeq   = -1;
    int  m_iDashSeq     = -1; // runshort
    int  m_iVictorySeq  = -1; // victoryeat1
    int  m_iFlinchSeq   = -1; // flinch

    bool  m_bWasMoving       = false; // previous movement state for anim switching
    bool  m_bInAttack        = false; // currently in attack animation lock
    float m_flAttackAnimEnd  = 0.0f;  // time when attack anim lock ends

    bool  m_bDashing         = false;
    float m_flDashEndTime    = 0.0f;
    float m_flNextDashTime   = 0.0f;

    bool  m_bInVictory       = false;
    float m_flVictoryEndTime = 0.0f;

    void Spawn()
    {
        Precache();

        g_EntityFuncs.SetModel( self, SUPER_RAX_MODEL );
        g_EntityFuncs.SetSize( self.pev, Vector(-16,-16,0), Vector(16,16,72) );

        self.pev.solid      = SOLID_SLIDEBOX;
        self.pev.movetype   = MOVETYPE_STEP;
        self.pev.takedamage = DAMAGE_AIM;
        self.pev.flags     |= FL_MONSTER;
        self.m_bloodColor   = BLOOD_COLOR_RED;

        self.pev.health = 1500;

        self.m_afCapability = bits_CAP_HEAR | bits_CAP_DOORS_GROUP;
        self.SetClassification( CLASS_ALIEN_MILITARY );

        // Sequence lookup
        m_iIdleSeq = self.LookupSequence("idle1");
        if (m_iIdleSeq < 0) m_iIdleSeq = self.LookupSequence("idle");
        if (m_iIdleSeq < 0) m_iIdleSeq = 0; // fallback

        m_iWalkSeq = self.LookupSequence("walk");
        if (m_iWalkSeq < 0) m_iWalkSeq = self.LookupSequence("run");
        if (m_iWalkSeq < 0) m_iWalkSeq = self.LookupSequence("walk1");
        if (m_iWalkSeq < 0) m_iWalkSeq = m_iIdleSeq;

        m_iAttackSeq = self.LookupSequence("attack1");

        // Dash, victory, flinch
        m_iDashSeq    = self.LookupSequence("runshort");
        m_iVictorySeq = self.LookupSequence("victoryeat1");
        m_iFlinchSeq  = self.LookupSequence("flinch");

        SetIdleAnim();

        self.MonsterInit();

        m_flNextIdleSound = g_Engine.time + 2.0f;
        m_flNextLightTime = g_Engine.time + 0.1f;
        m_flNextDashTime  = g_Engine.time + 1.0f;

        SetThink( ThinkFunction(SuperRaxThink) );
        self.pev.nextthink = g_Engine.time + 0.1f;
    }

    void Precache()
    {
        g_Game.PrecacheModel( SUPER_RAX_MODEL );
        g_SoundSystem.PrecacheSound( SUPER_RAX_ATTACK_SND );
        g_SoundSystem.PrecacheSound( SUPER_RAX_DEATH_SND );
        g_SoundSystem.PrecacheSound( SUPER_RAX_IDLE_SND );
        g_SoundSystem.PrecacheSound( SUPER_RAX_IMPACT_SND );
    }

    void SetIdleAnim()
    {
        if (m_iIdleSeq >= 0)
        {
            self.pev.sequence  = m_iIdleSeq;
            self.pev.frame     = 0;
            self.pev.framerate = 0.8f; // slow-ish so you can see the texture art
            self.ResetSequenceInfo();
        }
    }

    void SetWalkAnim()
    {
        if (m_iWalkSeq >= 0)
        {
            self.pev.sequence  = m_iWalkSeq;
            self.pev.frame     = 0;
            self.pev.framerate = 0.9f;
            self.ResetSequenceInfo();
        }
    }

    void SetAttackAnim()
    {
        if (m_iAttackSeq >= 0)
        {
            self.pev.sequence  = m_iAttackSeq;
            self.pev.frame     = 0;
            self.pev.framerate = 1.0f;
            self.ResetSequenceInfo();
        }
    }

    void SetDashAnim()
    {
        if (m_iDashSeq >= 0)
        {
            self.pev.sequence  = m_iDashSeq;
            self.pev.frame     = 0;
            self.pev.framerate = 1.2f;
            self.ResetSequenceInfo();
        }
        else
        {
            // fallback to walk/run if missing
            SetWalkAnim();
        }
    }

    void SetVictoryAnim()
    {
        if (m_iVictorySeq >= 0)
        {
            self.pev.sequence  = m_iVictorySeq;
            self.pev.frame     = 0;
            self.pev.framerate = 1.0f;
            self.ResetSequenceInfo();
        }
    }

    void SetFlinchAnim()
    {
        if (m_iFlinchSeq >= 0)
        {
            self.pev.sequence  = m_iFlinchSeq;
            self.pev.frame     = 0;
            self.pev.framerate = 1.0f;
            self.ResetSequenceInfo();
        }
    }

    // Small dynamic light, similar to Scrag glow
    void SpawnLightGlow()
    {
        if (g_Engine.time < m_flNextLightTime)
            return;

        m_flNextLightTime = g_Engine.time + 0.1f;

        Vector org = self.Center();

        NetworkMessage msg( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, org );
            msg.WriteByte( TE_DLIGHT );
            msg.WriteCoord( org.x );
            msg.WriteCoord( org.y );
            msg.WriteCoord( org.z + 10.0f ); // a little above origin
            msg.WriteByte( 15 );  // radius
            msg.WriteByte( 255 ); // R
            msg.WriteByte( 80 );  // G
            msg.WriteByte( 40 );  // B
            msg.WriteByte( 3 );   // life (0.3s)
            msg.WriteByte( 2 );   // decay
        msg.End();
    }

    void StartVictory()
    {
        m_bInVictory       = true;
        m_flVictoryEndTime = g_Engine.time + SUPER_RAX_VICTORY_TIME;

        m_bInAttack = false;
        m_bDashing  = false;
        self.pev.velocity = g_vecZero;

        SetVictoryAnim();
    }

    void SuperRaxThink()
    {
        // 🔒 If he's dead, stop all AI logic
        if ( self.pev.deadflag != DEAD_NO || self.pev.health <= 0 )
        {
            self.pev.velocity = g_vecZero;
            return;
        }

        // If in victory state, just play the animation and stand still
        if (m_bInVictory)
        {
            self.pev.velocity = g_vecZero;

            if (g_Engine.time >= m_flVictoryEndTime)
            {
                m_bInVictory = false;
                SetIdleAnim();
            }

            SpawnLightGlow();
            self.StudioFrameAdvance(0.08f);
            self.pev.nextthink = g_Engine.time + 0.1f;
            return;
        }

        CBaseEntity@ pEnemy = FindNearestPlayer(1024.0f);

        bool bMovingNow = false;

        // Handle attack lock ending
        if (m_bInAttack && g_Engine.time >= m_flAttackAnimEnd)
        {
            m_bInAttack = false;
            // when attack ends, go back to idle by default (we'll override with walk if we start moving)
            m_bWasMoving = false;
            SetIdleAnim();
        }

        if (pEnemy !is null && pEnemy.IsAlive())
        {
            Vector toEnemy = pEnemy.Center() - self.Center();
            float dist     = toEnemy.Length();

            // Face enemy (on yaw only)
            toEnemy.z = 0;
            if (toEnemy.Length() > 0)
                self.pev.angles.y = Math.VecToYaw(toEnemy);

            // If we're in attack lock, just hold still
            if (m_bInAttack)
            {
                self.pev.velocity = g_vecZero;
            }
            else if (m_bDashing)
            {
                // Continue dash toward enemy
                Vector dir = pEnemy.Center() - self.Center();
                dir.z = 0;
                float len = dir.Length();
                if (len > 1.0f)
                    dir = dir / len;
                else
                    dir = Vector(1,0,0);

                self.pev.velocity = dir * SUPER_RAX_DASH_SPEED;
                bMovingNow = true;

                // End dash if time up or we are in melee range
                if (g_Engine.time >= m_flDashEndTime || dist <= SUPER_RAX_MELEE_RANGE)
                {
                    m_bDashing = false;
                    self.pev.velocity = g_vecZero;

                    // If close enough and can attack, immediately swing
                    if (dist <= SUPER_RAX_MELEE_RANGE && g_Engine.time >= m_flNextAttackTime)
                    {
                        m_bInAttack        = true;
                        m_flAttackAnimEnd  = g_Engine.time + SUPER_RAX_ATTACK_ANIM_TIME;
                        DoMeleeAttack(pEnemy);
                        m_flNextAttackTime = g_Engine.time + 1.5f; // cooldown
                    }
                }
            }
            else
            {
                // Not attacking and not currently dashing
                // Possibly start a dash if in mid-range
                if (dist > SUPER_RAX_DASH_TRIGGER_MIN &&
                    dist <= SUPER_RAX_DASH_TRIGGER_MAX &&
                    g_Engine.time >= m_flNextDashTime)
                {
                    m_bDashing       = true;
                    m_flDashEndTime  = g_Engine.time + SUPER_RAX_DASH_DURATION;
                    m_flNextDashTime = g_Engine.time + SUPER_RAX_DASH_COOLDOWN;

                    SetDashAnim();

                    Vector dir = toEnemy;
                    dir.z = 0;
                    float len = dir.Length();
                    if (len > 1.0f)
                        dir = dir / len;
                    else
                        dir = Vector(1,0,0);

                    self.pev.velocity = dir * SUPER_RAX_DASH_SPEED;
                    bMovingNow = true;
                }
                else
                {
                    // Regular chase / melee
                    if (dist > SUPER_RAX_MELEE_RANGE)
                    {
                        // Chase
                        Vector dir = toEnemy.Normalize();
                        self.pev.velocity = dir * SUPER_RAX_RUN_SPEED;
                        bMovingNow = true;
                    }
                    else
                    {
                        // In melee range
                        self.pev.velocity = g_vecZero;

                        if (g_Engine.time >= m_flNextAttackTime)
                        {
                            // Start attack
                            m_bInAttack        = true;
                            m_flAttackAnimEnd  = g_Engine.time + SUPER_RAX_ATTACK_ANIM_TIME;
                            DoMeleeAttack(pEnemy);
                            m_flNextAttackTime = g_Engine.time + 1.5f; // cooldown
                        }
                    }
                }
            }
        }
        else
        {
            // No enemy
            self.pev.velocity = g_vecZero;
        }

        // Only flip between walk/idle when NOT in attack and NOT dashing
        if (!m_bInAttack && !m_bDashing && bMovingNow != m_bWasMoving)
        {
            if (bMovingNow)
                SetWalkAnim(); // normal WALK anim when just pathing
            else
                SetIdleAnim();

            m_bWasMoving = bMovingNow;
        }

        // Idle groans while alive (not dead)
        if (g_Engine.time >= m_flNextIdleSound && self.pev.health > 0)
        {
            g_SoundSystem.EmitSoundDyn(
                self.edict(), CHAN_VOICE,
                SUPER_RAX_IDLE_SND,
                1.0f, ATTN_NORM, 0, PITCH_NORM
            );
            m_flNextIdleSound = g_Engine.time + Math.RandomFloat(3.0f, 6.0f);
        }

        // Spawn dynamic light glow
        SpawnLightGlow();

        // Smooth animation
        self.StudioFrameAdvance( 0.08f );

        self.pev.nextthink = g_Engine.time + 0.1f;
    }

    CBaseEntity@ FindNearestPlayer(float maxDist)
    {
        CBaseEntity@ best = null;
        float bestSq = maxDist * maxDist;

        for (int i = 1; i <= g_Engine.maxClients; ++i)
        {
            CBasePlayer@ p = g_PlayerFuncs.FindPlayerByIndex(i);
            if (p is null || !p.IsConnected() || !p.IsAlive())
                continue;

            Vector delta = p.Center() - self.Center();
            float dsq = delta.x * delta.x + delta.y * delta.y + delta.z * delta.z;

            if (dsq < bestSq)
            {
                bestSq = dsq;
                @best  = p;
            }
        }

        return best;
    }

    void DoMeleeAttack(CBaseEntity@ pTarget)
    {
        // Start attack animation
        SetAttackAnim();

        // Play attack sound
        g_SoundSystem.EmitSoundDyn(
            self.edict(), CHAN_WEAPON,
            SUPER_RAX_ATTACK_SND,
            1.0f, ATTN_NORM, 0, PITCH_NORM
        );

        // Melee trace straight ahead
        g_EngineFuncs.MakeVectors(self.pev.angles);
        Vector forward = g_Engine.v_forward;

        TraceResult tr;
        g_Utility.TraceHull(
            self.Center(),
            self.Center() + forward * SUPER_RAX_MELEE_RANGE,
            dont_ignore_monsters,
            head_hull,
            self.edict(),
            tr
        );

        if (tr.pHit !is null)
        {
            CBaseEntity@ pHit = g_EntityFuncs.Instance(tr.pHit);
            if (pHit !is null && pHit.pev.takedamage != DAMAGE_NO)
            {
                pHit.TakeDamage(self.pev, self.pev, SUPER_RAX_MELEE_DMG, DMG_SLASH);

                // 🔊 Impact sound on successful hit
                g_SoundSystem.EmitSoundDyn(
                    self.edict(),
                    CHAN_BODY,
                    SUPER_RAX_IMPACT_SND,
                    1.0f,
                    ATTN_NORM,
                    0,
                    PITCH_NORM
                );

                // If we killed a player, go into victoryeat1 idle state
                CBasePlayer@ pPlr = cast<CBasePlayer@>(pHit);
                if (pPlr !is null && !pPlr.IsAlive())
                {
                    StartVictory();
                }
            }
        }
    }

    float TakeDamage(entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType)
    {
        float ret = BaseClass.TakeDamage(pevInflictor, pevAttacker, flDamage, bitsDamageType);

        // Flinch when taking damage, as long as we're not dead or in victory
        if (self.pev.health > 0 && !m_bInVictory)
        {
            SetFlinchAnim();
        }

        return ret;
    }

    void Killed(entvars_t@ pevAttacker, int iGib)
    {
        g_SoundSystem.EmitSoundDyn(
            self.edict(), CHAN_VOICE,
            SUPER_RAX_DEATH_SND,
            1.0f, ATTN_NORM, 0, PITCH_NORM
        );

        BaseClass.Killed(pevAttacker, iGib);

        // 🔒 Freeze corpse so he doesn't keep sliding/AI-ing
        self.pev.velocity = g_vecZero;
        self.pev.movetype = MOVETYPE_NONE;
        SetThink( null );
    }
}

void RegisterMonster_SuperRax()
{
    g_CustomEntityFuncs.RegisterCustomEntity("monster_superrax", "monster_superrax");
}

// monster_alextafini.as
//
// Custom Cyrax monster using models/cyrax/people/alextafini.mdl
// Voice lines in sound/cyrax/alexbigt/*
//
// Entity classname: monster_alextafini

const string ALEX_MODEL = "models/cyrax/people/alextafini.mdl";

// --- Sound mapping ---
//
// Notices player (AlertSound):     yourepedo.wav
// Takes damage (PainSound):        helpme.wav   (rate-limited)
// Idle/Bark pool (10–15s):         backup, dropyou, yourepedo, knockout
// Melee attack barks:              handsonme, punchmeagain
// Death:                           friend.wav
// Impact sound on hit:             crowbar body hit
// Body hitting ground:             common/bodydrop3.wav

array<string> g_AlexBarkSounds = {
    "cyrax/alexbigt/backup.wav",
    "cyrax/alexbigt/dropyou.wav",
    "cyrax/alexbigt/yourepedo.wav",
    "cyrax/alexbigt/knockout.wav"
};

array<string> g_AlexAttackSounds = {
    "cyrax/alexbigt/handsonme.wav",
    "cyrax/alexbigt/punchmeagain.wav"
};

// Pain line: help me
const string ALEX_PAIN_SOUND      = "cyrax/alexbigt/helpme.wav";
// Alert line: you’re a pedo
const string ALEX_ALERT_SOUND     = "cyrax/alexbigt/yourepedo.wav";
// Death line
const string ALEX_DEATH_SOUND     = "cyrax/alexbigt/friend.wav";
// Impact/foley when hit connects
const string ALEX_IMPACT_SOUND    = "weapons/cbar_hitbod1.wav";
// Body hitting the floor
const string ALEX_BODYDROP_SOUND  = "common/bodydrop3.wav";

// Small helper to precache an array of sounds
void PrecacheSoundArray(array<string>@ sounds)
{
    for (int i = 0; i < int(sounds.length()); i++)
        g_SoundSystem.PrecacheSound(sounds[i]);
}

class monster_alextafini : ScriptBaseMonsterEntity
{
    // Next time he’s allowed to START a melee attack
    float m_flNextMeleeAttack;

    // Cooldown for helpme.wav so it doesn’t spam
    float m_flNextPainTime;

    // We’ll use pev.fuser1 as the next idle bark time
    void SetNextIdleBark()
    {
        // 10–15 seconds from now
        self.pev.fuser1 = g_Engine.time + Math.RandomFloat(10.0f, 15.0f);
    }

    void Precache()
    {
        g_Game.PrecacheModel(ALEX_MODEL);

        PrecacheSoundArray(g_AlexBarkSounds);
        PrecacheSoundArray(g_AlexAttackSounds);

        g_SoundSystem.PrecacheSound(ALEX_PAIN_SOUND);
        g_SoundSystem.PrecacheSound(ALEX_ALERT_SOUND);
        g_SoundSystem.PrecacheSound(ALEX_DEATH_SOUND);
        g_SoundSystem.PrecacheSound(ALEX_IMPACT_SOUND);
        g_SoundSystem.PrecacheSound(ALEX_BODYDROP_SOUND);

        BaseClass.Precache();
    }

    void Spawn()
    {
        Precache();

        g_EntityFuncs.SetModel(self, ALEX_MODEL);

        // Human-sized hull
        g_EntityFuncs.SetSize(self.pev, VEC_HUMAN_HULL_MIN, VEC_HUMAN_HULL_MAX);

        self.pev.solid    = SOLID_SLIDEBOX;
        self.pev.movetype = MOVETYPE_STEP;

        self.m_bloodColor  = BLOOD_COLOR_RED;
        self.pev.health    = 120;       // tweak as you like
        self.pev.yaw_speed = 120;

        self.pev.view_ofs    = Vector(0, 0, 60);
        self.m_flFieldOfView = 0.5f;    // ~120° vision cone

        // Standard humanoid capabilities so he actually behaves like a proper monster
        self.m_afCapability = bits_CAP_HEAR | bits_CAP_TURN_HEAD | bits_CAP_DOORS_GROUP;

        m_flNextMeleeAttack = 0.0f;     // melee cooldown timer
        m_flNextPainTime    = 0.0f;     // pain sound cooldown

        SetNextIdleBark();
        self.MonsterInit();
    }

    int Classify()
    {
        // Aggressive human-type enemy
        return CLASS_HUMAN_MILITARY;
    }

    void SetYawSpeed()
    {
        self.pev.yaw_speed = 120;
    }

    // ------------------------
    //  AI: melee-only attacker
    // ------------------------
    bool CheckRangeAttack1(float flDot, float flDist)
    {
        // No ranged attack
        return false;
    }

    bool CheckMeleeAttack1(float flDot, float flDist)
    {
        // Enforce a 2.9-second cooldown between melee STARTS
        if (g_Engine.time < m_flNextMeleeAttack)
            return false;

        if (flDist <= 70.0f && flDot >= 0.7f)
        {
            // Next time he’s allowed to start another swing
            m_flNextMeleeAttack = g_Engine.time + 2.9f;
            return true;
        }

        return false;
    }

    // Attack anim event
    void HandleAnimEvent(MonsterEvent@ pEvent)
    {
        switch (pEvent.event)
        {
            case 2:
            {
                // Melee hit frame
                float flDamage = 25.0f; // tweak

                // Just smack our current enemy if it’s close enough
                CBaseEntity@ pEnemy = self.m_hEnemy.GetEntity();

                if (pEnemy !is null && pEnemy.IsAlive())
                {
                    Vector vecToEnemy = pEnemy.pev.origin - self.pev.origin;
                    float flDist = vecToEnemy.Length();

                    if (flDist <= 70.0f)
                    {
                        pEnemy.TakeDamage(self.pev, self.pev, flDamage, DMG_CLUB);

                        // Impact foley on hit
                        g_SoundSystem.EmitSoundDyn(
                            self.edict(),
                            CHAN_BODY,
                            ALEX_IMPACT_SOUND,
                            1.0f,
                            ATTN_NORM,
                            0,
                            PITCH_NORM
                        );
                    }
                }

                // Play one of the punch lines
                if (g_AlexAttackSounds.length() > 0)
                {
                    int idx = Math.RandomLong(0, int(g_AlexAttackSounds.length()) - 1);
                    g_SoundSystem.EmitSoundDyn(
                        self.edict(),
                        CHAN_WEAPON,
                        g_AlexAttackSounds[idx],
                        1.0f,
                        ATTN_NORM,
                        0,
                        PITCH_NORM
                    );
                }
                break;
            }

            default:
                BaseClass.HandleAnimEvent(pEvent);
        }
    }

    // ------------- 
    //  Voice lines 
    // -------------

    // Called by engine when he idles
    void IdleSound()
    {
        if (g_AlexBarkSounds.length() == 0)
            return;

        int idx = Math.RandomLong(0, int(g_AlexBarkSounds.length()) - 1);
        g_SoundSystem.EmitSoundDyn(
            self.edict(),
            CHAN_VOICE,
            g_AlexBarkSounds[idx],
            1.0f,
            ATTN_IDLE,
            0,
            PITCH_NORM
        );
    }

    // Plays when he notices the player
    void AlertSound()
    {
        g_SoundSystem.EmitSoundDyn(
            self.edict(),
            CHAN_VOICE,
            ALEX_ALERT_SOUND,
            1.0f,
            ATTN_NORM,
            0,
            PITCH_NORM
        );
    }

    void AttackSound()
    {
        // Backup if engine ever calls this directly
        if (g_AlexAttackSounds.length() == 0)
            return;

        int idx = Math.RandomLong(0, int(g_AlexAttackSounds.length()) - 1);
        g_SoundSystem.EmitSoundDyn(
            self.edict(),
            CHAN_VOICE,
            g_AlexAttackSounds[idx],
            1.0f,
            ATTN_NORM,
            0,
            PITCH_NORM
        );
    }

    // Plays when he takes damage
    void PainSound()
    {
        // Throttle helpme.wav so it only plays every few hits
        if (g_Engine.time < m_flNextPainTime)
            return;

        m_flNextPainTime = g_Engine.time + 2.5f; // adjust if you want it rarer

        g_SoundSystem.EmitSoundDyn(
            self.edict(),
            CHAN_VOICE,
            ALEX_PAIN_SOUND,
            1.0f,
            ATTN_NORM,
            0,
            PITCH_NORM
        );
    }

    void DeathSound()
    {
        g_SoundSystem.EmitSoundDyn(
            self.edict(),
            CHAN_VOICE,
            ALEX_DEATH_SOUND,
            1.0f,
            ATTN_NORM,
            0,
            PITCH_NORM
        );
    }

    // Make sure our custom death + body thud always play
    void Killed(entvars_t@ pevAttacker, int iGib)
    {
        DeathSound();

        // Body thud when corpse hits the floor
        g_SoundSystem.EmitSoundDyn(
            self.edict(),
            CHAN_BODY,
            ALEX_BODYDROP_SOUND,
            1.0f,
            ATTN_NORM,
            0,
            PITCH_NORM
        );

        BaseClass.Killed(pevAttacker, iGib);
    }

    // ---------------
    //  Timed barks + proximity awareness
    // ---------------

    void PrescheduleThink()
    {
        if (!self.IsAlive())
            return;

        // Simple proximity check so he doesn't "ignore" a nearby player
        CBaseEntity@ pEnt = null;
        while ((@pEnt = g_EntityFuncs.FindEntityByClassname(pEnt, "player")) !is null)
        {
            CBasePlayer@ pPl = cast<CBasePlayer@>(pEnt);
            if (pPl is null || !pPl.IsAlive())
                continue;

            float dist = (pPl.pev.origin - self.pev.origin).Length();

            // If a player is very close, force combat state
            if (dist <= 128.0f)
            {
                self.m_hEnemy = pPl;
                self.m_IdealMonsterState = MONSTERSTATE_COMBAT;
                break;
            }
        }

        // Use pev.fuser1 as "next bark time"
        if (g_Engine.time >= self.pev.fuser1)
        {
            IdleSound();       // random from backup/dropyou/yourepedo/knockout
            SetNextIdleBark(); // schedule next 10–15s bark
        }
    }
}

// Registration function – call this from your MapInit()
void RegisterMonsterAlexTafini()
{
    g_CustomEntityFuncs.RegisterCustomEntity("monster_alextafini", "monster_alextafini");
}

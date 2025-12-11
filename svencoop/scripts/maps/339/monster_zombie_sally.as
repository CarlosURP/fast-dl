// monster_zombie_sally.as
// Simple zombie-style melee monster using models/cyrax/people/zombie_sally.mdl

namespace monster_zombie_sally
{
    // --------------------------------------------------------
    // Config
    // --------------------------------------------------------
    const string SALLY_MODEL          = "models/cyrax/people/zombie_sally.mdl";

    const string SND_DEATH            = "cyrax/zombie_sally/sally_die.wav";        // on death
    const string SND_HIT              = "cyrax/zombie_sally/hit_female01.wav";     // when she hits player
    const string SND_PAIN             = "cyrax/zombie_sally/sally_damage01.wav";   // when she takes damage

    const float  SALLY_HEALTH         = 60.0f;
    const float  SALLY_FOV            = 0.5f;
    const float  SALLY_YAWSPEED       = 220.0f;

    // Larger + more forgiving melee
    const float  SALLY_MELEE_RANGE    = 80.0f;   // was 64
    const float  SALLY_MELEE_DAMAGE   = 20.0f;

    // Speed tweaks
    const float  SALLY_WALK_FRAMERATE   = 1.25f; // 25% faster walk
    const float  SALLY_ATTACK_FRAMERATE = 1.50f; // 50% faster attack

    // --------------------------------------------------------
    // Entity class
    // --------------------------------------------------------
    class CMonsterZombieSally : ScriptBaseMonsterEntity
    {
        float m_flNextPainSound;
        bool  m_bDidHitThisSwing;

        // ----------------------------------------------------
        // Precache
        // ----------------------------------------------------
        void Precache()
        {
            g_Game.PrecacheModel( SALLY_MODEL );

            g_SoundSystem.PrecacheSound( SND_DEATH );
            g_SoundSystem.PrecacheSound( SND_HIT );
            g_SoundSystem.PrecacheSound( SND_PAIN );

            BaseClass.Precache();
        }

        // ----------------------------------------------------
        // Spawn / setup
        // ----------------------------------------------------
        void Spawn()
        {
            Precache();

            g_EntityFuncs.SetModel( self, SALLY_MODEL );
            g_EntityFuncs.SetSize( self.pev, VEC_HUMAN_HULL_MIN, VEC_HUMAN_HULL_MAX );

            self.pev.solid     = SOLID_SLIDEBOX;
            self.pev.movetype  = MOVETYPE_STEP;
            self.pev.health    = SALLY_HEALTH;
            self.pev.yaw_speed = SALLY_YAWSPEED;
            self.pev.flags    |= FL_MONSTER;
            self.m_bloodColor  = BLOOD_COLOR_RED;

            self.pev.view_ofs  = Vector( 0, 0, 60 ); // matches EyePosition-ish
            self.pev.fov       = SALLY_FOV;

            // basic melee monster capabilities
            self.m_afCapability = bits_CAP_DOORS_GROUP |
                                  bits_CAP_HEAR |
                                  bits_CAP_TURN_HEAD |
                                  bits_CAP_MELEE_ATTACK1;

            self.MonsterInit();

            m_flNextPainSound   = 0.0f;
            m_bDidHitThisSwing  = false;
        }

        // ----------------------------------------------------
        // Classification (treat as alien/zombie so HECU hate her)
        // ----------------------------------------------------
        int Classify()
        {
            return CLASS_ALIEN_MONSTER;
        }

        // ----------------------------------------------------
        // Sounds
        // ----------------------------------------------------
        void PainSound()
        {
            if( g_Engine.time < m_flNextPainSound )
                return;

            g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, SND_PAIN,
                                        1.0f, ATTN_NORM, 0, PITCH_NORM );
            m_flNextPainSound = g_Engine.time + 0.6f;
        }

        void DeathSound()
        {
            g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, SND_DEATH,
                                        1.0f, ATTN_NORM, 0, PITCH_NORM );
        }

        // ----------------------------------------------------
        // Damage / death
        // ----------------------------------------------------
        int TakeDamage( entvars_t@ pevInflictor, entvars_t@ pevAttacker,
                        float flDamage, int bitsDamageType )
        {
            int result = BaseClass.TakeDamage( pevInflictor, pevAttacker, flDamage, bitsDamageType );

            if( self.IsAlive() )
                PainSound();

            return result;
        }

        void Killed( entvars_t@ pevAttacker, int iGib )
        {
            DeathSound();
            BaseClass.Killed( pevAttacker, iGib );
        }

        // ----------------------------------------------------
        // Melee attack checks (zombie-style)
        // ----------------------------------------------------
        bool CheckMeleeAttack1( float flDot, float flDist )
        {
            if( !self.m_hEnemy.IsValid() )
                return false;

            if( flDist > SALLY_MELEE_RANGE )
                return false;

            // More forgiving facing requirement
            if( flDot < 0.2f )
                return false;

            CBaseEntity@ pEnemy = self.m_hEnemy;
            if( pEnemy is null )
                return false;

            Vector vecEnemy = pEnemy.pev.origin + pEnemy.pev.view_ofs;
            if( !self.FVisible( vecEnemy ) )
                return false;

            return true;
        }

        // ----------------------------------------------------
        // Anim events from QC
        //
        // attack1:
        //   { event 1 10 }  -> start swing
        //   { event 2 19 }  -> hit frame
        //
        // attack2:
        //   { event 3 6 }   -> hit frame
        //
        // We try to hit on ALL of them, but only once per swing.
        // ----------------------------------------------------
        void HandleAnimEvent( MonsterEvent@ pEvent )
        {
            switch( pEvent.event )
            {
                case 1: // start of attack1 swing
                    m_bDidHitThisSwing = false;
                    DoMeleeHit();      // try hitting early in the swing
                    break;

                case 2: // attack1 later impact
                case 3: // attack2 impact
                    DoMeleeHit();
                    break;

                default:
                    BaseClass.HandleAnimEvent( pEvent );
            }
        }

        // ----------------------------------------------------
        // Apply melee damage when her swing connects
        // ----------------------------------------------------
        void DoMeleeHit()
        {
            if( m_bDidHitThisSwing )
                return; // only once per swing

            if( !self.m_hEnemy.IsValid() )
                return;

            CBaseEntity@ pEnemy = self.m_hEnemy;
            if( pEnemy is null )
                return;

            Vector vecToEnemy = pEnemy.pev.origin - self.pev.origin;
            float flDist      = vecToEnemy.Length();

            if( flDist > SALLY_MELEE_RANGE )
                return;

            // require she be somewhat facing the enemy, but forgiving
            vecToEnemy = vecToEnemy.Normalize();

            Vector forward, right, up;
            g_EngineFuncs.AngleVectors( self.pev.angles, forward, right, up );

            if( DotProduct( forward, vecToEnemy ) < 0.2f )
                return;

            // Deal damage directly
            pEnemy.TakeDamage( self.pev, self.pev, float(SALLY_MELEE_DAMAGE), DMG_SLASH );

            // Play hit sound
            g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, SND_HIT,
                                        1.0f, ATTN_NORM, 0, PITCH_NORM );

            m_bDidHitThisSwing = true;
        }

        // ----------------------------------------------------
        // AI think – also control animation speeds here
        // ----------------------------------------------------
        void RunAI()
        {
            BaseClass.RunAI();

            // Control animation framerate based on current activity
            if( self.m_Activity == ACT_WALK )
            {
                self.pev.framerate = SALLY_WALK_FRAMERATE;
            }
            else if( self.m_Activity == ACT_MELEE_ATTACK1 )
            {
                self.pev.framerate = SALLY_ATTACK_FRAMERATE;
            }
            else
            {
                self.pev.framerate = 1.0f;
            }
        }
    }
} // namespace monster_zombie_sally

// ------------------------------------------------------------
// Registration helper – call this from MapInit()
// ------------------------------------------------------------
void RegisterMonsterZombieSally()
{
    g_CustomEntityFuncs.RegisterCustomEntity(
        "monster_zombie_sally::CMonsterZombieSally",
        "monster_zombie_sally"
    );
}

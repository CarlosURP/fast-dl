// monster_edgrunt.as
// Simple scripted human-grunt style enemy using models/cyrax/people/hgrunt_ed.mdl

namespace monster_edgrunt
{
    // --------------------------------------------------------
    // Config
    // --------------------------------------------------------
    const string EDGRUNT_MODEL       = "models/cyrax/people/hgrunt_ed.mdl";

    const string SND_BABBLE         = "cyrax/ed/ed_babble.wav";       // bark / pain / death
    const string SND_IDLE_A         = "cyrax/ed/ed_hidingface.wav";   // idle
    const string SND_IDLE_B         = "cyrax/ed/ed_yearight.wav";     // idle
    const string SND_ALERT          = "cyrax/ed/ed_ugotago.wav";      // spotted player

    const string SND_PAINTBALL_1    = "cyrax/weapons/paintball01.wav";
    const string SND_PAINTBALL_2    = "cyrax/weapons/paintball02.wav";

    // Kick + body thud sounds (HL-style melee/impact)
    const string SND_KICK_HIT       = "weapons/cbar_hitbod1.wav";     // impact on victim
    const string SND_BODY_THUD      = "common/bodydrop3.wav";         // body hitting ground

    const float  EDGRUNT_HEALTH         = 300.0f;
    const float  EDGRUNT_FOV            = 0.35f;
    const float  EDGRUNT_YAWSPEED       = 200.0f;
    const float  EDGRUNT_IDLE_MIN_DELAY = 8.0f;
    const float  EDGRUNT_IDLE_MAX_DELAY = 16.0f;

    const float  EDGRUNT_MP5_RANGE      = 2048.0f;
    const float  EDGRUNT_MP5_SPREAD     = 0.04f;
    const int    EDGRUNT_MP5_CLIP       = 30;
    const int    EDGRUNT_MP5_DAMAGE     = 5;

    // Melee (kick) settings
    const float  EDGRUNT_KICK_RANGE     = 70.0f;
    const float  EDGRUNT_KICK_DAMAGE    = 25.0f;

    // Pain sound cooldown – ed_babble.wav is ~2 seconds
    const float  EDGRUNT_PAIN_COOLDOWN  = 2.1f;

    // *** IMPORTANT ***
    // This is the animation event index used by the kick frame in the QC.
    // If the kick still does no damage, check the model in HLMV/HLAE and
    // change this to match the event number used there.
    const int    EDGRUNT_EVENT_KICK     = 2;

    // --------------------------------------------------------
    // Entity class
    // --------------------------------------------------------
    class CEdGrunt : ScriptBaseMonsterEntity
    {
        float m_flNextIdleSound;
        float m_flNextPainSound;
        float m_flNextAttackTime;
        int   m_iClip;
        bool  m_fReloading;
        bool  m_fHasAlerted;

        // ----------------------------------------------------
        // Precache resources
        // ----------------------------------------------------
        void Precache()
        {
            g_Game.PrecacheModel( EDGRUNT_MODEL );

            g_SoundSystem.PrecacheSound( SND_BABBLE );
            g_SoundSystem.PrecacheSound( SND_IDLE_A );
            g_SoundSystem.PrecacheSound( SND_IDLE_B );
            g_SoundSystem.PrecacheSound( SND_ALERT );
            g_SoundSystem.PrecacheSound( SND_PAINTBALL_1 );
            g_SoundSystem.PrecacheSound( SND_PAINTBALL_2 );

            g_SoundSystem.PrecacheSound( SND_KICK_HIT );
            g_SoundSystem.PrecacheSound( SND_BODY_THUD );

            BaseClass.Precache();
        }

        // ----------------------------------------------------
        // Spawn / setup
        // ----------------------------------------------------
        void Spawn()
        {
            Precache();

            g_EntityFuncs.SetModel( self, EDGRUNT_MODEL );
            g_EntityFuncs.SetSize( self.pev, VEC_HUMAN_HULL_MIN, VEC_HUMAN_HULL_MAX );

            self.pev.solid     = SOLID_SLIDEBOX;
            self.pev.movetype  = MOVETYPE_STEP;
            self.pev.health    = EDGRUNT_HEALTH;
            self.pev.yaw_speed = EDGRUNT_YAWSPEED;
            self.pev.flags    |= FL_MONSTER;
            self.m_bloodColor  = BLOOD_COLOR_RED;

            self.pev.view_ofs  = Vector( 0, 0, 68 );
            self.pev.fov       = EDGRUNT_FOV;

            self.m_afCapability = bits_CAP_DOORS_GROUP |
                                  bits_CAP_HEAR |
                                  bits_CAP_TURN_HEAD |
                                  bits_CAP_RANGE_ATTACK1;

            self.MonsterInit();

            m_iClip            = EDGRUNT_MP5_CLIP;
            m_fReloading       = false;
            m_fHasAlerted      = false;
            m_flNextIdleSound  = g_Engine.time + Math.RandomFloat( EDGRUNT_IDLE_MIN_DELAY, EDGRUNT_IDLE_MAX_DELAY );
            m_flNextPainSound  = 0.0f;
            m_flNextAttackTime = g_Engine.time;
        }

        // ----------------------------------------------------
        // Classification
        // ----------------------------------------------------
        int Classify()
        {
            return CLASS_ALIEN_MONSTER;
        }

        // ----------------------------------------------------
        // Sounds
        // ----------------------------------------------------
        void IdleSound()
        {
            if( g_Engine.time < m_flNextIdleSound )
                return;

            if( self.m_hEnemy.IsValid() )
                return;

            string snd = (Math.RandomLong(0,1) == 0) ? SND_IDLE_A : SND_IDLE_B;

            g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, snd,
                                        1.0f, ATTN_NORM, 0, PITCH_NORM );

            m_flNextIdleSound = g_Engine.time +
                                Math.RandomFloat( EDGRUNT_IDLE_MIN_DELAY, EDGRUNT_IDLE_MAX_DELAY );
        }

        void AlertSound()
        {
            g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, SND_ALERT,
                                        1.0f, ATTN_NORM, 0, PITCH_NORM );
        }

        void PainSound()
        {
            // Respect cooldown so ed_babble.wav can fully play and not spam
            if( g_Engine.time < m_flNextPainSound )
                return;

            g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, SND_BABBLE,
                                        1.0f, ATTN_NORM, 0, PITCH_NORM );

            // Next pain sound allowed after the clip length
            m_flNextPainSound = g_Engine.time + EDGRUNT_PAIN_COOLDOWN;
        }

        void DeathSound()
        {
            g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, SND_BABBLE,
                                        1.0f, ATTN_NORM, 0, PITCH_NORM );
        }

        // ----------------------------------------------------
        // Simple body thud after death
        // ----------------------------------------------------
        void BodyThud()
        {
            // If he's already been removed, this won't do anything
            if( self.pev.health <= 0 && self.pev.solid == SOLID_NOT )
            {
                g_SoundSystem.EmitSoundDyn(
                    self.edict(),
                    CHAN_BODY,
                    SND_BODY_THUD,
                    1.0f,
                    ATTN_NORM,
                    0,
                    PITCH_NORM
                );
            }
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

            // Play a body-thud a short moment after he dies (roughly
            // when the body hits the ground).
            g_Scheduler.SetTimeout( @this, "BodyThud", 0.7f );

            BaseClass.Killed( pevAttacker, iGib );
        }

        // ----------------------------------------------------
        // Range attack checks (when AI is allowed to fire)
        // ----------------------------------------------------
        bool CheckRangeAttack1( float flDot, float flDist )
        {
            if( !self.m_hEnemy.IsValid() )
                return false;

            if( flDist > EDGRUNT_MP5_RANGE )
                return false;

            if( flDot < 0.3f )
                return false;

            CBaseEntity@ pEnemy = self.m_hEnemy;
            if( pEnemy is null )
                return false;

            Vector vecEnemy = pEnemy.pev.origin + pEnemy.pev.view_ofs;
            if( !self.FVisible( vecEnemy ) )
                return false;

            if( g_Engine.time < m_flNextAttackTime )
                return false;

            return true;
        }

        // ----------------------------------------------------
        // Melee kick logic
        // ----------------------------------------------------
        void KickAttack()
        {
            CBaseEntity@ pEnemy = self.m_hEnemy;
            if( pEnemy is null || !pEnemy.IsAlive() )
                return;

            // Direction to enemy
            Vector vecToEnemy = pEnemy.pev.origin - self.pev.origin;
            float flDist = vecToEnemy.Length();
            vecToEnemy = vecToEnemy.Normalize();

            Math.MakeVectors( self.pev.angles );
            float flDot = DotProduct( vecToEnemy, g_Engine.v_forward );

            if( flDist <= EDGRUNT_KICK_RANGE && flDot > 0.7f )
            {
                pEnemy.TakeDamage( self.pev, self.pev, EDGRUNT_KICK_DAMAGE, DMG_CLUB );

                // Impact sound (HL-style melee impact)
                g_SoundSystem.EmitSoundDyn(
                    self.edict(),
                    CHAN_WEAPON,
                    SND_KICK_HIT,
                    1.0f,
                    ATTN_NORM,
                    0,
                    PITCH_NORM
                );
            }
        }

        // ----------------------------------------------------
        // Animation events -> firing gun or kicking
        // ----------------------------------------------------
        void HandleAnimEvent( MonsterEvent@ pEvent )
        {
            int ev = pEvent.event;

            if( ev == EDGRUNT_EVENT_KICK )
            {
                // Kick event from QC
                KickAttack();
                return;
            }

            switch( ev )
            {
                case 4:
                case 5:
                case 6:
                    ShootMP5();
                    break;

                default:
                    BaseClass.HandleAnimEvent( pEvent );
            }
        }

        // ----------------------------------------------------
        // Core MP5 firing (simple hitscan, aims at enemy, no grenades)
        // ----------------------------------------------------
        void ShootMP5()
        {
            if( !self.m_hEnemy.IsValid() )
                return;

            if( m_iClip <= 0 )
            {
                // simple virtual reload
                if( !m_fReloading )
                {
                    m_fReloading       = true;
                    m_flNextAttackTime = g_Engine.time + 1.5f;
                }

                if( g_Engine.time >= m_flNextAttackTime )
                {
                    m_iClip      = EDGRUNT_MP5_CLIP;
                    m_fReloading = false;
                }
                return;
            }

            CBaseEntity@ pEnemy = self.m_hEnemy;
            if( pEnemy is null )
                return;

            // muzzle origin from attachment 0
            Vector vecMuzzleOrigin, vecMuzzleAngles;
            self.GetAttachment( 0, vecMuzzleOrigin, vecMuzzleAngles );

            // aim straight at enemy body
            Vector vecTarget = pEnemy.BodyTarget( vecMuzzleOrigin );
            Vector vecDir    = (vecTarget - vecMuzzleOrigin).Normalize();

            // small spread (world-space wobble)
            float x = Math.RandomFloat( -EDGRUNT_MP5_SPREAD, EDGRUNT_MP5_SPREAD );
            float y = Math.RandomFloat( -EDGRUNT_MP5_SPREAD, EDGRUNT_MP5_SPREAD );
            vecDir  = (vecDir + Vector( x, y, 0 )).Normalize();

            // paintball sound
            string snd = (Math.RandomLong(0,1) == 0) ? SND_PAINTBALL_1 : SND_PAINTBALL_2;
            g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, snd,
                                        1.0f, ATTN_NORM, 0, PITCH_NORM );

            self.pev.effects |= EF_MUZZLEFLASH;

            // trace bullet
            TraceResult tr;
            g_Utility.TraceLine( vecMuzzleOrigin,
                                 vecMuzzleOrigin + vecDir * EDGRUNT_MP5_RANGE,
                                 dont_ignore_monsters,
                                 self.edict(),
                                 tr );

            if( tr.flFraction < 1.0f )
            {
                CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );

                if( pHit !is null && pHit.pev.takedamage != 0 )
                {
                    g_WeaponFuncs.ClearMultiDamage();
                    pHit.TraceAttack( self.pev, float(EDGRUNT_MP5_DAMAGE), vecDir, tr, DMG_BULLET );
                    g_WeaponFuncs.ApplyMultiDamage( self.pev, self.pev );
                }
                else
                {
                    // world impact decal
                    g_Utility.DecalTrace( tr, DECAL_GUNSHOT1 + Math.RandomLong(0,4) );
                }
            }

            m_iClip--;
            m_flNextAttackTime = g_Engine.time + Math.RandomFloat( 0.05f, 0.12f );
        }

        // ----------------------------------------------------
        // Think: extra behavior on top of base AI
        // ----------------------------------------------------
        void RunAI()
        {
            BaseClass.RunAI();

            // idle chatter when not in combat
            IdleSound();

            // simple first-time alert bark
            if( self.m_hEnemy.IsValid() )
            {
                if( !m_fHasAlerted )
                {
                    AlertSound();
                    m_fHasAlerted = true;
                }
            }
            else
            {
                m_fHasAlerted = false;
            }
        }
    }
} // namespace monster_edgrunt

// ------------------------------------------------------------
// Registration helper – call this from MapInit()
// ------------------------------------------------------------
void RegisterMonsterEdGrunt()
{
    g_CustomEntityFuncs.RegisterCustomEntity( "monster_edgrunt::CEdGrunt", "monster_edgrunt" );
}

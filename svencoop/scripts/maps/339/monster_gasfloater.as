// monster_gasfloater.as  (scripts/maps/339/monster_gasfloater.as)
//
// Sackrax gas floater ("Sackraxx"):
//  - Small "bouncing" head that moves toward players
//  - Leaves a visual poison smoke trail on the ground
//  - When close, performs a quick "shock" dash melee attack toward the player
//  - Physical damage ONLY during the pounce, so you can melee him safely otherwise

// ---------------------------------------------------------
// Assets
// ---------------------------------------------------------
const string GASFLOATER_MODEL       = "models/cyrax/sackrax.mdl";

// For green smoke: copy steam1.spr, recolor it green in Wally, save as
//   sprites/cyrax/steam_green.spr
// And point this to it once you have it. For now you’re using steam1.spr.
const string GASFLOATER_SMOKE_SPR   = "sprites/steam1.spr";

// Custom gib model for death
const string GASFLOATER_GIB_MODEL   = "models/cyrax/gib_lung.mdl";

// Sounds – change paths to whatever you like.
const string GASFLOATER_IDLE_SOUND  = "cyrax/monsters/sackrax_sing01.wav";   // optional
const string GASFLOATER_MOVE_SOUND  = "cyrax/monsters/sackrax_bounce1.wav";  // on each hop
const string GASFLOATER_HIT_SOUND   = "cyrax/monsters/squish.wav";           // melee hit
const string GASFLOATER_DIE_SOUND   = "cyrax/monsters/sackrax_die.wav";      // death

// ---------------------------------------------------------
// Tuning
// ---------------------------------------------------------

// Health
const float GASFLOATER_HEALTH           = 200.0f;

// Horizontal motion (idle bouncing locomotion)
const float GASFLOATER_HOP_SPEED        = 90.0f;
const float GASFLOATER_HOP_UP           = 170.0f;   // vertical impulse for real bounce
const float GASFLOATER_HOP_INTERVAL_MIN = 0.8f;
const float GASFLOATER_HOP_INTERVAL_MAX = 1.4f;

// Gas trail (visual only)
const float GASFLOATER_GAS_INTERVAL     = 0.35f;

// Melee / touch damage (only during pounce)
const float GASFLOATER_TOUCH_DAMAGE     = 15.0f;
const float GASFLOATER_TOUCH_KNOCK      = 220.0f;
const float GASFLOATER_TOUCH_COOLDOWN   = 0.6f;

// Pounce / dash attack tuning
const float GASFLOATER_POUNCE_RANGE     = 160.0f;   // start pounce when this close
const float GASFLOATER_POUNCE_SPEED     = 260.0f;   // dash horizontal speed
const float GASFLOATER_POUNCE_UP        = 120.0f;   // small jump up on pounce
const float GASFLOATER_POUNCE_DURATION  = 0.45f;    // how long the dash lasts
const float GASFLOATER_POUNCE_COOLDOWN  = 2.0f;     // time between pounces

// Think step
const float GASFLOATER_THINK_TIME       = 0.1f;

// Visual vertical fudge: how far to push him UP from the mapper's placement.
const float GASFLOATER_Z_FUDGE          = 64.0f;

// Yaw offset so he faces the right direction while moving
const float GASFLOATER_YAW_OFFSET       = 90.0f;

// Gibs on death
const int   GASFLOATER_NUM_GIBS         = 7;        // how many lungs to throw
const float GASFLOATER_GIB_LIFETIME     = 30.0f;    // seconds before they fade

// ---------------------------------------------------------

class monster_gasfloater : ScriptBaseMonsterEntity
{
    float m_flNextGasTime     = 0.0f;
    float m_flNextHopTime     = 0.0f;
    float m_flNextTouchTime   = 0.0f;

    // Pounce state
    bool  m_bPouncing         = false;
    float m_flPounceEndTime   = 0.0f;
    float m_flNextPounceTime  = 0.0f;

    // Cached "shock" sequence index
    int   m_iShockSeq         = -1;

    void Spawn()
    {
        Precache();

        g_EntityFuncs.SetModel( self, GASFLOATER_MODEL );

        // Simple hull around origin
        g_EntityFuncs.SetSize(
            self.pev,
            Vector( -8, -8, -8 ),
            Vector(  8,  8, 16 ) );

        self.pev.movetype   = MOVETYPE_STEP;
        self.pev.solid      = SOLID_SLIDEBOX;
        self.pev.flags     |= FL_MONSTER;
        self.pev.takedamage = DAMAGE_AIM;

        self.m_bloodColor   = BLOOD_COLOR_RED;
        self.pev.health     = GASFLOATER_HEALTH;
        self.pev.max_health = self.pev.health;

        self.pev.gravity    = 0.8f;  // real gravity / bouncing
        self.pev.friction   = 1.0f;

        self.m_afCapability = 0;
        self.SetClassification( CLASS_ALIEN_MONSTER );

        // UI display name
        self.m_FormattedName = "Sackraxx";

        // Use idle sequence if it exists
        int idleSeq = self.LookupSequence( "idle" );
        if ( idleSeq == -1 )
            idleSeq = self.LookupSequence( "idle1" );
        if ( idleSeq != -1 )
        {
            self.pev.sequence = idleSeq;
            self.pev.frame    = 0;
            self.ResetSequenceInfo();
        }

        // Cache shock sequence index for pounce anim
        m_iShockSeq = self.LookupSequence( "shock" );

        self.MonsterInit();

        // Shove him up so he floats visually where you tuned him
        self.pev.origin.z += GASFLOATER_Z_FUDGE;

        m_flNextGasTime     = g_Engine.time + GASFLOATER_GAS_INTERVAL;
        m_flNextHopTime     = g_Engine.time + Math.RandomFloat(
            GASFLOATER_HOP_INTERVAL_MIN, GASFLOATER_HOP_INTERVAL_MAX );
        m_flNextTouchTime   = 0.0f;
        m_flNextPounceTime  = g_Engine.time + 1.0f;

        SetThink( ThinkFunction( GasFloaterThink ) );
        self.pev.nextthink = g_Engine.time + GASFLOATER_THINK_TIME;
    }

    void Precache()
    {
        g_Game.PrecacheModel( GASFLOATER_MODEL );
        g_Game.PrecacheModel( GASFLOATER_SMOKE_SPR );
        g_Game.PrecacheModel( GASFLOATER_GIB_MODEL );

        g_SoundSystem.PrecacheSound( GASFLOATER_IDLE_SOUND );
        g_SoundSystem.PrecacheSound( GASFLOATER_MOVE_SOUND );
        g_SoundSystem.PrecacheSound( GASFLOATER_HIT_SOUND );
        g_SoundSystem.PrecacheSound( GASFLOATER_DIE_SOUND );
    }

    // -----------------------------------------------------
    // Main think – hop + gas trail + pounce logic
    // -----------------------------------------------------
    void GasFloaterThink()
    {
        // Gas puffs (visual only)
        if ( g_Engine.time >= m_flNextGasTime )
        {
            DropGasPuff();
            m_flNextGasTime = g_Engine.time + GASFLOATER_GAS_INTERVAL;
        }

        // If currently pouncing, handle pounce timing / end
        if ( m_bPouncing )
        {
            if ( g_Engine.time >= m_flPounceEndTime )
            {
                // End pounce, let normal hopping resume
                m_bPouncing = false;
            }
        }
        else
        {
            // Not pouncing: idle hop behavior
            if ( ( self.pev.flags & FL_ONGROUND ) != 0 &&
                 g_Engine.time >= m_flNextHopTime )
            {
                HopTowardPlayer();
                m_flNextHopTime = g_Engine.time + Math.RandomFloat(
                    GASFLOATER_HOP_INTERVAL_MIN, GASFLOATER_HOP_INTERVAL_MAX );
            }

            // Try to start a pounce if close enough to player
            TryStartPounce();
        }

        self.StudioFrameAdvance( 0.1f );
        self.pev.nextthink = g_Engine.time + GASFLOATER_THINK_TIME;
    }

    // -----------------------------------------------------
    // Simple hop locomotion (slow bouncing movement)
    // -----------------------------------------------------
    void HopTowardPlayer()
    {
        CBasePlayer@ pTarget = FindNearestPlayer( 1024.0f );
        Vector dir( 0, 0, 0 );

        if ( pTarget !is null )
        {
            dir = pTarget.pev.origin - self.pev.origin;
            dir.z = 0.0f;
            float len = dir.Length();
            if ( len > 0.0f )
                dir = dir * ( 1.0f / len );
        }
        else
        {
            dir = Vector(
                Math.RandomFloat( -1.0f, 1.0f ),
                Math.RandomFloat( -1.0f, 1.0f ),
                0.0f );
            dir = dir.Normalize();
        }

        self.pev.velocity.x = dir.x * GASFLOATER_HOP_SPEED;
        self.pev.velocity.y = dir.y * GASFLOATER_HOP_SPEED;
        self.pev.velocity.z = GASFLOATER_HOP_UP;

        // Apply yaw offset so he visually faces the direction of travel
        self.pev.angles.y = Math.VecToYaw( dir ) + GASFLOATER_YAW_OFFSET;

        g_SoundSystem.EmitSoundDyn(
            self.edict(), CHAN_BODY,
            GASFLOATER_MOVE_SOUND,
            0.8f, ATTN_IDLE, 0, 100 );
    }

    // -----------------------------------------------------
    // Gas puff – visual smoke only (NO damage here now)
    // -----------------------------------------------------
    void DropGasPuff()
    {
        Vector pos = self.pev.origin;

        int sprIndex = g_EngineFuncs.ModelIndex( GASFLOATER_SMOKE_SPR );

        NetworkMessage smoke( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, pos );
            smoke.WriteByte( TE_SMOKE );
            smoke.WriteCoord( pos.x );
            smoke.WriteCoord( pos.y );
            smoke.WriteCoord( pos.z );
            smoke.WriteShort( sprIndex );
            smoke.WriteByte( 15 );  // scale
            smoke.WriteByte( 8 );   // framerate
        smoke.End();

        // If you want lingering poison pools later, you can
        // spawn a separate small entity here that lives a few seconds
        // and deals damage over time in its radius.
    }

    // -----------------------------------------------------
    // Pounce logic – quick dash + "shock" animation
    // -----------------------------------------------------
    void TryStartPounce()
    {
        if ( g_Engine.time < m_flNextPounceTime )
            return;

        CBasePlayer@ pPlr = FindNearestPlayer( 512.0f );
        if ( pPlr is null || !pPlr.IsAlive() )
            return;

        Vector toPlr = pPlr.pev.origin - self.pev.origin;
        float dist2D = Vector( toPlr.x, toPlr.y, 0 ).Length();

        if ( dist2D > GASFLOATER_POUNCE_RANGE )
            return;

        // Start pounce
        Vector dir = Vector( toPlr.x, toPlr.y, 0 );
        float len = dir.Length();
        if ( len <= 0.0f )
            return;

        dir = dir * ( 1.0f / len );

        // Strong dash toward player
        self.pev.velocity.x = dir.x * GASFLOATER_POUNCE_SPEED;
        self.pev.velocity.y = dir.y * GASFLOATER_POUNCE_SPEED;
        self.pev.velocity.z = GASFLOATER_POUNCE_UP;

        self.pev.angles.y = Math.VecToYaw( dir ) + GASFLOATER_YAW_OFFSET;

        m_bPouncing        = true;
        m_flPounceEndTime  = g_Engine.time + GASFLOATER_POUNCE_DURATION;
        m_flNextPounceTime = g_Engine.time + GASFLOATER_POUNCE_COOLDOWN;

        // Play shock animation if it exists
        if ( m_iShockSeq >= 0 )
        {
            self.pev.sequence  = m_iShockSeq;
            self.pev.frame     = 0;
            self.pev.framerate = 1.5f; // a bit snappier
            self.ResetSequenceInfo();
        }
    }

    // -----------------------------------------------------
    // Touch: physical bonk damage + knockback ONLY during pounce
    // -----------------------------------------------------
    void Touch( CBaseEntity@ pOther )
    {
        if ( pOther is null || !pOther.IsPlayer() )
            return;

        // Only deal melee damage when we are actively pouncing
        if ( !m_bPouncing )
            return;

        if ( g_Engine.time < m_flNextTouchTime )
            return;

        m_flNextTouchTime = g_Engine.time + GASFLOATER_TOUCH_COOLDOWN;

        pOther.TakeDamage(
            self.pev, self.pev,
            GASFLOATER_TOUCH_DAMAGE,
            DMG_CLUB | DMG_POISON );

        Vector dir = ( pOther.pev.origin - self.pev.origin ).Normalize();
        pOther.pev.velocity = pOther.pev.velocity + dir * GASFLOATER_TOUCH_KNOCK;

        g_SoundSystem.EmitSoundDyn(
            self.edict(), CHAN_WEAPON,
            GASFLOATER_HIT_SOUND,
            1.0f, ATTN_NORM, 0, 100 );

        // Once we slam into a player, end this pounce
        m_bPouncing = false;
    }

    // -----------------------------------------------------
    // Death – custom lung gibs + sound, then remove
    // -----------------------------------------------------
    void Killed( entvars_t@ pevAttacker, int iGib )
    {
        // Avoid double-death
        if ( self.pev.deadflag == DEAD_DEAD )
            return;

        // Death sound
        g_SoundSystem.EmitSoundDyn(
            self.edict(), CHAN_VOICE,
            GASFLOATER_DIE_SOUND,
            1.0f, ATTN_NORM, 0, 100 );

        // Spawn custom lung gibs
        for ( int i = 0; i < GASFLOATER_NUM_GIBS; ++i )
        {
            Vector gibOrg = self.pev.origin;
            gibOrg.x += Math.RandomFloat( -8.0f, 8.0f );
            gibOrg.y += Math.RandomFloat( -8.0f, 8.0f );
            gibOrg.z += Math.RandomFloat( 0.0f, 8.0f );

            Vector gibAngles( 0, Math.RandomFloat( 0, 360 ), 0 );

            CGib@ pGib = g_EntityFuncs.CreateGib( gibOrg, gibAngles );
            if ( pGib !is null )
            {
                pGib.Spawn( GASFLOATER_GIB_MODEL );
                pGib.pev.velocity = Vector(
                    Math.RandomFloat( -120.0f, 120.0f ),
                    Math.RandomFloat( -120.0f, 120.0f ),
                    Math.RandomFloat( 120.0f, 220.0f ) );

                pGib.m_bloodColor    = BLOOD_COLOR_RED;
                pGib.m_cBloodDecals  = 4;
                pGib.m_lifeTime      = GASFLOATER_GIB_LIFETIME;
            }
        }

        self.pev.solid      = SOLID_NOT;
        self.pev.takedamage = DAMAGE_NO;
        self.pev.deadflag   = DEAD_DEAD;

        g_EntityFuncs.Remove( self );
    }

    // -----------------------------------------------------
    // Helper: nearest alive player (returns CBasePlayer@)
    // -----------------------------------------------------
    CBasePlayer@ FindNearestPlayer( float flMaxDist )
    {
        CBasePlayer@ pBest = null;
        float bestDistSq = flMaxDist * flMaxDist;

        for ( int i = 1; i <= g_Engine.maxClients; ++i )
        {
            CBasePlayer@ pPlr = g_PlayerFuncs.FindPlayerByIndex( i );
            if ( pPlr is null || !pPlr.IsConnected() || !pPlr.IsAlive() )
                continue;

            Vector d = pPlr.Center() - self.Center();
            float dsq = d.x*d.x + d.y*d.y + d.z*d.z;
            if ( dsq < bestDistSq )
            {
                bestDistSq = dsq;
                @pBest = pPlr;
            }
        }

        return pBest;
    }
}

// Registration function
void RegisterMonster_GasFloater()
{
    g_CustomEntityFuncs.RegisterCustomEntity(
        "monster_gasfloater", "monster_gasfloater" );
}

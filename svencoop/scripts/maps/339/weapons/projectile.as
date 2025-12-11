#include "../tempents"

// ---------------------------
// Q1-style grenade projectile
// ---------------------------
class projectile_qgrenade : ScriptBaseEntity
{
    float m_fExplodeTime;

    void Spawn()
    {
        // Precaches for this projectile
        g_SoundSystem.PrecacheSound( "cyrax/weapons/bounce.wav" );

        g_EntityFuncs.SetModel( self, "models/cyrax/grenade.mdl" );
        g_EntityFuncs.SetSize( self.pev,
            Vector( -0.5, -0.5, -0.5 ),
            Vector(  0.5,  0.5,  0.5 ) );
        g_EntityFuncs.SetOrigin( self, self.pev.origin );

        m_fExplodeTime = g_Engine.time + 3.0f;

        self.pev.movetype   = MOVETYPE_BOUNCE;
        self.pev.solid      = SOLID_BBOX;
        self.pev.nextthink  = g_Engine.time + 2.5f;
        self.pev.avelocity  = Vector( 300, 300, 300 );

        SetThink( ThinkFunction( Explode ) );
    }

    void Explode()
    {
        q1_Explode( self, self.pev.dmg );
        g_EntityFuncs.Remove( self );
    }

    void Touch( CBaseEntity@ pOther )
    {
        // World / owner bounce logic
        if ( pOther is null || pOther.IsBSPModel() || pOther.edict() is self.pev.owner )
        {
            if ( self.pev.velocity.Length() > 15.0f )
            {
                g_SoundSystem.EmitSoundDyn(
                    self.edict(), CHAN_AUTO,
                    "cyrax/weapons/bounce.wav",
                    1.0f, ATTN_NORM, 0, 100 );
            }
            else
            {
                self.pev.angles.x  = 0.0f;
                self.pev.avelocity = g_vecZero;
            }

            self.pev.velocity = self.pev.velocity * 0.5f;
            return;
        }

        Explode();
    }
}

// ---------------------------
// Q1-style rocket projectile
// ---------------------------
class projectile_qrocket : ScriptBaseEntity
{
    float m_fExplodeTime;

    void Spawn()
    {
        g_EntityFuncs.SetModel( self, "models/cyrax/rocket.mdl" );
        g_EntityFuncs.SetSize( self.pev, g_vecZero, g_vecZero );
        g_EntityFuncs.SetOrigin( self, self.pev.origin );

        m_fExplodeTime = g_Engine.time + 10.0f;

        self.pev.movetype   = MOVETYPE_FLYMISSILE;
        self.pev.solid      = SOLID_BBOX;
        self.pev.effects   |= EF_DIMLIGHT;

        self.pev.nextthink  = g_Engine.time + 10.0f;
        SetThink( ThinkFunction( Explode ) );
    }

    void Explode()
    {
        q1_Explode( self, self.pev.dmg );
        g_EntityFuncs.Remove( self );
    }

    void Touch( CBaseEntity@ pOther )
    {
        Explode();
    }
}

// ---------------------------
// Flying meat (zombie projectile)
// ---------------------------
class projectile_qmeat : ScriptBaseEntity
{
    float m_fExplodeTime;

    void Spawn()
    {
        // Precaches for this projectile
        g_SoundSystem.PrecacheSound( "cyrax/monsters/zombie/hit.wav" );
        g_SoundSystem.PrecacheSound( "cyrax/monsters/zombie/miss.wav" );

        g_EntityFuncs.SetModel( self, "models/cyrax/zombiegib.mdl" );

        m_fExplodeTime      = g_Engine.time + 5.0f;
        self.pev.movetype   = MOVETYPE_BOUNCE;
        self.pev.solid      = SOLID_BBOX;
        self.pev.mins       = Vector( -1, -1, -1 );
        self.pev.maxs       = Vector(  1,  1,  1 );
        self.pev.nextthink  = g_Engine.time + 0.1f;
        self.pev.avelocity  = Vector( 3000, 1000, 2000 );
    }

    void Explode()
    {
        g_EntityFuncs.Remove( self );
    }

    void Think()
    {
        q1_TE_BloodStream( self.pev.origin, ( -self.pev.velocity ).Normalize(), 73 );

        if ( g_Engine.time >= m_fExplodeTime )
            Explode();
        else
            self.pev.nextthink = g_Engine.time + 0.1f;
    }

    void Touch( CBaseEntity@ pOther )
    {
        if ( pOther is g_EntityFuncs.Instance( self.pev.owner ) )
            return;

        if ( pOther !is null && !pOther.IsBSPModel() && pOther.pev.takedamage != 0 )
        {
            pOther.TakeDamage( self.pev, self.pev.owner.vars, self.pev.dmg, DMG_GENERIC );
            g_SoundSystem.EmitSoundDyn(
                self.edict(), CHAN_AUTO,
                "cyrax/monsters/zombie/hit.wav",
                1.0f, ATTN_NORM, 0, 100 );
        }
        else
        {
            g_SoundSystem.EmitSoundDyn(
                self.edict(), CHAN_AUTO,
                "cyrax/monsters/zombie/miss.wav",
                1.0f, ATTN_NORM, 0, 100 );
        }

        Explode();
    }
}

// ---------------------------
// Scrag spike projectile
// ---------------------------
class projectile_qscragspike : ScriptBaseEntity
{
    float m_fExplodeTime;
    Vector m_vecStart;

    void Spawn()
    {
        // Precaches for Scrag spike usage
        g_SoundSystem.PrecacheSound( "cyrax/monsters/scrag/hit.wav" );
        g_SoundSystem.PrecacheSound( "cyrax/monsters/scrag/shoot.wav" );

        g_EntityFuncs.SetModel( self, "models/cyrax/spike.mdl" );

        m_fExplodeTime      = g_Engine.time + 5.0f;
        self.pev.movetype   = MOVETYPE_FLYMISSILE;
        self.pev.solid      = SOLID_BBOX;
        self.pev.angles     = Math.VecToAngles( self.pev.velocity );
        m_vecStart          = self.pev.origin;

        g_EntityFuncs.SetSize(
            self.pev,
            Vector( -0.5f, -0.5f, -0.5f ),
            Vector(  0.5f,  0.5f,  0.5f ) );

        self.pev.nextthink  = g_Engine.time + 0.1f;
    }

    void Think()
    {
        if ( m_fExplodeTime < g_Engine.time )
        {
            g_EntityFuncs.Remove( self );
            return;
        }

        q1_TE_BloodStream( self.pev.origin, ( -self.pev.velocity ).Normalize() );

        self.pev.angles     = Math.VecToAngles( self.pev.velocity );
        self.pev.nextthink  = g_Engine.time + 0.1f;
    }

    void Touch( CBaseEntity@ pOther )
    {
        if ( pOther is g_EntityFuncs.Instance( self.pev.owner ) )
            return;

        // -----------------------------------------
        // IMPORTANT: don't damage Nihilrax
        // -----------------------------------------
        bool bIgnoreDamage = false;

        if ( pOther !is null && pOther.GetClassname() == "monster_nihilrax" )
        {
            // We can still play a hit sound for feedback, but do no damage.
            bIgnoreDamage = true;
        }

        g_SoundSystem.EmitSoundDyn(
            self.edict(), CHAN_AUTO,
            "cyrax/monsters/scrag/hit.wav",
            1.0f, ATTN_NORM, 0, 100 );

        if ( !bIgnoreDamage &&
             pOther !is null &&
             !pOther.IsBSPModel() &&
             pOther.pev.takedamage != 0 )
        {
            g_WeaponFuncs.SpawnBlood( self.pev.origin, pOther.BloodColor(), self.pev.dmg );
            pOther.TakeDamage( self.pev, self.pev.owner.vars, self.pev.dmg, DMG_GENERIC );
        }

        g_EntityFuncs.Remove( self );
    }
}

// ---------------------------
// Simple spike projectile
// ---------------------------
class projectile_qspike : ScriptBaseEntity
{
    void Spawn()
    {
        // Precaches for this projectile
        g_SoundSystem.PrecacheSound( "cyrax/weapons/tink1.wav" );

        g_EntityFuncs.SetModel( self, "models/cyrax/spike.mdl" );

        self.pev.movetype   = MOVETYPE_FLYMISSILE;
        self.pev.solid      = SOLID_BBOX;
        g_EntityFuncs.SetSize( self.pev, g_vecZero, g_vecZero );
        self.pev.nextthink  = g_Engine.time + 10.0f;
    }

    void Think()
    {
        g_EntityFuncs.Remove( self );
    }

    void Touch( CBaseEntity@ pOther )
    {
        if ( pOther is g_EntityFuncs.Instance( self.pev.owner ) )
            return;

        if ( pOther !is null && !pOther.IsBSPModel() && pOther.pev.takedamage != 0 )
        {
            pOther.TakeDamage( self.pev, self.pev.owner.vars, self.pev.dmg, DMG_GENERIC );
            g_WeaponFuncs.SpawnBlood( self.pev.origin, pOther.BloodColor(), self.pev.dmg );
        }
        else
        {
            g_SoundSystem.EmitSoundDyn(
                self.edict(), CHAN_AUTO,
                "cyrax/weapons/tink1.wav",
                1.0f, ATTN_NORM, 0, 100 );
            g_Utility.Sparks( self.pev.origin );

            if ( pOther !is null && pOther.pev.takedamage != 0 )
                pOther.TakeDamage( self.pev, self.pev.owner.vars, self.pev.dmg, DMG_GENERIC );
        }

        g_EntityFuncs.Remove( self );
    }
}

// ---------------------------
// Explosion + radius damage helpers
// ---------------------------
void q1_RadiusDamage( Vector vecCenter, CBaseEntity@ pInflictor, CBaseEntity@ pAttacker,
                      float flDamage, float flRadius, int bitsDamage )
{
    array<CBaseEntity@> aEnts(32);
    int iNum = g_EntityFuncs.MonstersInSphere( aEnts, vecCenter, flRadius );

    for ( int i = 0; i < iNum; ++i )
    {
        CBaseEntity@ pEnt = aEnts[i];
        if ( pEnt.pev.takedamage != 0 && pEnt !is pInflictor )
        {
            Vector vecOrg = pEnt.pev.origin + ( pEnt.pev.mins + pEnt.pev.maxs ) * 0.5f;

            TraceResult tr;
            g_Utility.TraceLine( vecCenter, vecOrg,
                                 ignore_monsters, dont_ignore_glass,
                                 pInflictor.edict(), tr );
            if ( tr.flFraction <= 0.999f )
                continue;

            float flPoints = ( vecOrg - vecCenter ).Length() * 0.5f;
            if ( flPoints < 0 ) flPoints = 0;

            flPoints = flDamage - flPoints;
            if ( pEnt is pAttacker )
                flPoints *= 0.5f;

            if ( flPoints > 0 )
            {
                if ( pEnt.GetClassname() == "monster_qshambler" )
                    pEnt.TakeDamage( pInflictor.pev, pAttacker.pev, flPoints * 0.5f, bitsDamage );
                else
                    pEnt.TakeDamage( pInflictor.pev, pAttacker.pev, flPoints, bitsDamage );
            }
        }
    }
}

void q1_Explode( CBaseEntity@ proj, float dmg )
{
    // Fake explosion
    g_EntityFuncs.CreateExplosion(
        proj.pev.origin, proj.pev.angles,
        proj.pev.owner, 64.0f, false );

    // Quake-like radius damage
    q1_RadiusDamage(
        proj.pev.origin,
        proj,
        g_EntityFuncs.Instance( proj.pev.owner ),
        dmg, 140.0f, DMG_BLAST );

    // Alert nearby monsters
    q1_AlertMonsters( g_EntityFuncs.Instance( proj.pev.owner ),
                      proj.pev.origin, 1600.0f );
}

// ---------------------------
// Generic projectile spawner
// ---------------------------
CBaseEntity@ q1_ShootCustomProjectile( string classname, string mdl,
                                       Vector ori, Vector vel,
                                       Vector angles, CBaseEntity@ owner )
{
    if ( classname.Length() == 0 )
        return null;

    dictionary keys;
    Vector boltAngles = angles * Vector( -1, 1, 1 );
    keys[ "origin"  ] = ori.ToString();
    keys[ "angles"  ] = boltAngles.ToString();
    keys[ "velocity"] = vel.ToString();

    string model = mdl.Length() > 0 ? mdl : "models/error.mdl";
    keys[ "model" ] = model;

    if ( mdl.Length() == 0 )
        keys[ "rendermode" ] = "1"; // invisible

    CBaseEntity@ shootEnt = g_EntityFuncs.CreateEntity( classname, keys, false );
    @shootEnt.pev.owner   = owner.edict();

    g_EntityFuncs.DispatchSpawn( shootEnt.edict() );

    return shootEnt;
}

// ---------------------------
// Scrag spike helpers
// ---------------------------
void q1_ScragDelayedSpike( EHandle hOwner, EHandle hEnemy,
                           Vector vecSrc, Vector vecOffset )
{
    if ( !hOwner || !hEnemy )
        return;

    CBaseEntity@ pOwner = hOwner.GetEntity();
    CBaseEntity@ pEnemy = hEnemy.GetEntity();

    if ( pOwner is null || pEnemy is null || pOwner.pev.health <= 0 )
        return;

    pOwner.pev.effects |= EF_MUZZLEFLASH;

    Vector dst = pEnemy.pev.origin - vecOffset;
    Vector vec = ( dst - vecSrc ).Normalize();

    g_SoundSystem.EmitSoundDyn(
        pOwner.edict(), CHAN_VOICE,
        "cyrax/monsters/scrag/shoot.wav",
        1.0f, ATTN_NORM, 0, 100 );

    CBaseEntity@ pBolt = q1_ShootCustomProjectile(
        "projectile_qscragspike",
        "models/cyrax/spike.mdl",
        vecSrc, vec * 600.0f,
        Math.VecToAngles( vec ), pOwner );

    if ( pBolt !is null )
        pBolt.pev.dmg = 9.0f;
}

void q1_ScragDelaySpike( CBaseEntity@ pOwner, CBaseEntity@ pEnemy,
                         Vector vecSrc, Vector vecOffset, float time )
{
    g_Scheduler.SetTimeout(
        "q1_ScragDelayedSpike", time,
        EHandle( @pOwner ), EHandle( @pEnemy ),
        vecSrc, vecOffset );
}

// ---------------------------
// Zombie meat missile helper
// ---------------------------
void q1_ZombieMissile( CBaseEntity@ pOwner, CBaseEntity@ pEnemy,
                       Vector vecOrigin, Vector vecOffset )
{
    g_EngineFuncs.MakeVectors( pOwner.pev.angles );

    Vector vecOrg = vecOrigin
        + vecOffset.x * g_Engine.v_forward
        + vecOffset.y * g_Engine.v_right
        + ( vecOffset.z - 24.0f ) * g_Engine.v_up;

    Vector vecVelocity = ( pEnemy.EyePosition() - vecOrg ).Normalize() * 600.0f;
    vecVelocity.z = 200.0f;

    CBaseEntity@ pBolt = q1_ShootCustomProjectile(
        "projectile_qmeat",
        "models/cyrax/zombiegib.mdl",
        vecOrg, vecVelocity,
        Math.VecToAngles( vecVelocity ), pOwner );

    if ( pBolt !is null )
        pBolt.pev.dmg = 10.0f;
}

// ---------------------------
// Registration
// ---------------------------
void q1_RegisterProjectiles()
{
    g_CustomEntityFuncs.RegisterCustomEntity(
        "projectile_qgrenade", "projectile_qgrenade" );
    g_CustomEntityFuncs.RegisterCustomEntity(
        "projectile_qrocket", "projectile_qrocket" );
    g_CustomEntityFuncs.RegisterCustomEntity(
        "projectile_qspike", "projectile_qspike" );
    g_CustomEntityFuncs.RegisterCustomEntity(
        "projectile_qscragspike", "projectile_qscragspike" );
    g_CustomEntityFuncs.RegisterCustomEntity(
        "projectile_qmeat", "projectile_qmeat" );
}

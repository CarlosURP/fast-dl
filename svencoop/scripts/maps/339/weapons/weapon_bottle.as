/* 
* Bottle melee weapon – based on weapon_hlcrowbar.as by Sidewinder
*/

enum bottle
{
    BOTTLE_IDLE = 0,
    BOTTLE_DRAW,
    BOTTLE_HOLSTER,
    BOTTLE_ATTACK1HIT,
    BOTTLE_ATTACK1MISS,
    BOTTLE_ATTACK2MISS,
    BOTTLE_ATTACK2HIT,
    BOTTLE_ATTACK3MISS,
    BOTTLE_ATTACK3HIT
};

class weapon_bottle : ScriptBasePlayerWeaponEntity
{
    private CBasePlayer@ m_pPlayer = null;
    
    int m_iSwing = 0;
    TraceResult m_trHit;
    
    void Spawn()
    {
        self.Precache();

        // World model (pickup)
        g_EntityFuncs.SetModel( self, self.GetW_Model( "models/cyrax/wpn/w_bottle.mdl" ) );

        self.m_iClip       = -1;
        self.m_flCustomDmg = self.pev.dmg;

        self.FallInit(); // get ready to fall down.
    }

    void Precache()
    {
        self.PrecacheCustomModels();

        // View + world model
        g_Game.PrecacheModel( "models/cyrax/wpn/v_liqourbottle.mdl" );
        g_Game.PrecacheModel( "models/cyrax/wpn/w_bottle.mdl" );

        // Sounds actually used in the script
        g_SoundSystem.PrecacheSound( "weapons/knife_hit_flesh1.wav" );
        g_SoundSystem.PrecacheSound( "weapons/knife_hit_flesh2.wav" );
        g_SoundSystem.PrecacheSound( "weapons/knife_hit_wall1.wav" );
        g_SoundSystem.PrecacheSound( "weapons/knife3.wav" );
        g_SoundSystem.PrecacheSound( "debris/glass1.wav" );
        g_SoundSystem.PrecacheSound( "bat_deploy1.wav" );

        g_Game.PrecacheGeneric( "sprites/cyrax/weapon_bottle.txt" );
    }

    bool GetItemInfo( ItemInfo& out info )
    {
        info.iMaxAmmo1 = -1;
        info.iMaxAmmo2 = -1;
        info.iMaxClip  = WEAPON_NOCLIP;
        info.iSlot     = 0;
        info.iPosition = 9;
        info.iWeight   = 0;
        return true;
    }
    
    bool AddToPlayer( CBasePlayer@ pPlayer )
    {
        if( !BaseClass.AddToPlayer( pPlayer ) )
            return false;
            
        @m_pPlayer = pPlayer;
        return true;
    }

    float WeaponTimeBase()
    {
        return g_Engine.time;
    }

    bool Deploy()
    {
        g_SoundSystem.EmitSoundDyn(
            m_pPlayer.edict(), CHAN_VOICE,
            "bat_deploy1.wav", 1.0f, ATTN_NORM, 0, PITCH_NORM
        );

        // Make third-person model invisible by using an empty P-model string.
        return self.DefaultDeploy(
            self.GetV_Model( "models/cyrax/wpn/v_liqourbottle.mdl" ),
            "", // no visible third-person model
            BOTTLE_DRAW,
            "crowbar" // use crowbar player animations
        );
    }

    void Holster( int skiplocal /* = 0 */ )
    {
        self.m_fInReload = false; // cancel any reload in progress.

        m_pPlayer.m_flNextAttack = WeaponTimeBase() + 0.5f; 

        // Clear viewmodel on holster
        m_pPlayer.pev.viewmodel = "";
        
        SetThink( null );
    }

    void ItemPreFrame()
    {
        BaseClass.ItemPreFrame();
    }

    void ItemPostFrame()
    {
        BaseClass.ItemPostFrame();
    }
    
    void PrimaryAttack()
    {
        if( !Swing( 1 ) )
        {
            SetThink( ThinkFunction( this.SwingAgain ) );
            self.pev.nextthink = g_Engine.time + 0.1f;
        }
    }
    
    void Smack()
    {
        g_WeaponFuncs.DecalGunshot( m_trHit, BULLET_PLAYER_CROWBAR );
    }

    void SwingAgain()
    {
        Swing( 0 );
    }

    bool Swing( int fFirst )
    {
        bool fDidHit = false;

        TraceResult tr;

        Math.MakeVectors( m_pPlayer.pev.v_angle );
        Vector vecSrc = m_pPlayer.GetGunPosition();
        Vector vecEnd = vecSrc + g_Engine.v_forward * 32;

        g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

        if( tr.flFraction >= 1.0f )
        {
            g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr );
            if( tr.flFraction < 1.0f )
            {
                CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
                if( pHit is null || pHit.IsBSPModel() )
                    g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, m_pPlayer.edict() );
                vecEnd = tr.vecEndPos;
            }
        }

        if( tr.flFraction >= 1.0f )
        {
            if( fFirst != 0 )
            {
                // miss
                switch( ( m_iSwing++ ) % 3 )
                {
                    case 0: self.SendWeaponAnim( BOTTLE_ATTACK1MISS ); break;
                    case 1: self.SendWeaponAnim( BOTTLE_ATTACK2MISS ); break;
                    case 2: self.SendWeaponAnim( BOTTLE_ATTACK3MISS ); break;
                }

                self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.5f;

                g_SoundSystem.EmitSoundDyn(
                    m_pPlayer.edict(), CHAN_WEAPON,
                    "weapons/knife3.wav", 1.0f, ATTN_NORM, 0,
                    94 + Math.RandomLong( 0, 0xF )
                );

                m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 
            }
        }
        else
        {
            // hit
            fDidHit = true;
            
            CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

            // simple alternation between hit anims
            switch( ( m_iSwing++ ) % 3 )
            {
                case 0: self.SendWeaponAnim( BOTTLE_ATTACK1HIT ); break;
                case 1: self.SendWeaponAnim( BOTTLE_ATTACK2HIT ); break;
                case 2: self.SendWeaponAnim( BOTTLE_ATTACK3HIT ); break;
            }

            m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 

            float flDamage = 10.0f;
            if( self.m_flCustomDmg > 0 )
                flDamage = self.m_flCustomDmg;

            g_WeaponFuncs.ClearMultiDamage();

            if( self.m_flNextPrimaryAttack + 1 < WeaponTimeBase() )
                pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_CLUB | DMG_NEVERGIB );
            else
                pEntity.TraceAttack( m_pPlayer.pev, flDamage * 0.75f, g_Engine.v_forward, tr, DMG_CLUB | DMG_NEVERGIB );

            g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

            float flVol = 1.0f;
            bool fHitWorld = true;

            if( pEntity !is null )
            {
                self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.30f;

                if( pEntity.Classify() != CLASS_NONE && pEntity.Classify() != CLASS_MACHINE && pEntity.BloodColor() != DONT_BLEED )
                {
                    if( pEntity.IsPlayer() )
                        pEntity.pev.velocity = pEntity.pev.velocity + ( self.pev.origin - pEntity.pev.origin ).Normalize() * 120;

                    // flesh hit + glass
                    switch( Math.RandomLong( 0, 1 ) )
                    {
                        case 0:
                        {
                            g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "weapons/knife_hit_flesh1.wav", 1.0f, ATTN_NORM );
                            g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, "debris/glass1.wav", 0.5f, ATTN_NORM, 0, 90 + Math.RandomLong( -5, 5 ) );
                        }
                        break;
                        case 1:
                        {
                            g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "weapons/knife_hit_flesh2.wav", 1.0f, ATTN_NORM );
                            g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, "debris/glass1.wav", 0.5f, ATTN_NORM, 0, 90 + Math.RandomLong( -5, 5 ) );
                        }
                        break;
                    }

                    m_pPlayer.m_iWeaponVolume = 128; 
                    if( !pEntity.IsAlive() )
                        return true;
                    else
                        flVol = 0.1f;

                    fHitWorld = false;
                }
            }

            if( fHitWorld == true )
            {
                float fvolbar = g_SoundSystem.PlayHitSound(
                    tr,
                    vecSrc,
                    vecSrc + ( vecEnd - vecSrc ) * 2,
                    BULLET_PLAYER_CROWBAR
                );
                
                self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.25f;
                
                fvolbar = 1.0f;

                g_SoundSystem.EmitSoundDyn(
                    m_pPlayer.edict(), CHAN_WEAPON,
                    "weapons/knife_hit_wall1.wav",
                    1.0f, ATTN_NORM, 0, 98 + Math.RandomLong( 0, 3 )
                );
                g_SoundSystem.EmitSoundDyn(
                    m_pPlayer.edict(), CHAN_ITEM,
                    "debris/glass1.wav",
                    0.5f, ATTN_NORM, 0, 90 + Math.RandomLong( -5, 5 )
                );
            }

            m_trHit = tr;

            m_pPlayer.m_iWeaponVolume = int( flVol * 512 ); 
        }

        return fDidHit;
    }

    void WeaponIdle()
    {
        if( self.m_flTimeWeaponIdle > WeaponTimeBase() )
            return;

        self.SendWeaponAnim( BOTTLE_IDLE );
        self.m_flTimeWeaponIdle = WeaponTimeBase() + 3.0f;
    }
}

void Register339Bottle()
{
    g_CustomEntityFuncs.RegisterCustomEntity( "weapon_bottle", "weapon_bottle" );
    g_ItemRegistry.RegisterWeapon( "weapon_bottle", "cyrax" );
}

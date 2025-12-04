namespace PLAYER_SENTRY
{

array<string> SIEGE_WEAPON_MDLS =
{
    "models/chan_space_escape/v_box.mdl",
    "models/chan_space_escape/w_box.mdl",
    "models/chan_space_escape/p_box.mdl",
    "sprites/ns/weapon_siege.spr"
};

bool WeaponSiegeRegister(string strViewMdl = "", string strWorldMdl = "", string strPlayerMdl = "")
{
    strSiegeWeapon = "weapon_siege";
    strDisplayName = "";
    blDeployFx = blMoveFx = blUseArmourCost = false;
    flSiegePosLength = 48.0f;

    if( strViewMdl != "" )
        SIEGE_WEAPON_MDLS[MDL_VIEW] = strViewMdl;

    if( strWorldMdl != "" )
        SIEGE_WEAPON_MDLS[MDL_WORLD] = strWorldMdl;

    if( strPlayerMdl != "" )
        SIEGE_WEAPON_MDLS[MDL_PLAYER] = strPlayerMdl;

    g_CustomEntityFuncs.RegisterCustomEntity( "PLAYER_SENTRY::CSiegeWeapon", strSiegeWeapon );
    g_ItemRegistry.RegisterWeapon( strSiegeWeapon, "ns", strSiegeWeapon );

    return g_CustomEntityFuncs.IsCustomEntity( strSiegeWeapon );
}
// Class is not final and all members are public for use as baseclass for a constructing a more derived siegeweapon type
class CSiegeWeapon : ScriptBasePlayerWeaponEntity
{
    float m_flAttackRange, flPlaceDelay = 1.9f;// Used by weapon_siege for delay between primary attack and siege placement
    string m_strDisplayName;
    CScheduledFunction@ fnPlaceSiege;

    CBasePlayer@ m_pPlayer
    {
        get { return cast<CBasePlayer@>( self.m_hPlayer.GetEntity() ); }
        set { self.m_hPlayer = EHandle( @value ); }
    }

    bool KeyValue(const string& in szKey, const string& in szValue)
    {
        if( szKey == "displayname" )
            m_strDisplayName = szValue;
        else if( szKey == "attackrange" )
            m_flAttackRange = atof( szValue );
        else if( szKey == "classify" )
            self.m_iClassSelection = atoi( szValue );
        else
            return BaseClass.KeyValue( szKey, szValue );

        return true;
    }

    bool GetItemInfo(ItemInfo& out info)
    {
        info.iId     	= g_ItemRegistry.GetIdForName( self.GetClassname() );
        info.iMaxAmmo1 	= 1;
        info.iMaxAmmo2 	= -1;
        info.iMaxClip 	= WEAPON_NOCLIP;
        info.iSlot 		= 4;
        info.iPosition 	= 7;
        info.iFlags 	= ITEM_FLAG_LIMITINWORLD | ITEM_FLAG_EXHAUSTIBLE;
        info.iWeight 	= 5;

        return info.iId == g_ItemRegistry.GetIdForName( self.GetClassname() );
    }

    void Precache()
    {
        PLAYER_SENTRY::Precache();
        self.PrecacheCustomModels();
        g_Game.PrecacheGeneric( "sprites/ns/weapon_siege.txt" );
        
        for( uint i = 0; i < SIEGE_WEAPON_MDLS.length(); i++ )
            g_Game.PrecacheModel( SIEGE_WEAPON_MDLS[i] );

        BaseClass.Precache();
    }

    void Spawn()
    {
        self.Precache();
        self.m_iDefaultAmmo = 1;
        g_EntityFuncs.SetModel( self, self.GetW_Model( SIEGE_WEAPON_MDLS[MDL_WORLD] ) );
        self.FallInit();

        BaseClass.Spawn();
    }

    //int PrimaryAmmoIndex()
    //{
    //    return 1;
    //}

    string pszName()
    {
        return self.GetClassname();
    }

    string pszAmmo1()
    {
        return self.GetClassname();
    }

    bool AddToPlayer(CBasePlayer@ pPlayer)
    {
        if( !BaseClass.AddToPlayer( pPlayer ) )
            return false;

        NetworkMessage weapon( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
            weapon.WriteLong( g_ItemRegistry.GetIdForName( self.GetClassname() ) );
        weapon.End();

        @m_pPlayer = pPlayer;

        return true;
    }

    CBasePlayerItem@ DropItem()
    {
        return self;
    }

    bool CanHaveDuplicates()
    {
        return true;
    }

    bool CanDeploy()
    {
        return m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) > 0;
    }

    bool Deploy()
    {
		self.DefaultDeploy( self.GetV_Model( SIEGE_WEAPON_MDLS[MDL_VIEW] ), self.GetP_Model( SIEGE_WEAPON_MDLS[MDL_PLAYER] ), SIEGE_DRAW, "trip" );
        self.m_flTimeWeaponIdle = g_Engine.time + 1.5f;
		self.m_flNextPrimaryAttack  = g_Engine.time + 1.0f;
        return true;
    }

    bool IsEmpty()
    {
        return m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) < 1;
    }

    void DeductAmmo(int iAmmoAmt = 1)
    {
        if( iAmmoAmt == 0 )
            return;

        m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - iAmmoAmt );
    }

    void Holster(int skipLocal = 0)
    {
        m_pPlayer.m_flNextAttack = g_Engine.time + 0.5f;
        BaseClass.Holster( skipLocal );
    }

    void PlaceSiege()
    {
        CBaseMonster@ pSiege = cast<CBaseMonster@>( g_EntityFuncs.Instance( BuildSentry( m_pPlayer, SIEGE ) ) );

        if( pSiege is null )
        {   // Not enough room. Try again!
            self.m_flTimeWeaponIdle = g_Engine.time + 0.01f;
            return;
        }

        if( self.pev.health != 0.0f )
            pSiege.pev.max_health = pSiege.pev.health = self.pev.health;

        if( m_strDisplayName != "" )
            pSiege.m_FormattedName = m_strDisplayName;

        if( self.m_iClassSelection > 0 )
            pSiege.SetClassification( self.m_iClassSelection );

        //if( m_flAttackRange > 0.0f )
        //    g_EntityFuncs.DispatchKeyValue( pSiege.edict(), "attackrange", "" + m_flAttackRange );

        DeductAmmo();
        self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 10, 15 );

        if( IsEmpty() )
        {
            self.RetireWeapon();// Not necessary, but just in case of cosmic rays
            self.DestroyItem();
            return;
        }
    }

    void WeaponIdle()
    {
        if( self.m_flTimeWeaponIdle > g_Engine.time )
            return;

        self.SendWeaponAnim( SIEGE_IDLE );
        self.m_flTimeWeaponIdle = g_Engine.time + 5.0f;
    }

    void PrimaryAttack()
    {
        if( IsEmpty() )
			return;

        @fnPlaceSiege = g_Scheduler.SetTimeout( this, "PlaceSiege", flPlaceDelay );
        m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
        self.SendWeaponAnim( SIEGE_DROP );
        self.m_flNextPrimaryAttack = g_Engine.time + flPlaceDelay;
    }

    void UpdateOnRemove()
    {
        if( fnPlaceSiege !is null )
            g_Scheduler.RemoveTimer( fnPlaceSiege );
    }
};

}

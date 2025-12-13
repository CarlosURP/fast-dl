//AlienShooter Shotgun//
//email:Dr.Abc@foxmail.con//
//请勿擅自修改


class weapon_alien_shotgun : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;
	int m_iShell;
	
	void Spawn()
	{
		Precache();
		self.m_iDefaultAmmo = 20;
		g_EntityFuncs.SetModel( self, "models/alienshooter/w_alien_shot.mdl" );
		self.FallInit();
	}
	
	void Precache()
	{
		self.PrecacheCustomModels();
		//预载模型
		g_Game.PrecacheModel( "models/hlclassic/p_shotgun.mdl" );
		g_Game.PrecacheModel( "models/alienshooter/w_alien_shot.mdl" );
		g_Game.PrecacheModel( "models/alienshooter/nope.mdl" );
		m_iShell = g_Game.PrecacheModel( "models/shotgunshell.mdl" );

		//预载图标
		g_Game.PrecacheModel( "sprites/640hud7.spr" );
		g_Game.PrecacheModel( "sprites/640hud4.spr" );
		g_Game.PrecacheModel( "sprites/640hud1.spr" );
		
		//预载音效
		g_SoundSystem.PrecacheSound( "alienshooter/shotgun.wav" );
		
		//为fastdl的预载
		g_Game.PrecacheGeneric( "sprites/" + "640hud7.spr" );
		g_Game.PrecacheGeneric( "sprites/" + "640hud4.spr" );
		g_Game.PrecacheGeneric( "sprites/" + "640hud1.spr" );
		g_Game.PrecacheGeneric( "sound/" + "alienshooter/shotgun.wav" );
		g_Game.PrecacheGeneric( "sprites/" + "alien/weapon_alien_shotgun.txt" );
		
	}
	
	bool GetItemInfo( ItemInfo& out info )
	{
		//无子弹
		info.iMaxAmmo1 	= 2000;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= -1;
		info.iSlot 		= 1;
		info.iPosition 	= 5;
		info.iFlags 	= 0;
		info.iWeight 	= 0;
		return true;
	}
	
	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( BaseClass.AddToPlayer( pPlayer ) == true )
		{
			@m_pPlayer = pPlayer;
			NetworkMessage infex2( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
				infex2.WriteLong( g_ItemRegistry.GetIdForName("weapon_alien_shotgun") );
			infex2.End();
			return true;
		}
		
		return false;
	}
	
	bool Deploy()
	{
		bool bResult;
		{
			bResult = self.DefaultDeploy( self.GetV_Model( "models/alienshooter/nope.mdl" ), self.GetP_Model( "models/hlclassic/p_shotgun.mdl" ), NONE, "shotgun" );
			float deployTime = 1.1f;
			self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + deployTime;
			return bResult;
		}
	}
	
	float WeaponTimeBase()
	{
		return g_Engine.time;
	}

	void Holster( int skipLocal = 0 )
	{
		BaseClass.Holster( skipLocal );
	}
	
	void CreatShotgunDecal( const Vector& in vecSrc, const Vector& in vecAiming, const Vector& in vecSpread, const uint uiPelletCount )
	{
		TraceResult tr;
		float x, y;
		for( uint uiPellet = 0; uiPellet < uiPelletCount; ++uiPellet )
		{
			g_Utility.GetCircularGaussianSpread( x, y );
			Vector vecDir = vecAiming 
							+ x * vecSpread.x * g_Engine.v_right 
							+ y * vecSpread.y * g_Engine.v_up;
			Vector vecEnd	= vecSrc + vecDir * 2048;
			
			g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );
			
			if( tr.flFraction < 1.0 )
			{
				if( tr.pHit !is null )
				{
					CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
					
					if( pHit is null || pHit.IsBSPModel() )
						g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_BUCKSHOT );
				}
			}
		}
	}
	
	void PrimaryAttack()
	{
		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD || m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
		{
			self.m_flNextPrimaryAttack = g_Engine.time + 1.0;
			return;
		}
		
		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - 1 );
		
		self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.6;
		
		//枪火
		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;
		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
		
		
		//攻击动作
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 0.28;

		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "alienshooter/shotgun.wav", 1, ATTN_NORM, 0, PITCH_NORM );
		
		Vector vecSrc	 = m_pPlayer.GetGunPosition();
		Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );
		Vector vecRnd = Vector (Math.RandomLong(-10,10),Math.RandomLong(-10,10),Math.RandomLong(-10,10));
		
		int m_iBulletDamage = 16;//武器伤害
		
		m_pPlayer.FireBullets( 12, vecSrc, vecAiming, VECTOR_CONE_6DEGREES, 8192, BULLET_PLAYER_CUSTOMDAMAGE, 2, m_iBulletDamage );
		CreatShotgunDecal( vecSrc, vecAiming,VECTOR_CONE_ALIEN_SHOTGUN, SHOTGUN_CONE_ALIEN_PELLETCOUNT );
		
		AlienSshoottr(vecAiming + vecRnd ,120,5);//射击点残渣
		m_pPlayer.pev.punchangle.x = Math.RandomLong( -2, -1 );
		m_pPlayer.pev.punchangle.y = Math.RandomFloat( -0.2f, 0.2f );


		if( self.m_flNextPrimaryAttack < WeaponTimeBase() )
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.9f;

		self.m_flTimeWeaponIdle = WeaponTimeBase() + Math.RandomFloat( 10, 15 );
		
		//抛壳
		Vector vecShellVelocity2 = g_Engine.v_right * Math.RandomLong(80,120);
		g_EntityFuncs.EjectBrass( m_pPlayer.GetGunPosition(), vecShellVelocity2, m_pPlayer.pev.angles[ 1 ], m_iShell, TE_BOUNCE_SHELL );
	}
	
	
	void WeaponIdle()
	{

		m_pPlayer.GetAutoaimVector( AUTOAIM_10DEGREES );
		self.m_flTimeWeaponIdle = WeaponTimeBase() + Math.RandomLong(10,15);
	}
}	
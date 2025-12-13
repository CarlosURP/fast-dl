//AlienShooter Pistol//
//email:Dr.Abc@foxmail.con//
//请勿擅自修改

//没有动作
enum ALIENAnimation
{
	NONE = 0
};
//武器主题
class weapon_alien_pistol : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;
	int m_iShell;
	int16 ShellVel = 0;
	
	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, "models/alienshooter/p_alien_pistol.mdl" );
		self.FallInit();
	}
	
	void Precache()
	{
		self.PrecacheCustomModels();
		//预载模型
		g_Game.PrecacheModel( "models/alienshooter/p_alien_pistol.mdl" );
		g_Game.PrecacheModel( "models/alienshooter/nope.mdl" );
		m_iShell = g_Game.PrecacheModel( "models/shell.mdl" );

		//预载图标
		g_Game.PrecacheModel( "sprites/640hud7.spr" );
		g_Game.PrecacheModel( "sprites/640hud1.spr" );
		g_Game.PrecacheModel( "sprites/640hud4.spr" );
		
		//预载音效
		g_SoundSystem.PrecacheSound( "alienshooter/pistol_shot.wav" );
		
		//为fastdl的预载
		g_Game.PrecacheGeneric( "sprites/" + "640hud7.spr" );
		g_Game.PrecacheGeneric( "sprites/" + "640hud1.spr" );
		g_Game.PrecacheGeneric( "sprites/" + "640hud4.spr" );
		g_Game.PrecacheGeneric( "sound/" + "alienshooter/pistol_shot.wav" );
		g_Game.PrecacheGeneric( "sprites/" + "alien/weapon_alien_pistol.txt" );
		
	}
	
	bool GetItemInfo( ItemInfo& out info )
	{
		//无子弹
		info.iMaxAmmo1 	= -1;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= -1;
		info.iSlot 		= 0;
		info.iPosition 	= 4;
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
				infex2.WriteLong( g_ItemRegistry.GetIdForName("weapon_alien_pistol") );
			infex2.End();
			return true;
		}
		
		return false;
	}
	
	bool Deploy()
	{
		bool bResult;
		{
			bResult = self.DefaultDeploy( self.GetV_Model( "models/alienshooter/nope.mdl" ), self.GetP_Model( "models/alienshooter/p_alien_pistol.mdl" ), NONE, "uzis" );
			float deployTime = 1.1f;
			m_pPlayer.m_szAnimExtension = "uzis";
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
		//恢复抛壳方向
		ShellVel = 0;
		BaseClass.Holster( skipLocal );
	}
	
	void PrimaryAttack()
	{
		self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.2;
		
		//枪火
		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;
		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
		
		//双持动作
		m_pPlayer.m_szAnimExtension = "uzis_both";
		
		//攻击动作
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 0.28;

		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "alienshooter/pistol_shot.wav", 1, ATTN_NORM, 0, PITCH_NORM );
		
		Vector vecSrc	 = m_pPlayer.GetGunPosition();
		Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );
		
		int m_iBulletDamage = 25;//武器伤害
		
		m_pPlayer.FireBullets( 1, vecSrc, vecAiming, VECTOR_CONE_6DEGREES, 8192, BULLET_PLAYER_CUSTOMDAMAGE, 2, m_iBulletDamage );
		
		m_pPlayer.pev.punchangle.x = Math.RandomLong( -2, -1 );
		m_pPlayer.pev.punchangle.y = Math.RandomFloat( -0.2f, 0.2f );


		if( self.m_flNextPrimaryAttack < WeaponTimeBase() )
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.2f;

		self.m_flTimeWeaponIdle = WeaponTimeBase() + Math.RandomFloat( 10, 15 );
		
		//弹孔
		TraceResult tr;
		float x, y;
		g_Utility.GetCircularGaussianSpread( x, y );
		
		Vector vecDir = vecAiming + x * VECTOR_CONE_2DEGREES.x * g_Engine.v_right + y * VECTOR_CONE_2DEGREES.y * g_Engine.v_up;
		Vector vecEnd = vecSrc + vecDir * 4096;
		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );
		
		if( tr.flFraction < 1.0 )
		{
			if( tr.pHit !is null )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				
				if( pHit.IsBSPModel() == true )
					g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_MP5 );
					AlienSshoottr(tr.vecEndPos,160,3);//射击点残渣
			}
		}
			
		//抛壳
		Vector vecShellVelocity;
		//切换抛壳方向
		switch (ShellVel)
		{
			case 0:vecShellVelocity = g_Engine.v_right * Math.RandomLong(80,120);ShellVel = 1;break;
			case 1:vecShellVelocity = g_Engine.v_right * Math.RandomLong(-80,-120);ShellVel = 0;break;
		}
		g_EntityFuncs.EjectBrass( m_pPlayer.GetGunPosition(), vecShellVelocity, m_pPlayer.pev.angles[ 1 ], m_iShell, TE_BOUNCE_SHELL );
	}
	
	void WeaponIdle()
	{

		m_pPlayer.GetAutoaimVector( AUTOAIM_10DEGREES );
		
		if( self.m_flTimeWeaponIdle > WeaponTimeBase() || self.m_flTimeWeaponIdle == 0.28f )
		{
			m_pPlayer.m_szAnimExtension = "uzis";
			return;
		}
		m_pPlayer.m_szAnimExtension = "uzis";
		
		self.m_flTimeWeaponIdle = WeaponTimeBase() + Math.RandomLong(10,15);
	}
}	
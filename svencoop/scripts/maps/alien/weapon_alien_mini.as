//AlienShooter Minigun//
//email:Dr.Abc@foxmail.con//
//请勿擅自修改

class weapon_alien_mini : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;
	int m_iShell;
	
	void Spawn()
	{
		Precache();
		self.m_iDefaultAmmo = 500;
		g_EntityFuncs.SetModel( self, "models/alienshooter/w_alien_mini.mdl" );
		self.FallInit();
	}
	
	void Precache()
	{
		self.PrecacheCustomModels();
		//预载模型
		g_Game.PrecacheModel( "models/alienshooter/p_alien_mini.mdl" );
		g_Game.PrecacheModel( "models/alienshooter/w_alien_mini.mdl" );
		g_Game.PrecacheModel( "models/alienshooter/nope.mdl" );
		m_iShell = g_Game.PrecacheModel( "models/saw_shell.mdl" );

		//预载图标
		g_Game.PrecacheModel( "sprites/640hud7.spr" );
		g_Game.PrecacheModel( "sprites/640hudof01.spr" );
		g_Game.PrecacheModel( "sprites/640hudof02.spr" );
		
		//预载音效
		g_SoundSystem.PrecacheSound( "alienshooter/machine_gun.wav" );
		
		//为fastdl的预载
		g_Game.PrecacheGeneric( "sprites/" + "640hud7.spr" );
		g_Game.PrecacheGeneric( "sprites/" + "640hudof01.spr" );
		g_Game.PrecacheGeneric( "sprites/" + "640hudof02.spr" );
		g_Game.PrecacheGeneric( "sound/" + "alienshooter/machine_gun.wav" );
		g_Game.PrecacheGeneric( "sprites/" + "alien/weapon_alien_mini.txt" );
		
	}
	
	bool GetItemInfo( ItemInfo& out info )
	{
		//无子弹
		info.iMaxAmmo1 	= 2000;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= -1;
		info.iSlot 		= 2;
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
				infex2.WriteLong( g_ItemRegistry.GetIdForName("weapon_alien_mini") );
			infex2.End();
			return true;
		}
		
		return false;
	}
	
	bool Deploy()
	{
		bool bResult;
		{
			bResult = self.DefaultDeploy( self.GetV_Model( "models/alienshooter/nope.mdl" ), self.GetP_Model( "models/alienshooter/p_alien_mini.mdl" ), NONE, "minigun" );
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
	
	void PrimaryAttack()
	{
		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD || m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
		{
			self.m_flNextPrimaryAttack = g_Engine.time + 0.5;
			return;
		}
		
		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - 1 );
		
		self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.07;
		
		//枪火
		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;
		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
		
		
		//攻击动作
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 0.28;

		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "alienshooter/machine_gun.wav", 1, ATTN_NORM, 0, PITCH_NORM );
		
		Vector vecSrc	 = m_pPlayer.GetGunPosition();
		Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );
		
		int m_iBulletDamage = 50;//武器伤害
		
		m_pPlayer.FireBullets( 1, vecSrc, vecAiming, VECTOR_CONE_6DEGREES, 4096, BULLET_PLAYER_CUSTOMDAMAGE, 15, m_iBulletDamage );
		
		m_pPlayer.pev.punchangle.x = Math.RandomLong( -2, -1 );
		m_pPlayer.pev.punchangle.y = Math.RandomFloat( -0.2f, 0.2f );


		if( self.m_flNextPrimaryAttack < WeaponTimeBase() )
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.07f;

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
					g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_SAW );
					AlienSshoottr(tr.vecEndPos,200,5);//射击点残渣
			}
		}	
		
		//抛壳
		Vector vecShellVelocity1 = g_Engine.v_right * Math.RandomLong(80,120);
		g_EntityFuncs.EjectBrass( m_pPlayer.GetGunPosition() + g_Engine.v_up * - 20, vecShellVelocity1, m_pPlayer.pev.angles[ 1 ], m_iShell, TE_BOUNCE_SHELL );
	}
	
	
	void WeaponIdle()
	{

		m_pPlayer.GetAutoaimVector( AUTOAIM_10DEGREES );
		self.m_flTimeWeaponIdle = WeaponTimeBase() + Math.RandomLong(10,15);
	}
}	
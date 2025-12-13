//AlienShooter RPG//
//email:Dr.Abc@foxmail.con//
//请勿擅自修改

#include "../alien/item_alien"

class weapon_alien_rpg : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;
	int m_iShell;
	CBaseEntity@ cbeAlienRPG;
	
	void Spawn()
	{
		Precache();
		self.m_iDefaultAmmo = 8;
		g_EntityFuncs.SetModel( self, "models/alienshooter/w_alien_rpg.mdl" );
		self.FallInit();
	}
	
	void Precache()
	{
		self.PrecacheCustomModels();
		//预载模型
		g_Game.PrecacheModel( "models/alienshooter/p_alien_rpg.mdl" );
		g_Game.PrecacheModel( "models/alienshooter/w_alien_rpg.mdl" );
		g_Game.PrecacheModel( "models/metalgibs.mdl" );
		g_Game.PrecacheModel( "models/alienshooter/nope.mdl" );
		m_iShell = g_Game.PrecacheModel( "models/saw_shell.mdl" );

		//预载图标
		g_Game.PrecacheModel( "sprites/640hud7.spr" );
		g_Game.PrecacheModel( "sprites/640hud2.spr" );
		g_Game.PrecacheModel( "sprites/640hud5.spr" );
		g_Game.PrecacheModel( "sprites/eexplo.spr" );
		
		//预载音效
		g_SoundSystem.PrecacheSound( "alienshooter/rocket_launch.wav" );
		
		//为fastdl的预载
		g_Game.PrecacheGeneric( "sprites/" + "640hud7.spr" );
		g_Game.PrecacheGeneric( "sprites/" + "640hud2.spr" );
		g_Game.PrecacheGeneric( "sprites/" + "640hud5.spr" );
		g_Game.PrecacheGeneric( "sound/" + "alienshooter/rocket_launch.wav" );
		g_Game.PrecacheGeneric( "sprites/" + "alien/weapon_alien_rpg.txt" );
		
	}
	
	bool GetItemInfo( ItemInfo& out info )
	{
		//无子弹
		info.iMaxAmmo1 	= 2000;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= -1;
		info.iSlot 		= 4;
		info.iPosition 	= 5;
		info.iFlags 	= 0;
		info.iWeight 	= 4;
		return true;
	}
	
	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( BaseClass.AddToPlayer( pPlayer ) == true )
		{
			@m_pPlayer = pPlayer;
			NetworkMessage infex2( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
				infex2.WriteLong( g_ItemRegistry.GetIdForName("weapon_alien_rpg") );
			infex2.End();
			return true;
		}
		
		return false;
	}
	
	bool Deploy()
	{
		bool bResult;
		{
			bResult = self.DefaultDeploy( self.GetV_Model( "models/alienshooter/nope.mdl" ), self.GetP_Model( "models/alienshooter/p_alien_rpg.mdl" ), NONE, "rpg" );
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
		
		self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.75;
		
		//枪火
		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;
		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
		
		
		//攻击动作
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 0.28;

		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "alienshooter/rocket_launch.wav", 1, ATTN_NORM, 0, PITCH_NORM );
		
		Math.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle);
		if( ( m_pPlayer.pev.button & IN_DUCK ) != 0 )
		{						
			ShootAlienNade(m_pPlayer.pev,
								m_pPlayer.pev.origin + g_Engine.v_forward * 32 + g_Engine.v_right * 8 + g_Engine.v_up * 4,
								g_Engine.v_forward * 1000);//800
			AlienTrail(cbeAlienRPG,255,255,255,255,2,2);
		}
		else
		{
			ShootAlienNade(m_pPlayer.pev,
								m_pPlayer.pev.origin + m_pPlayer.pev.view_ofs * 0.5 + g_Engine.v_forward * 32 + g_Engine.v_right * 8 + g_Engine.v_up * 4,
								g_Engine.v_forward * 1000 );//800
			AlienTrail(cbeAlienRPG,255,255,255,255,2,2);
		}
		
		m_pPlayer.pev.punchangle.x = Math.RandomLong( -2, -1 );
		m_pPlayer.pev.punchangle.y = Math.RandomFloat( -0.2f, 0.2f );


		if( self.m_flNextPrimaryAttack < WeaponTimeBase() )
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.75f;

		self.m_flTimeWeaponIdle = WeaponTimeBase() + Math.RandomFloat( 10, 15 );
		
		
		//抛壳
		Vector vecShellVelocity1 = g_Engine.v_right * Math.RandomLong(80,120);
		g_EntityFuncs.EjectBrass( m_pPlayer.GetGunPosition() + g_Engine.v_up * - 20, vecShellVelocity1, m_pPlayer.pev.angles[ 1 ], m_iShell, TE_BOUNCE_SHELL );
	}
	
	private void ShootAlienNade(entvars_t@ pevOwner, Vector vecStart, Vector vecVelocity) 
	{
		@ cbeAlienRPG = g_EntityFuncs.CreateEntity( "alien_rpg", null,  false);
		alien_rpg@ pAlienRPG = cast<alien_rpg@>(CastToScriptClass(cbeAlienRPG));

		g_EntityFuncs.SetOrigin( pAlienRPG.self, vecStart );
		g_EntityFuncs.DispatchSpawn( pAlienRPG.self.edict() );

		pAlienRPG.pev.velocity = vecVelocity ;
		@pAlienRPG.pev.owner = pevOwner.pContainingEntity;
		pAlienRPG.pev.angles = Math.VecToAngles( pAlienRPG.pev.velocity );
		pAlienRPG.SetTouch( TouchFunction( pAlienRPG.Touch ) );
	}

	void WeaponIdle()
	{
		m_pPlayer.GetAutoaimVector( AUTOAIM_10DEGREES );
		self.m_flTimeWeaponIdle = WeaponTimeBase() + Math.RandomLong(10,15);
	}
}	
/* 
* Modified version of the weapon_hlcrowbar.as by Sidewinder ( https://steamcommunity.com/id/tehsnek/ )
*/

enum pad_e
{
	PAD_IDLE = 0,
	PAD_DRAW,
	PAD_HOLSTER,
	PAD_ATTACK1HIT,
	PAD_ATTACK1MISS,
	PAD_ATTACK2MISS,
	PAD_ATTACK2HIT,
	PAD_ATTACK3MISS,
	PAD_ATTACK3HIT
};

class weapon_ipad : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;
	int m_iSwing;
	TraceResult m_trHit;
	
	void Spawn()
	{
		self.Precache();
		g_EntityFuncs.SetModel( self, self.GetW_Model( "models/cyrax/wpn/w_ipad.mdl") );
		self.m_iClip			= -1;
		self.m_flCustomDmg		= self.pev.dmg;

		self.FallInit();// get ready to fall down.
	}

	void Precache()
	{
		self.PrecacheCustomModels();

		g_Game.PrecacheModel( "models/cyrax/wpn/p_ipad.mdl" );
		g_Game.PrecacheModel( "models/cyrax/wpn/v_ipad.mdl" );
		g_Game.PrecacheModel( "models/cyrax/wpn/w_ipad.mdl" );
		
		g_Game.PrecacheGeneric( "sprites/cyrax/weapon_ipad.txt" );
		g_Game.PrecacheModel( "sprites/cyrax/640hud1_ipad.spr" );
		g_Game.PrecacheModel( "sprites/cyrax/640hud4_ipad.spr" );


		g_SoundSystem.PrecacheSound( "weapons/knife_hit_flesh1.wav" );
		g_SoundSystem.PrecacheSound( "weapons/knife3.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/blunt_hit2.wav" );

		g_Game.PrecacheGeneric( "sprites/cyrax/weapon_ipad.txt" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1		= -1;
		info.iMaxAmmo2		= -1;
		info.iMaxClip		= WEAPON_NOCLIP;
		info.iSlot		= 0;
		info.iPosition		= 12;
		info.iWeight		= 0;
		return true;
	}
	
	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( !BaseClass.AddToPlayer( pPlayer ) )
			return false;
			
		@m_pPlayer = pPlayer;

		return true;
	}

	bool Deploy()
	{
		return self.DefaultDeploy( self.GetV_Model( "models/cyrax/wpn/v_ipad.mdl" ), self.GetP_Model( "models/cyrax/wpn/p_ipad.mdl" ), PAD_DRAW, "crowbar" );
	}

	void Holster( int skiplocal /* = 0 */ )
	{
		self.m_fInReload = false;// cancel any reload in progress.

		m_pPlayer.m_flNextAttack = g_WeaponFuncs.WeaponTimeBase() + 0.5; 

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
			self.pev.nextthink = g_Engine.time + 0.1;
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
		Vector vecSrc	= m_pPlayer.GetGunPosition();
		Vector vecEnd	= vecSrc + g_Engine.v_forward * 32;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if ( tr.flFraction >= 1.0 )
		{
			g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr );
			if ( tr.flFraction < 1.0 )
			{
				// Calculate the point of intersection of the line (or hull) and the object we hit
				// This is and approximation of the "best" intersection
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				if ( pHit is null || pHit.IsBSPModel() )
					g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, m_pPlayer.edict() );
				vecEnd = tr.vecEndPos;	// This is the point on the actual surface (the hull could have hit space)
			}
		}

		if ( tr.flFraction >= 1.0 )
		{
			if( fFirst != 0 )
			{
				// miss
				switch( ( m_iSwing++ ) % 3 )
				{
				case 0:
					self.SendWeaponAnim( PAD_ATTACK1MISS ); break;
				case 1:
					self.SendWeaponAnim( PAD_ATTACK2MISS ); break;
				case 2:
					self.SendWeaponAnim( PAD_ATTACK3MISS ); break;
				}
				self.m_flNextPrimaryAttack = g_Engine.time + 0.5;
				// play wiff or swish sound
				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "weapons/knife3.wav", 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );

				// player "shoot" animation
				m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 
			}
		}
		else
		{
			// hit
			fDidHit = true;
			
			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

			switch( ( ( m_iSwing++ ) % 2 ) + 1 )
			{
			case 0:
				self.SendWeaponAnim( PAD_ATTACK1HIT ); break;
			case 1:
				self.SendWeaponAnim( PAD_ATTACK2HIT ); break;
			case 2:
				self.SendWeaponAnim( PAD_ATTACK3HIT ); break;
			}

			// player "shoot" animation
			m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 

			// AdamR: Custom damage option
			float flDamage = 8;
			if ( self.m_flCustomDmg > 0 )
				flDamage = self.m_flCustomDmg;
			// AdamR: End

			g_WeaponFuncs.ClearMultiDamage();
			if ( self.m_flNextPrimaryAttack + 1 < g_Engine.time )
			{
				pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_CLUB | DMG_NEVERGIB );
			}
			else
			{
				// subsequent swings do 50% (Changed -Sniper) (Half)
				pEntity.TraceAttack( m_pPlayer.pev, flDamage * 0.5, g_Engine.v_forward, tr, DMG_CLUB | DMG_NEVERGIB );  
			}
			g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

			//m_flNextPrimaryAttack = gpGlobals->time + 0.30; //0.25

			// play thwack, smack, or dong sound
			float flVol = 1.0;
			bool fHitWorld = true;

			if( pEntity !is null )
			{
				self.m_flNextPrimaryAttack = g_Engine.time + 0.20; //0.25

				if( pEntity.Classify() != CLASS_NONE && pEntity.Classify() != CLASS_MACHINE && pEntity.BloodColor() != DONT_BLEED )
				{
	// aone
					if( pEntity.IsPlayer() )		// lets pull them
					{
						pEntity.pev.velocity = pEntity.pev.velocity + ( self.pev.origin - pEntity.pev.origin ).Normalize() * 120;
					}
	// end aone
					// play thwack or smack sound
					g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "weapons/knife_hit_flesh1.wav", 1, ATTN_NORM );

					m_pPlayer.m_iWeaponVolume = 128; 
					if( !pEntity.IsAlive() )
						return true;
					else
						flVol = 0.1;

					fHitWorld = false;
				}
			}

			// play texture hit sound
			// UNDONE: Calculate the correct point of intersection when we hit with the hull instead of the line

			if( fHitWorld == true )
			{
				float fvolbar = g_SoundSystem.PlayHitSound( tr, vecSrc, vecSrc + ( vecEnd - vecSrc ) * 2, BULLET_PLAYER_CROWBAR );
				
				self.m_flNextPrimaryAttack = g_Engine.time + 0.2; //0.25
				
				// override the volume here, cause we don't play texture sounds in multiplayer, 
				// and fvolbar is going to be 0 from the above call.

				fvolbar = 1;

				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/blunt_hit2.wav", fvolbar, ATTN_NORM, 0, 80 ); 
			}

			// delay the decal a bit
			m_trHit = tr;
			//SetThink( ThinkFunction( this.Smack ) );
			//self.pev.nextthink = g_Engine.time + 0.2;

			m_pPlayer.m_iWeaponVolume = int( flVol * 512 ); 
		}
		return fDidHit;
	}
}

void Register339IPad()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_ipad", "weapon_ipad" );
	g_ItemRegistry.RegisterWeapon( "weapon_ipad", "cyrax" );
}

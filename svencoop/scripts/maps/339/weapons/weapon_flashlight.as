/* 
* Modified version of the weapon_hlcrowbar.as by Sidewinder ( https://steamcommunity.com/id/tehsnek/ )
*/

enum flashlight
{
	CROWBAR_IDLE = 0,
	CROWBAR_HOLSTER,
	CROWBAR_PUSHBUTTON,
	CROWBAR_DRAW,
	CROWBAR_SWING1,
	CROWBAR_SWING2
};

enum m_iFlashLightMode
{
	MODE_NONE,
	MODE_ON,
	MODE_OFF
};

class weapon_flashlight : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;
	private int m_iFlashLightMode;
	int m_iSwing;
	TraceResult m_trHit;
	
	void Spawn()
	{
		self.Precache();
		g_EntityFuncs.SetModel( self, self.GetW_Model( "models/cyrax/wpn/w_flashlight.mdl") );
		self.m_iClip			= -1;
		self.m_flCustomDmg		= self.pev.dmg;
		m_iFlashLightMode = MODE_OFF;
		self.FallInit();// get ready to fall down.
	}

	void Precache()
	{
		self.PrecacheCustomModels();

		g_Game.PrecacheModel( "models/cyrax/wpn/p_flashlight.mdl" );
		g_Game.PrecacheModel( "models/cyrax/wpn/v_flashlight.mdl" );
		g_Game.PrecacheModel( "models/cyrax/wpn/w_flashlight.mdl" );
		
		g_Game.PrecacheGeneric( "sprites/cyrax/weapon_flashlight.txt" );
		g_Game.PrecacheModel( "sprites/cyrax/640hud1_flashlight.spr" );
		g_Game.PrecacheModel( "sprites/cyrax/640hud4_flashlight.spr" );


		g_SoundSystem.PrecacheSound( "cyrax/wpn/bat_hitwall1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/blunt_hitbod1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/blunt_hitbod2.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/blunt_hitbod3.wav" );
		g_SoundSystem.PrecacheSound( "weapons/knife3.wav" );

		g_Game.PrecacheGeneric( "sprites/cyrax/weapon_flashlight.txt" );

	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1		= -1;
		info.iMaxAmmo2		= -1;
		info.iMaxClip		= WEAPON_NOCLIP;
		info.iSlot			= 0;
		info.iPosition		= 18;
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
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "weapons/knife3.wav", 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
		return self.DefaultDeploy( self.GetV_Model( "models/cyrax/wpn/v_flashlight.mdl" ), self.GetP_Model( "models/cyrax/wpn/p_flashlight.mdl" ), CROWBAR_DRAW, "crowbar" );
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

	void SecondaryAttack()
	{
		switch( m_iFlashLightMode )
		{
			case MODE_OFF:
			{
				m_iFlashLightMode = MODE_ON;
				m_pPlayer.pev.effects |= EF_DIMLIGHT;
				self.SendWeaponAnim( CROWBAR_PUSHBUTTON );
				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "items/flashlight1.wav", 1, ATTN_NORM, 0, 100 );
				break;
			}
			case MODE_ON:
			{
				m_iFlashLightMode = MODE_OFF;
				m_pPlayer.pev.effects &= ~EF_DIMLIGHT;
				self.SendWeaponAnim( CROWBAR_PUSHBUTTON );
				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "items/flashlight1.wav", 1, ATTN_NORM, 0, 100 );
				break;
			}
		}

		self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.5;
	}

	void Smack()
	{
		if( m_iFlashLightMode == MODE_ON )
		{
			m_pPlayer.pev.effects |= EF_DIMLIGHT;
		}

		//g_WeaponFuncs.DecalGunshot( m_trHit, BULLET_PLAYER_CROWBAR );
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
				self.SendWeaponAnim( CROWBAR_SWING1 );

				m_pPlayer.pev.effects &= ~EF_DIMLIGHT;
				self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.5;
				// play wiff or swish sound
				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "weapons/knife3.wav", 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );

				// player "shoot" animation
				m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
			}

			SetThink( ThinkFunction( this.Smack ) );
			self.pev.nextthink = g_Engine.time + 0.55;
		}
		else
		{
			// hit
			fDidHit = true;
			
			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

			self.SendWeaponAnim( CROWBAR_SWING2 );

			// player "shoot" animation
			m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 

			// AdamR: Custom damage option
			float flDamage = 9;
			if ( self.m_flCustomDmg > 0 )
				flDamage = self.m_flCustomDmg;
			// AdamR: End

			g_WeaponFuncs.ClearMultiDamage();
			if ( self.m_flNextPrimaryAttack + 1 < g_Engine.time )
			{
				// first swing does full damage
				pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_CLUB | DMG_NEVERGIB );  
			}
			else
			{
				pEntity.TraceAttack( m_pPlayer.pev, flDamage * 0.75, g_Engine.v_forward, tr, DMG_CLUB | DMG_NEVERGIB );  
			}	
			g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

			// play thwack, smack, or dong sound
			float flVol = 1.0;
			bool fHitWorld = true;

			if( pEntity !is null )
			{
				self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.25; //0.25

				m_pPlayer.pev.effects &= ~EF_DIMLIGHT;
				if( pEntity.Classify() != CLASS_NONE && pEntity.Classify() != CLASS_MACHINE && pEntity.BloodColor() != DONT_BLEED )
				{
	// aone
					if( pEntity.IsPlayer() )		// lets pull them
					{
						pEntity.pev.velocity = pEntity.pev.velocity + ( self.pev.origin - pEntity.pev.origin ).Normalize() * 120;
					}
	// end aone
					// play thwack or smack sound
					switch( Math.RandomLong( 0, 2 ) )
					{
						case 0:
						{
							g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/blunt_hitbod1.wav", 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
						}
						break;
						case 1:
						{
							g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/blunt_hitbod2.wav", 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
						}
						break;
						case 2:
						{
							g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/blunt_hitbod3.wav", 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
						}
						break;
					}
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
				
				self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.25; //0.25

				m_pPlayer.pev.effects &= ~EF_DIMLIGHT;
				// override the volume here, cause we don't play texture sounds in multiplayer, 
				// and fvolbar is going to be 0 from the above call.

				fvolbar = 1;

				// also play crowbar strike
				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "cyrax/wpn/bat_hitwall1.wav", 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
			}

			// delay the decal a bit
			m_trHit = tr;
			SetThink( ThinkFunction( this.Smack ) );
			self.pev.nextthink = g_Engine.time + 0.35;

			m_pPlayer.m_iWeaponVolume = int( flVol * 512 ); 
		}
		return fDidHit;
	}
}

void Register339Flashlight()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_flashlight", "weapon_flashlight" );
	g_ItemRegistry.RegisterWeapon( "weapon_flashlight", "cyrax" );
}

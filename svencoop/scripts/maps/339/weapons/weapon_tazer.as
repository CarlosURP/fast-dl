/* 
* Modified version of the weapon_hlcrowbar.as by Sidewinder ( https://steamcommunity.com/id/tehsnek/ )
*/

enum tazer
{
	TAZER_IDLE = 0,
	TAZER_DRAW,
	TAZER_HOLSTER,
	TAZER_ATTACK1HIT,
	TAZER_ATTACK1MISS,
	TAZER_ATTACK2MISS,
	TAZER_ATTACK2HIT,
	TAZER_ATTACK3MISS,
	TAZER_ATTACK3HIT
};

class weapon_tazer : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;
	
	int m_iSwing;
	TraceResult m_trHit;
	
	void Spawn()
	{
		self.Precache();
		g_EntityFuncs.SetModel( self, self.GetW_Model( "models/cyrax/wpn/w_tazer.mdl") );
		self.m_iClip			= -1;
		self.m_flCustomDmg		= self.pev.dmg;

		self.FallInit();// get ready to fall down.
	}

	void Precache()
	{
		self.PrecacheCustomModels();

		g_Game.PrecacheModel( "models/cyrax/wpn/p_tazer.mdl" );
		g_Game.PrecacheModel( "models/cyrax/wpn/v_tazer.mdl" );
		g_Game.PrecacheModel( "models/cyrax/wpn/w_tazer.mdl" );

		g_SoundSystem.PrecacheSound( "cyrax/wpn/tazer_hit1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/tazer_hit2.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/tazer_hitbod1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/tazer_hitbod2.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/tazer_hitbod3.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/tazer_miss1.wav" );
		g_SoundSystem.PrecacheSound( "cyrax/wpn/kitana_hitwall2.wav" );
		g_SoundSystem.PrecacheSound( "weapons/knife_hit_flesh1.wav" );
		g_SoundSystem.PrecacheSound( "weapons/knife_hit_wall1.wav" );
		g_SoundSystem.PrecacheSound( "weapons/knife3.wav" );

		g_Game.PrecacheGeneric( "sprites/cyrax/weapon_tazer.txt" );

	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1		= -1;
		info.iMaxAmmo2		= -1;
		info.iMaxClip		= WEAPON_NOCLIP;
		info.iSlot			= 0;
		info.iPosition		= 14;
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
		return self.DefaultDeploy( self.GetV_Model( "models/cyrax/wpn/v_tazer.mdl" ), self.GetP_Model( "models/cyrax/wpn/p_tazer.mdl" ), TAZER_DRAW, "crowbar" );
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

	// Simple helper: spawn electric sparks at a position
	void ElectricSparks( const Vector& in pos )
	{
		NetworkMessage m( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, pos );
			m.WriteByte( TE_SPARKS );
			m.WriteCoord( pos.x );
			m.WriteCoord( pos.y );
			m.WriteCoord( pos.z );
		m.End();
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
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				if ( pHit is null || pHit.IsBSPModel() )
					g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, m_pPlayer.edict() );
				vecEnd = tr.vecEndPos;
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
					self.SendWeaponAnim( TAZER_ATTACK1MISS ); break;
				case 1:
					self.SendWeaponAnim( TAZER_ATTACK2MISS ); break;
				case 2:
					self.SendWeaponAnim( TAZER_ATTACK3MISS ); break;
				}
				self.m_flNextPrimaryAttack = g_Engine.time + 0.5;
				// play wiff or swish sound
				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "weapons/knife3.wav", 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
				g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_STATIC, "cyrax/wpn/tazer_miss1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM );

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
				self.SendWeaponAnim( TAZER_ATTACK1HIT ); break;
			case 1:
				self.SendWeaponAnim( TAZER_ATTACK2HIT ); break;
			case 2:
				self.SendWeaponAnim( TAZER_ATTACK3HIT ); break;
			}

			// player "shoot" animation
			m_pPlayer.SetAnimation( PLAYER_ATTACK1 ); 

			// Damage reduced by half from original (20 -> 10)
			float flDamage = 10;
			if ( self.m_flCustomDmg > 0 )
				flDamage = self.m_flCustomDmg;

			g_WeaponFuncs.ClearMultiDamage();
			if ( self.m_flNextPrimaryAttack + 1 < g_Engine.time )
			{
				pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_SHOCK | DMG_SHOCK_GLOW | DMG_POISON | DMG_NEVERGIB );
			}
			else
			{
				pEntity.TraceAttack( m_pPlayer.pev, flDamage * 0.75, g_Engine.v_forward, tr, DMG_SHOCK | DMG_SHOCK_GLOW | DMG_POISON | DMG_NEVERGIB );
			}	
			g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

			// play thwack, smack, or dong sound
			float flVol = 1.0;
			bool fHitWorld = true;

			if( pEntity !is null )
			{
				self.m_flNextPrimaryAttack = g_Engine.time + 0.3; 

				if( pEntity.Classify() != CLASS_NONE && pEntity.Classify() != CLASS_MACHINE && pEntity.BloodColor() != DONT_BLEED )
				{
					// tazer visual effect on entity
					ElectricSparks( tr.vecEndPos );

					if( pEntity.IsPlayer() )
					{
						pEntity.pev.velocity = pEntity.pev.velocity + ( self.pev.origin - pEntity.pev.origin ).Normalize() * 120;
					}
					switch( Math.RandomLong( 0, 1 ) )
					{
						case 0:
						{
							g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "weapons/knife_hit_flesh1.wav", 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
							g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_STATIC, "cyrax/wpn/tazer_hit1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM );
						}
						break;
						case 1:
						{
							g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "weapons/knife_hit_flesh1.wav", 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
							g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_STATIC, "cyrax/wpn/tazer_hit2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM );
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

			if( fHitWorld == true )
			{
				float fvolbar = g_SoundSystem.PlayHitSound( tr, vecSrc, vecSrc + ( vecEnd - vecSrc ) * 2, BULLET_PLAYER_CROWBAR );
				
				self.m_flNextPrimaryAttack = g_Engine.time + 0.3; 
				
				fvolbar = 1;

				// tazer sparks on world hit too
				ElectricSparks( tr.vecEndPos );

				switch( Math.RandomLong( 0, 1 ) )
				{
					case 0:
					{
						g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "weapons/knife_hit_wall1.wav", 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
						g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_STATIC, "cyrax/wpn/tazer_hit1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM );
					}
					break;
					case 1:
					{
						g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "weapons/knife_hit_wall1.wav", 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );
						g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_STATIC, "cyrax/wpn/tazer_hit2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM );
					}
					break;
				}
			}
			m_trHit = tr;
			m_pPlayer.m_iWeaponVolume = int( flVol * 512 ); 
		}
		return fDidHit;
	}
}

void Register339Tazer()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "weapon_tazer", "weapon_tazer" );
	g_ItemRegistry.RegisterWeapon( "weapon_tazer", "cyrax" );
}

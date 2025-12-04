/* Natural Selection Weldable Script
By Meryilla

This is basically a stripped down, more limited version of func_breakable
except that it is only damagable by the NS welder

Models, Sounds, and Sprites by Unknown Worlds

Additional Credit to the below for providing guidance in creating these scripts:

https://github.com/ValveSoftware/halflife Half-Life SDK - by Valve
https://twhl.info/wiki/page/Tutorial%3A_Coding_NPCs_in_GoldSrc - by dexter
Natural Selection Source Code - by Unknown Worlds
*/

namespace NS_WELDABLE
{

enum e_materials
{
	MAT_GLASS = 0,
	MAT_METAL,
	MAT_FLESH,
	MAT_WOOD,
	MAT_LAST
};

array<string> SOUNDS_GLASS = 
{
	"debris/glass1.wav",
	"debris/glass2.wav",
	"debris/glass3.wav"
};

array<string> SOUNDS_METAL = 
{
	"debris/metal1.wav",
	"debris/metal2.wav",
	"debris/metal3.wav"
};

array<string> SOUNDS_FLESH = 
{
	"debris/flesh1.wav",
	"debris/flesh2.wav",
	"debris/flesh3.wav",
	"debris/flesh5.wav",
	"debris/flesh6.wav",
	"debris/flesh7.wav"
};

array<string> SOUNDS_WOOD = 
{
	"debris/wood1.wav",
	"debris/wood2.wav",
	"debris/wood3.wav"
};

class func_weldable : ScriptBaseEntity
{
	int m_iMaterial;
	int m_iExplosion;
	float m_flAngle;
	Vector m_vecAttackDir = Vector( 0, 0, 0);
	private string m_szGib;

	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		//It doesn't really make sense for non metal materials to be weldable, but lets add support anyway
		if( szKey == "material" )
		{
			// 0:glass, 1:metal, 2:flesh, 3:wood
			m_iMaterial = atoi( szValue );

			if( ( m_iMaterial < 0 ) || ( m_iMaterial >= MAT_LAST ) )
				m_iMaterial = MAT_METAL;
		}
		else
			return BaseClass.KeyValue( szKey, szValue );
		
		return true;
	}

	void Spawn()
	{
		Precache();
		self.pev.solid	= SOLID_BSP;
		self.pev.movetype	= MOVETYPE_PUSH;
		self.pev.takedamage = DAMAGE_YES;

		m_flAngle = self.pev.angles.y;
		self.pev.angles.y = 0;

		g_EntityFuncs.SetModel( self, self.pev.model );
	}

	void Precache()
	{
		switch( m_iMaterial )
		{
			case MAT_GLASS:
			{
				m_szGib = "models/glassgibs.mdl";
				g_SoundSystem.PrecacheSound( "debris/bustglass1.wav" );
				g_SoundSystem.PrecacheSound( "debris/bustglass2.wav" );
				break;
			}
			case MAT_METAL:
			{
				m_szGib = "models/metalplategibs.mdl";
				g_SoundSystem.PrecacheSound( "debris/bustmetal1.wav" );
				g_SoundSystem.PrecacheSound( "debris/bustmetal2.wav" );
				break;
			}
			case MAT_FLESH:
			{
				m_szGib = "models/fleshgibs.mdl";
				g_SoundSystem.PrecacheSound( "debris/bustflesh1.wav" );
				g_SoundSystem.PrecacheSound( "debris/bustflesh2.wav" );
				break;				
			}			
			case MAT_WOOD:
			{
				m_szGib = "models/woodgibs.mdl";
				g_SoundSystem.PrecacheSound( "debris/bustcrate1.wav" );
				g_SoundSystem.PrecacheSound( "debris/bustcrate2.wav" );
				break;
			}
			default:
			{
				m_szGib = "models/metalplategibs.mdl";
				g_SoundSystem.PrecacheSound( "debris/bustmetal1.wav" );
				g_SoundSystem.PrecacheSound( "debris/bustmetal2.wav" );
				break;
			}
		}
		MaterialSoundPrecache( m_iMaterial );
		g_Game.PrecacheModel( m_szGib );
	}

	array<string> MaterialSoundList( int iMat )
	{
		array<string> soundList;

		switch ( iMat ) 
		{
			case MAT_GLASS:
			{
				soundList = SOUNDS_GLASS;
				break;
			}
			case MAT_METAL:
			{
				soundList = SOUNDS_METAL;
				break;
			}
			case MAT_FLESH:
			{
				soundList = SOUNDS_FLESH;
				break;
			}
			case MAT_WOOD:
			{
				soundList = SOUNDS_WOOD;
				break;
			}
			default:
			{
				soundList = SOUNDS_METAL;
				break;
			}
		}
		return soundList;
	}

	void MaterialSoundPrecache( int iMat )
	{
		array<string> soundList;

		soundList = MaterialSoundList( iMat );

		for( int i = 0; i < soundList.length(); i++ )
		{
			g_SoundSystem.PrecacheSound( soundList[i] );
		}
	}

	void DamageSound()
	{
		int iPitch;
		float flVol;
		array<string> soundsToPlay(6);
		int iLastIndex;

		if( Math.RandomLong( 0, 2 ) != 0 )
			iPitch = PITCH_NORM;
		else
			iPitch = 95 + Math.RandomLong( 0, 34 );

		flVol = Math.RandomFloat( 0.75, 1.0 );

		switch ( m_iMaterial )
		{
			case MAT_GLASS:
			{
				soundsToPlay[0] = "debris/glass1.wav";
				soundsToPlay[1] = "debris/glass2.wav";
				soundsToPlay[2] = "debris/glass3.wav";
				iLastIndex = 2;
				break;
			}

			case MAT_WOOD:
			{
				soundsToPlay[0] = "debris/wood1.wav";
				soundsToPlay[1] = "debris/wood2.wav";
				soundsToPlay[2] = "debris/wood3.wav";
				iLastIndex = 2;
				break;
			}
			case MAT_METAL:
			{
				soundsToPlay[0] = "debris/metal1.wav";
				soundsToPlay[1] = "debris/metal3.wav";
				soundsToPlay[2] = "debris/metal2.wav";
				iLastIndex = 2;
				break;
			}
			case MAT_FLESH:
			{
				soundsToPlay[0] = "debris/flesh1.wav";
				soundsToPlay[1] = "debris/flesh2.wav";
				soundsToPlay[2] = "debris/flesh3.wav";
				soundsToPlay[3] = "debris/flesh5.wav";
				soundsToPlay[4] = "debris/flesh6.wav";
				soundsToPlay[5] = "debris/flesh7.wav";
				iLastIndex = 5;
				break;
			}
			default:
			{
				soundsToPlay[0] = "debris/metal1.wav";
				soundsToPlay[1] = "debris/metal3.wav";
				soundsToPlay[2] = "debris/metal2.wav";
				iLastIndex = 2;
				break;
			}
		}
		string szSound = soundsToPlay[Math.RandomLong( 0, iLastIndex )];
		g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, szSound, flVol, ATTN_NORM, 0, iPitch );
	}	

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float value )
	{
		if ( IsBreakable() )
		{
			self.pev.angles.y = m_flAngle;
			g_EngineFuncs.MakeVectors( self.pev.angles );
			m_vecAttackDir = g_Engine.v_forward;

			Die();
		}
	}

	int TakeDamage( entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType )
	{
		Vector	vecTemp;
		//We only take damage from the NS welder
		if( pevInflictor.classname == "weapon_ns_welder" )	
		{
			vecTemp = pevInflictor.origin - ( self.pev.absmin + ( self.pev.size * 0.5 ) );
		}
		else
		{
			return 0;
		}
		
		if( !IsBreakable() )
			return 0;

		// this is still used for glass and other non-monster killables, along with decals.
		m_vecAttackDir = vecTemp.Normalize();
			
		// do the damage
		self.pev.health -= flDamage;
		if( self.pev.health <= 0 )
		{
			self.Killed( pevAttacker, GIB_NORMAL );
			Die();
			return 0;
		}

		// Make a shard noise each time func breakable is hit.
		// Don't play shard noise if cbreakable actually died.

		DamageSound();

		return 1;
	}

	void Die()
	{
		Vector vecSpot;// shard origin
		Vector vecVelocity = g_vecZero;// shard velocity
		CBaseEntity@ pEntity;
		uint8 ui8Flag = 0;
		int iPitch;
		float flVol;
		
		iPitch = 95 + Math.RandomLong( 0, 29 );

		if (iPitch > 97 && iPitch < 103)
			iPitch = 100;

		// The more negative pev->health, the louder
		// the sound should be.

		flVol = Math.RandomFloat( 0.85, 1.0 ) + ( abs( self.pev.health ) / 100.0);

		if (flVol > 1.0)
			flVol = 1.0;


		switch( m_iMaterial )
		{
			case MAT_GLASS:
			{
				switch ( Math.RandomLong( 0, 1 ) )
				{
					case 0:	g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustglass1.wav", flVol, ATTN_NORM, 0, iPitch );	
						break;
					case 1:	g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustglass2.wav", flVol, ATTN_NORM, 0, iPitch );	
						break;
				}
				ui8Flag = BREAK_GLASS;
				break;
			}
			case MAT_WOOD:
			{
				switch ( Math.RandomLong( 0, 1 ) )
				{
					case 0:	g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustcrate1.wav", flVol, ATTN_NORM, 0, iPitch );	
						break;
					case 1:	g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustcrate2.wav", flVol, ATTN_NORM, 0, iPitch );	
						break;
				}
				ui8Flag = BREAK_WOOD;
				break;
			}
			case MAT_METAL:
			{
				switch ( Math.RandomLong( 0, 1 ) )
				{
					case 0:	g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustmetal1.wav", flVol, ATTN_NORM, 0, iPitch );	
						break;
					case 1:	g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustmetal2.wav", flVol, ATTN_NORM, 0, iPitch );	
						break;
				}
				ui8Flag = BREAK_METAL;
				break;
			}
			case MAT_FLESH:
			{
				switch ( Math.RandomLong( 0, 1 ) )
				{
					case 0:	g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustflesh1.wav", flVol, ATTN_NORM, 0, iPitch );	
						break;
					case 1:	g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustflesh2.wav", flVol, ATTN_NORM, 0, iPitch );	
						break;
				}
				ui8Flag = BREAK_FLESH;
				break;
			}
			default:
			{
				switch ( Math.RandomLong( 0, 1 ) )
				{
					case 0:	g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustmetal1.wav", flVol, ATTN_NORM, 0, iPitch );	
						break;
					case 1:	g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustmetal2.wav", flVol, ATTN_NORM, 0, iPitch );	
						break;
				}
				ui8Flag = BREAK_METAL;
				break;
			}
		}
		
		//if( m_Explosion == expDirected )
		//	vecVelocity = g_vecAttackDir * 200;
		//else
		//{
		//	vecVelocity.x = 0;
		//	vecVelocity.y = 0;
		//	vecVelocity.z = 0;
		//}

		vecSpot = self.pev.origin + ( self.pev.mins + self.pev.maxs ) * 0.5;
		NetworkMessage m( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecSpot );
			m.WriteByte( TE_BREAKMODEL);

			// position
			m.WriteCoord( vecSpot.x );
			m.WriteCoord( vecSpot.y );
			m.WriteCoord( vecSpot.z );

			// size
			m.WriteCoord( self.pev.size.x);
			m.WriteCoord( self.pev.size.y);
			m.WriteCoord( self.pev.size.z);

			// velocity
			m.WriteCoord( vecVelocity.x );
			m.WriteCoord( vecVelocity.y );
			m.WriteCoord( vecVelocity.z );

			// randomization
			m.WriteByte( 10 );

			// Model
			m.WriteShort( g_EngineFuncs.ModelIndex( m_szGib ) ); //model id#

			// # of shards
			m.WriteByte( 0 ); // let client decide

			// duration
			m.WriteByte( 25 );// 2.5 seconds

			// flags
			m.WriteByte( ui8Flag );
		m.End();

		float size = self.pev.size.x;
		if ( size < self.pev.size.y )
			size = self.pev.size.y;
		if ( size < self.pev.size.z )
			size = self.pev.size.z;

		// !!! HACK  This should work!
		// Build a box above the entity that looks like an 8 pixel high sheet
		//Vector mins = self.pev.absmin;
		//Vector maxs = self.pev.absmax;
		//mins.z = self.pev.absmax.z;
		//maxs.z += 8;

		//// BUGBUG -- can only find 256 entities on a breakable -- should be enough
		//CBaseEntity *pList[256];
		//int count = UTIL_EntitiesInBox( pList, 256, mins, maxs, FL_ONGROUND );
		//if ( count )
		//{
		//	for ( int i = 0; i < count; i++ )
		//	{
		//		ClearBits( pList[i]->pev->flags, FL_ONGROUND );
		//		pList[i]->pev->groundentity = NULL;
		//	}
		//}

		// Don't fire something that could fire myself
		self.pev.targetname = "0";

		self.pev.solid = SOLID_NOT;
		// Fire targets on break
		self.SUB_UseTargets( null, USE_TOGGLE, 0 );

		//SetThink( ThinkFunction( this.SUB_Remove ) );
		//self.pev.nextthink = g_Engine.time + 0.1;
		//if ( m_iszSpawnObject )
		//	CBaseEntity::Create( (char *)STRING(m_iszSpawnObject), VecBModelOrigin(pev), pev->angles, edict() );


		//if ( Explodable() )
		//{
		//	ExplosionCreate( Center(), pev->angles, edict(), ExplosionMagnitude(), TRUE );
		//}

		g_EntityFuncs.Remove( self );
	}


	bool IsBreakable()
	{
		//Maybe we will add some additional logic here to define whether scenarios where the brush won't break
		return true;
	}
}
void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "NS_WELDABLE::func_weldable", "func_weldable" );
}
}
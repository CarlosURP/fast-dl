#include "base_turret"

/* Natural Selection Siege Turret Script
By Meryilla

Models, Sounds, and Sprites by Unknown Worlds

Additional Credit to the below for providing guidance in creating these scripts:

https://github.com/ValveSoftware/halflife Half-Life SDK - by Valve
https://twhl.info/wiki/page/Tutorial%3A_Coding_NPCs_in_GoldSrc - by dexter
Natural Selection Source Code - by Unknown Worlds
*/

namespace NS_SIEGE_TURRET
{
//Vars
enum e_sentry_anims
{
	IDLE_OFF = 0,
	FIRE,
	SPIN,
	DEPLOY,
	RETIRE,
	DIE
}
//Models
const string MODEL = "models/ns/monsters/b_siege_test_a.mdl";
const string MODEL_BLAST = "sprites/shockwave.spr";
//Sounds
const string SOUND_FIRE1 = "ns/monsters/b_siege/st_fire1.wav";
const string SOUND_DEPLOY = "ns/monsters/b_siege/siege_deploy.wav";
const string SOUND_HIT1 = "ns/monsters/b_siege/siegehit1.wav";
const string SOUND_HIT2 = "ns/monsters/b_siege/siegehit2.wav";
const string SOUND_PING = "ns/monsters/b_siege/siege_ping.wav";
const string SOUND_DEATH1 = "turret/tu_die.wav";
const string SOUND_DEATH2 = "turret/tu_die2.wav";
const string SOUND_DEATH3 = "turret/tu_die3.wav";

array<string> SOUNDS = {
	SOUND_FIRE1,
	SOUND_DEPLOY,
	SOUND_HIT1,
	SOUND_HIT2,
	SOUND_PING,
	SOUND_DEATH1,
	SOUND_DEATH2,
	SOUND_DEATH3
};
//Stats
const float SIEGE_HEALTH = 500;
const float SIEGE_DAMAGE = 400;
const float SIEGE_SPLASH_RADIUS = 300;
const float SIEGE_ROF = 4;

class CSiegeTurret : ScriptBaseMonsterEntity, NS_BASE_TURRET::TurretBase
{
	private float m_flBuildEndTime;
	private float m_flTimeLastFired;
	private bool m_blIsBuilt = false;
	private bool m_blPersistent = false;

	private int m_iModelIndex;
	private int m_iBlastIndex;

	void Precache()
	{
		m_iModelIndex = g_Game.PrecacheModel( MODEL );
		m_iBlastIndex = g_Game.PrecacheModel( MODEL_BLAST );
		for( uint i = 0; i < SOUNDS.length(); i++ )
		{
			g_SoundSystem.PrecacheSound( SOUNDS[i] );
			g_Game.PrecacheGeneric( "sound/" + SOUNDS[i] );
		}
	}

	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, MODEL );

		self.pev.movetype = MOVETYPE_TOSS;
		self.pev.solid = SOLID_SLIDEBOX;
		self.m_bloodColor = DONT_BLEED;

		g_EntityFuncs.SetSize( self.pev, Vector( -16, -16, 0 ), Vector( 16.0, 16.0, 42.0 ) );

		//TODO Health from keyvalue or cvar?
		if( self.pev.health == 0 )
			self.pev.health = SIEGE_HEALTH;
		self.pev.max_health = self.pev.health;

		PlayAnimationAtIndex( DEPLOY, true, 0.2f );

		m_flBuildEndTime = g_Engine.time + ( GetTimeForAnimation( self.pev.sequence ) / self.pev.framerate );
		Setup();

		SetThink( ThinkFunction( PreBuiltThink ) );
		self.pev.nextthink = g_Engine.time + 0.5f;

		g_SoundSystem.EmitSound( self.edict(), CHAN_AUTO, SOUND_DEPLOY, 1.0, ATTN_IDLE );

		//hardcoding whether entities are healable or not by classname is dumb af
		g_EntityFuncs.DispatchKeyValue( self.edict(), "classname", "monster_sentry" );

		//Siege Turret should turn slower - This doesn't affect idle rotations. It also reduces the delay between attacks. 
		//The base turret script needs revamping
		m_flTurnRate = M_PI/3.0f;
	}

	int Classify()
	{
		// player ally override
		if( self.IsPlayerAlly() )
			return CLASS_PLAYER_ALLY;

		// allow custom monster classifications
		if( self.m_fOverrideClass )
			return self.m_iClassSelection;

		// default
		return CLASS_MACHINE;
	}

	void PreBuiltThink()
	{
		if( m_flBuildEndTime < g_Engine.time )
		{
			m_blIsBuilt = true;
			SetEnabledState();
		}

		self.pev.nextthink = g_Engine.time + 0.1f;
	}

	void Killed( entvars_t@ pevAttacker, int iGib )
	{
		PlayAnimationAtIndex( DIE, true, 1.0f );
		TurretKilled( pevAttacker, iGib );
	}

	void Shoot ( Vector& in vecOrigin, Vector& in vecToEnemy, Vector& in vecEnemyVelocity )
	{
		// Only fire once every few seconds...this is hacky but there's no way to override think functions so it must be done
		// I wish it was easier to change the update rate but it's not so...
		if(( g_Engine.time - m_flTimeLastFired ) > GetRateOfFire() )
		{
			// Find enemy player in range, ignore walls and everything else
			if( self.m_hEnemy )
			{
				edict_t@ pentEnemy = self.m_hEnemy.GetEntity().edict();
				entvars_t@ pevEnemy = self.m_hEnemy.GetEntity().pev;
				CBaseEntity@ pEnemy = cast<CBaseEntity@>( self.m_hEnemy.GetEntity() );

				//if( GetIsValidTarget( self.m_hEnemy ) && pentEnemy !is null && pevEnemy !is null && pEnemy !is null )
				if( pentEnemy !is null && pevEnemy !is null && pEnemy !is null )
				{
					// Play view shake, because a big gun is going off
					float flShakeAmplitude = 20;
					float flShakeFrequency = 80;
					float flShakeDuration = .3f;
					float flShakeRadius = 240;
					g_PlayerFuncs.ScreenShake( self.pev.origin, flShakeAmplitude, flShakeFrequency, flShakeDuration, flShakeRadius );

					float flSiegeSplashRadius = SIEGE_SPLASH_RADIUS;
					
					// Play fire sound
					g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_WEAPON, SOUND_FIRE1, VOL_NORM, ATTN_NORM, 0, 94 + Math.RandomLong( 0, 0xF ) );
					
					self.pev.effects |= EF_MUZZLEFLASH;
					
					// Send normal effect to all
					//From what I can tell this is meant to play one of the hit sounds on the target, and display a blob explosion particle event - mery
					//PLAYBACK_EVENT_FULL(0, pentEnemy, gSiegeHitEventID, 0, pevEnemy->origin, pevEnemy->angles, 0.0, 0.0, /*theWeaponIndex*/ 0, 0, 0, 0 );

					//g_SoundSystem.EmitSoundDyn( pentEnemy, CHAN_BODY, Math.RandomLong( 0, 1 ) == 0 ? SOUND_HIT1 : SOUND_HIT2, VOL_NORM, ATTN_NORM, 0, 94 + Math.RandomLong( 0, 0xF ) );
					g_SoundSystem.PlaySound( pentEnemy, CHAN_BODY, Math.RandomLong( 0, 1 ) == 0 ? SOUND_HIT1 : SOUND_HIT2, VOL_NORM, ATTN_NORM, 0, 94 + Math.RandomLong( 0, 0xF ), 0, true, pevEnemy.origin );

					// Play view shake where it hits as well
					flShakeAmplitude = 60;
					flShakeFrequency = 120;
					flShakeDuration = 1.0f;
					flShakeRadius = 650;
					g_PlayerFuncs.ScreenShake( pevEnemy.origin, flShakeAmplitude, flShakeFrequency, flShakeDuration, flShakeRadius );
					
					if( pEnemy.IsPlayer() )
					{
						// Send personal view shake to recipient only (check for splash here, pass param to lessen effect for others?)
						//From what I can tell this performs punchangles on the target player. See EV_SiegeViewHit for reference - mery
						// TODO: Use upgrade level to parameterize screen shake and fade?
						//PLAYBACK_EVENT_FULL(FEV_HOSTONLY, pentEnemy, gSiegeViewHitEventID, 0, pevEnemy->origin, pevEnemy->angles, 0.0, 0.0, /*theWeaponIndex*/ 0, 0, 0, 0 );
						
						Vector vecFadeColor;
						vecFadeColor.x = 255;
						vecFadeColor.y = 100;
						vecFadeColor.z = 100;
						g_PlayerFuncs.ScreenFade( self.m_hEnemy, vecFadeColor, .3f, 0.0f, 255, FFADE_OUT );
					}

					// blast circles
					NetworkMessage blast( MSG_PAS, NetworkMessages::SVC_TEMPENTITY, pevEnemy.origin );
						blast.WriteByte( TE_BEAMCYLINDER );
						blast.WriteCoord( pevEnemy.origin.x);
						blast.WriteCoord( pevEnemy.origin.y);
						blast.WriteCoord( pevEnemy.origin.z + 16);
						blast.WriteCoord( pevEnemy.origin.x);
						blast.WriteCoord( pevEnemy.origin.y);
						blast.WriteCoord( pevEnemy.origin.z + 16 + flSiegeSplashRadius / .2); // reach damage radius over .3 seconds
						blast.WriteShort( m_iBlastIndex );
						blast.WriteByte( 0 ); // startframe
						blast.WriteByte( 0 ); // framerate
						blast.WriteByte( 2 ); // life
						blast.WriteByte( 16 ); // width
						blast.WriteByte( 0 ); // noise
					
						// Write color
						blast.WriteByte(188);
						blast.WriteByte(220);
						blast.WriteByte(255);
					
						blast.WriteByte( 255 ); //brightness
						blast.WriteByte( 0 ); // speed
					blast.End();

					// Finally, do damage (do damage after sending effects because m_hEnemy seems to be going to NULL)
					//Sonic damage or something else? - mery
					RadiusDamage( pevEnemy.origin, self.pev, self.pev, SIEGE_DAMAGE, flSiegeSplashRadius, CLASS_NONE, DMG_SONIC );
				}
				else
				{
					self.m_hEnemy = null;
				}
			}

			m_flTimeLastFired = g_Engine.time;
		}
	}

	//bool GetIsValidTarget( EHandle hEntity )
	//{
	//	bool blValid = false;
	//	
	//	if(AvHMarineTurret::GetIsValidTarget(inEntity))
	//	{
	//		if(!inEntity->IsPlayer() && !FStrEq(STRING(inEntity->pev->classname), kwsBabblerProjectile))
	//		{
	//			float theDistanceToCurrentEnemy = AvHSUEyeToBodyDistance(this->pev, inEntity);
	//			//if(theDistanceToCurrentEnemy >= this->GetMinimumRange())
	//			//{
	//				// We have to see it as well
	//				//Vector vecMid = this->pev->origin + this->pev->view_ofs;
	//				//Vector vecMidEnemy = inEntity->BodyTarget(vecMid);
	//				//if(FBoxVisible(this->pev, inEntity->pev, vecMidEnemy))
	//				//{
//
	//				// Entities must be sighted to be hit (in view of player or scanned)
	//				AvHSiegeTurret* thisTurret = const_cast<AvHSiegeTurret*>(this);
	//				if(GetHasUpgrade(inEntity->pev->iuser4, MASK_VIS_SIGHTED) || inEntity->FVisible(thisTurret))
	//				{
	//					blValid = true;
	//				}
	//				//}
	//			//}
	//		}
	//	}
	//	return blValid;
	//}

	int MoveTurret()
	{
		return BaseMoveTurret();
	}

	float GetPointsForDamage( float flDamage )
	{
		//return ( flDamage/self.pev.max_health ) * ( 6 * ( self.pev.max_health/sk_siegeturret_health.value ) );
		return ( flDamage/self.pev.max_health ) * ( 6 );
	}

	bool GetIsOrganic()
	{
		return false;
	}

	bool HasDeathAnim()
	{
		return false;
	}		

	bool IsMachine()
	{
		return true;
	}

	int	GetXYRange()
	{
		return 1200;
	}

	int	GetMinXYRange()
	{
		return SIEGE_SPLASH_RADIUS + 1;
	}

	string GetKilledSound()
	{
		switch( Math.RandomLong( 0, 2 ) )
		{
			case 0:
				return SOUND_DEATH1;
			case 1:
				return SOUND_DEATH2;
			case 2:
				return SOUND_DEATH3;
		}
		return SOUND_DEATH1;
	}

	string GetPingSound()
	{
		return SOUND_PING;
	}

	int GetSetEnabledAnimation()
	{
		return 3;
	}

	bool GetRequiresLOS()
	{
		return false;
	}

	float GetRateOfFire()
	{
		return SIEGE_ROF;
	}	

	//AAAAAAAAAAAAAAAAAAAAAAAAAAA THIS IS SO DUMB WHY DOESN'T AS EXPOSE STUDIO MODEL FUNCS AHHHHHHHHHHHHHHHHHHHHH
	float GetTimeForAnimation( int iIndex )
	{
		switch( iIndex )
		{
			case 0:
				return (13.0f);
			case 1:
				return (63.0f/100.0f);
			case 2:
				return (9.0f/20.0f);
			case 3:
				return (163.0f/100.0f);
			case 4:
				return (9.0f/10.0f);
			case 5:
				return (1.0f/2.0f);
		}
		return 0.0f;
	}	
}
void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "NS_SIEGE_TURRET::CSiegeTurret", "monster_siegeturret" );
}
}
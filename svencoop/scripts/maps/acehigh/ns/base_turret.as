#include "quat"
#include "vectorUtils"
/* Natural Selection Base Turret Script
By Meryilla

Models, Sounds, and Sprites by Unknown Worlds

Additional Credit to the below for providing guidance in creating these scripts:

https://github.com/ValveSoftware/halflife Half-Life SDK - by Valve
https://twhl.info/wiki/page/Tutorial%3A_Coding_NPCs_in_GoldSrc - by dexter
Natural Selection Source Code - by Unknown Worlds
*/

namespace NS_BASE_TURRET
{

const float TURRET_PING_INTERVAL = 3.0f;
const float TURRET_PING_VOL = .4f;

const float TURRET_TRACKING_RATE = 3.0f;
const float TURRET_THINK_INTERVAL = 0.05f;
const float TURRET_UPDATE_ENEMY_INTERVAL = .25f;
const float TURRET_SEARCH_SCALER = TURRET_THINK_INTERVAL*(-90.0f/180)*M_PI;

const float VERTICAL_FOV = 30.0f;

//Models
const string MODEL_DEATH_SPRITE = "sprites/ns/chamberdeath.spr";
const string MODEL_GIBS = "models/computergibs.mdl";
const string SMOKE_SPRITE = "sprites/steam1.spr";
const string EXPLODE_SPRITE = "sprites/zerogxplode.spr";

mixin class TurretBase
{
	protected float m_flTimeAnimationDone = 0;
	protected int m_iLastAnimationPlayed = -1;

	protected bool m_blIsDying = false;

	protected float m_flTimeOfLastUpdateEnemy = -1;
	protected float m_flTurnRate;
	protected float m_flNextPingTime;
	protected float m_flTimeOfNextAttack = -1.0f; 
	protected Quat m_quatGoal( 0, 0, 0, 1 );  
	protected Quat m_quatCur( 0, 0, 0, 1 );

	void CommonPrecache()
	{
		g_Game.PrecacheModel( MODEL_DEATH_SPRITE );
		g_Game.PrecacheModel( MODEL_GIBS );
		g_Game.PrecacheModel( SMOKE_SPRITE );
		g_Game.PrecacheModel( EXPLODE_SPRITE );
	}

	void Setup()
	{
		//self.pev.nextthink = g_Engine.time + 1;
		self.pev.frame = 0;
		self.pev.takedamage = DAMAGE_AIM;
		m_flNextPingTime = 0;
		self.m_flFieldOfView = VIEW_FIELD_FULL;
		m_flTurnRate = TURRET_TRACKING_RATE;
		
		// This is the visual difference between model origin and gun barrel, it's needed to orient the barrel and hit targets properly
		self.pev.view_ofs.z = 48;
		
		self.pev.flags |= FL_MONSTER;
		
		self.SetBoneController(0, 0);
		self.SetBoneController(1, 0);

		m_blIsBuilt = false;
	}

	float GetTimeAnimationDone()
	{
		return m_flTimeAnimationDone;
	}

	//float GetTimeForAnimation( int iIndex ) 
	//{
	//    return GetSequenceDuration(GET_MODEL_PTR(ENT(pev)), this.pev);
	//}    

	void SetEnabledState()
	{
		int iEnabledAnimation = GetSetEnabledAnimation();
		if( !m_blIsBuilt )
		{
			self.m_hEnemy = null;
			SetThink( null );
		}
		else
		{
			float flTimeToAnimate = Math.max( g_Engine.time + TURRET_THINK_INTERVAL, GetTimeAnimationDone() );
			SetThink( ThinkFunction( SearchThink ) );
			self.pev.nextthink = flTimeToAnimate;
		}
	}

	void PlayAnimationAtIndex( int iIndex, bool blForce = false, float flFrameRate = 1.0f )
	{
		// Allow forcing of new animation, but it's better to complete current animation then interrupt it and play it again
		float flCurrentTime = g_Engine.time;
		if( ( flCurrentTime >= m_flTimeAnimationDone ) || ( blForce && ( iIndex != m_iLastAnimationPlayed ) ) )
		{
			self.pev.sequence = iIndex;
			self.pev.frame = 0;
			self.ResetSequenceInfo();

			self.pev.framerate = flFrameRate;

			// Set to last frame to play backwards
			if( self.pev.framerate < 0 )
			{
				self.pev.frame = 255;
			}

			m_iLastAnimationPlayed = iIndex;
			float flTimeForAnim = GetTimeForAnimation( iIndex );
			m_flTimeAnimationDone = flCurrentTime + flTimeForAnim;
		}
	}
	void SearchThink()
	{ 
		//TODO Below seems to be enabled depending on GetBaseClassAnimatesTurret in NS source
		if( self.pev.sequence != 2 )
			self.pev.sequence = 2;

		//self.ResetSequenceInfo();
		//self.StudioFrameAdvance();

		//TEMP - check here if alien turret is fucked after commenting this out
		//if( self.pev.sequence != 2 )
		//    self.pev.sequence = 2;

		self.pev.nextthink = g_Engine.time + TURRET_THINK_INTERVAL;
		
		Ping();
		
		// If we have a target and we're still healthy
		if( self.m_hEnemy )
		{
			if( !( self.m_hEnemy.GetEntity().IsAlive() ) )
			{
				self.m_hEnemy = null;// Dead enemy forces a search for new one
			}
		}
		
		// Acquire Target
		UpdateEnemy();

		// If we've found a target, spin up the barrel and start to attack
		if( self.m_hEnemy )
		{
			//this.m_flSpinUpTime = 0;
			SetThink( ThinkFunction( ActiveThink ) );
		}

		TurretUpdate();
	}

	void UpdateEnemy()
	{
		// If enabled
		if( m_blIsBuilt )
		{
			// If time to find new enemy
			float flCurrentTime = g_Engine.time;

			if( ( m_flTimeOfLastUpdateEnemy == -1 ) || ( flCurrentTime >  ( m_flTimeOfLastUpdateEnemy + TURRET_UPDATE_ENEMY_INTERVAL ) ) )
			{
				// Find new best enemy
				self.m_hEnemy = FindBestEnemy();
				m_flTimeOfLastUpdateEnemy = flCurrentTime;
			}
		}
		else
		{
			// Clear current enemy
			self.m_hEnemy = null;
		}
	}

	void Ping()
	{
		// Make the pinging noise every second while searching
		if( m_flNextPingTime == 0 )
		{
			m_flNextPingTime = g_Engine.time + TURRET_PING_INTERVAL;
		}
		else if( m_flNextPingTime <= g_Engine.time )
		{
			string szPingSound = GetPingSound();
			if( !szPingSound.IsEmpty() )
			{
				m_flNextPingTime = g_Engine.time + TURRET_PING_INTERVAL;
				g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, szPingSound, TURRET_PING_VOL, ATTN_STATIC );
				//EyeOn( );
			}
		}
		//	else if (m_eyeBrightness > 0)
		//	{
		//		EyeOff( );
		//	}
	}      

	// This function takes a lot of CPU, so make sure it's not called often!  Don't call this function directly, use UpdateEnemy instead whenever possible.
	EHandle FindBestEnemy()
	{
		array<CBaseEntity@> theEntityList(100);
		
		int iMaxRange = GetXYRange();
		int iMinRange = GetMinXYRange();
		
		Vector vecDelta = Vector( iMaxRange, iMaxRange, iMaxRange );
		CBaseEntity@ pCurrentEntity, pBestEntity;

		float flCurrentEntityRange = 100000;
		
		// Find only monsters/clients in box, NOT limited to PVS
		//int iCount = g_EntityFuncs.EntitiesInBox( theEntityList, 100, self.pev.origin - vecDelta, self.pev.origin + vecDelta, FL_CLIENT | FL_MONSTER );
		int iCount = g_EntityFuncs.EntitiesInBox( theEntityList, self.pev.origin - vecDelta, self.pev.origin + vecDelta, FL_CLIENT | FL_MONSTER );
		for( int i = 0; i < iCount; i++ )
		{
			@pCurrentEntity = theEntityList[i];
			if( ( pCurrentEntity !is self ) && pCurrentEntity.IsAlive() )
			{
				// the looker will want to consider this entity
				// don't check anything else about an entity that can't be seen, or an entity that you don't care about.
				//if( self.IRelationship( pCurrentEntity ) > 0 && self.FInViewCone( pCurrentEntity ) && 
				//    !pCurrentEntity.pev.FlagBitSet( FL_NOTARGET ) )
				if( !( self.IRelationship( pCurrentEntity ) > 0) )
				{
					continue;
				}
				if( !( self.FInViewCone( pCurrentEntity ) ) )
				{
					continue;
				}
				if( ( pCurrentEntity.pev.FlagBitSet( FL_NOTARGET ) ) )
				{
					continue;
				}

				// Find nearest enemy
				float flRangeToTarget = ( pCurrentEntity.pev.origin - self.pev.origin ).Length2D();
				if( flRangeToTarget < flCurrentEntityRange  && flRangeToTarget > iMinRange )
				{
					// FVisible is expensive, so defer until necessary
					if( !GetRequiresLOS() || self.FVisible( pCurrentEntity, true ) )
					{
						flCurrentEntityRange = flRangeToTarget;
						@pBestEntity = pCurrentEntity;
					}
				}
			}
		}
		return EHandle( pBestEntity );
	}
	void ActiveThink()
	{
		// Advance model frame
		self.StudioFrameAdvance();

		// Find enemy, or reacquire dead enemy
		UpdateEnemy();

		// If we have a valid enemy
		if( self.m_hEnemy && !FNullEnt( self.m_hEnemy.GetEntity().edict() ) )
		{
			// If enemy is in FOV
			Vector vecMid = self.pev.origin + self.pev.view_ofs;
			//AvHSUPlayParticleEvent("JetpackEffect", this.edict(), vecMid);

			CBaseEntity@ pEnemyEntity = cast<CBaseEntity@>( self.m_hEnemy.GetEntity() );
			Vector vecMidEnemy = pEnemyEntity.BodyTarget( vecMid );

			//AvHSUPlayParticleEvent("JetpackEffect", vecMidEnemy.edict(), vecMidEnemy);

			// calculate dir and dist to enemy
			Vector vecDirToEnemy = vecMidEnemy - vecMid;
			Vector vecAddition = vecMid + vecDirToEnemy;

			Vector vecLOS = vecDirToEnemy.Normalize();

			// Update our goal angles to direction to enemy
			Vector vecDirToEnemyAngles;
			//VectorAngles( vecDirToEnemy, vecDirToEnemyAngles );
			vecDirToEnemyAngles = Math.VecToAngles( vecDirToEnemy );

			// Set goal quaternion
			//Do we REALLY want to use quats here just because they do in NS?
			 m_quatGoal = Quat( vecDirToEnemyAngles );

			// Is the turret looking at the target yet?
			float flRadians = ( VERTICAL_FOV/180.0f )*3.1415f;
			float flCosVerticalFOV = cos( flRadians );

			Vector vecCurrentAngles;
			m_quatCur.GetAngles( vecCurrentAngles );
			Math.MakeAimVectors( vecCurrentAngles );

			if( DotProduct( vecLOS, g_Engine.v_forward) > flCosVerticalFOV )
			{
				// If enemy is visible
				//Lets just use FVisible here, rather than this slower FBoxVisible from NS
				//bool blEnemyVisible = FBoxVisible( self.pev, pEnemyEntity.pev, vecMidEnemy ) || !GetRequiresLOS();
				bool blEnemyVisible = self.FVisible( pEnemyEntity, true ) || !GetRequiresLOS();
				if( blEnemyVisible && pEnemyEntity.IsAlive() )
				{
					// If it's time to attack
					if( ( m_flTimeOfNextAttack == -1) || ( g_Engine.time >= m_flTimeOfNextAttack ) )
					{
						// Shoot and play shoot animation
						Shoot( vecMid, vecDirToEnemy, pEnemyEntity.pev.velocity );
						
						PlayAnimationAtIndex( GetActiveAnimation() );
						
						// Set time for next attack
						SetNextAttack();
					}
					// spin the barrel when acquired but not firing
					//TODO figure this shit out
					//else if( GetBaseClassAnimatesTurret() )
					//{
					//    self.pev.sequence = 2;
					//    self.ResetSequenceInfo();
					//}
				}
			}
			else
			{
				//TODO: REmove and replace with somethin better
				if( self.pev.sequence != 2 )
					self.pev.sequence = 2;

				//self.ResetSequenceInfo();
				//self.StudioFrameAdvance();
			}

			// Set next active think
			self.pev.nextthink = g_Engine.time + TURRET_THINK_INTERVAL;
		}
		// else we have no enemy, go back to search think
		else
		{
			SetThink( ThinkFunction( SearchThink ) );
			self.pev.nextthink = g_Engine.time + TURRET_THINK_INTERVAL;
		}

		TurretUpdate();
	}

	void TurretUpdate()
	{
		MoveTurret();
	}

	int BaseMoveTurret()
	{
		//ASSERT(this.m_flTurnRate > 0);
		// We have an enemy, track towards goal angles
		if( self.m_hEnemy )
		{
			float flRate = m_flTurnRate*TURRET_THINK_INTERVAL;
			m_quatCur = ConstantRateLerp( m_quatCur, m_quatGoal, flRate );
		}
		// generic hunt for new victims
		else
		{
			// Create transformation quat that will rotate current quat
			Vector vecAxis = Vector( 0.0f, 0.0f, 1.0f );
			Quat rot( TURRET_SEARCH_SCALER, vecAxis );

			m_quatCur = rot*m_quatCur;

			// Reset height
		}

		Vector vecAngles;
		m_quatCur.GetAngles( vecAngles );

		//SetBoneController(0, m_vecCurAngles.y - pev.angles.y );
		self.SetBoneController( 0, vecAngles.y - self.pev.angles.y );
		self.SetBoneController( 1, -vecAngles.x );

		return 0;
	}
	

	void TurretKilled( entvars_t@ pevAttacker, int iGib )
	{
		//AvHBaseBuildable::SetHasBeenKilled();
		//GetGameRules().RemoveEntityUnderAttack( this.entindex() );

		//this.mKilled = true;
		//this.mInternalSetConstructionComplete = false;
		//this.mTimeOfLastAutoHeal = -1;

		//Stops effects from running multiple times on top of each other when destroyed by explosives or shotguns
		if( !m_blIsDying )
			TriggerDeathAudioVisuals();
		
		if( !GetIsOrganic() )
		{
			int numSparks = 3;
			for( int i=0; i < numSparks; i++ ) 
			{
				Vector vecSrc = Vector( Math.RandomFloat( self.pev.absmin.x, self.pev.absmax.x ), Math.RandomFloat( self.pev.absmin.y, self.pev.absmax.y ), 0 );
				vecSrc = vecSrc + Vector( 0, 0, Math.RandomFloat( self.pev.origin.z, self.pev.absmax.z ) );
				g_Utility.Sparks( vecSrc );
			}
		}
		// :

		//The below isn't necessary as we will make use of GetPointsForDamage instead for scoring
		//if( pevAttacker !is null )
		//{
		//    const char* theClassName = STRING(this.pev.classname);
		//    AvHPlayer* inPlayer = dynamic_cast<AvHPlayer*>(CBaseEntity::Instance(ENT(pevAttacker)));
		//    if(inPlayer && theClassName)
		//    {
		//        inPlayer.LogPlayerAction("structure_destroyed", theClassName);
		//        GetGameRules().RewardPlayerForKill(inPlayer, this);
		//    }
		//}
		SetThink(null);
		//TODO Add this in, add keyvalue to allow mappers to make the turret permanent
		if( m_blPersistent )
		{
			SetInactive();
		}
		else
		{
			if( !HasDeathAnim() )
			{
				//RIP
				g_EntityFuncs.Remove( self );
			}
			else
			{
				self.pev.health = 0;
				self.pev.takedamage = DAMAGE_NO;
				self.pev.dmgtime = g_Engine.time;
				self.pev.flags &= ~FL_MONSTER;  
				self.pev.solid = SOLID_NOT;
				SetThink( ThinkFunction( FadeOut ) );
				self.pev.nextthink = g_Engine.time + 12.0f;
			}
		}
		BaseClass.Killed( pevAttacker, iGib );
	}

	void FadeOut()
	{
		self.pev.nextthink = g_Engine.time + 0.1f;

		if( self.pev.rendermode == kRenderNormal )
		{
			self.pev.renderamt = 255;
			self.pev.rendermode = kRenderTransTexture;
		}

		if( self.pev.renderamt > 7 )
		{
			self.pev.renderamt -= 7;
		}
		else
		{
			SetThink(null);
			self.pev.renderamt = 0;
			g_EntityFuncs.Remove( self );
		}
	}

	void TriggerDeathAudioVisuals()
	{
		m_blIsDying = true;
		if( GetIsOrganic() )
		{
			Vector vecDir = Vector( 0, 0, 5 );
			te_spray( self.pev.origin, vecDir, MODEL_DEATH_SPRITE, 15, 40, 120, 5 );
		}
		else if( !HasDeathAnim() )
		{
			//If the model has no death animation, just do an explosion + gibs. Kind of lame but better than nothing
			NetworkMessage explode( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
			explode.WriteByte( TE_EXPLOSION );
			explode.WriteCoord( self.pev.origin.x);
			explode.WriteCoord( self.pev.origin.y );
			explode.WriteCoord( self.pev.origin.z );
			explode.WriteShort( g_EngineFuncs.ModelIndex( EXPLODE_SPRITE ) );
			explode.WriteByte( 10 ); //scale
			explode.WriteByte( 15 ); //framerate
			explode.WriteByte( 0 ); //flags
			explode.End();

			Vector vecSize = self.pev.maxs - self.pev.mins;

			NetworkMessage gibs( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
			gibs.WriteByte( TE_BREAKMODEL );
			gibs.WriteCoord( self.pev.origin.x );
			gibs.WriteCoord( self.pev.origin.y );
			gibs.WriteCoord( self.pev.origin.z + 20 );
			gibs.WriteCoord( vecSize.x );
			gibs.WriteCoord( vecSize.y );
			gibs.WriteCoord( vecSize.z );
			gibs.WriteCoord( 0 ); //velocity x, y, and z
			gibs.WriteCoord( 0 );
			gibs.WriteCoord( 0 );
			gibs.WriteByte( 16 ); //speedNoise
			gibs.WriteShort( g_EngineFuncs.ModelIndex( MODEL_GIBS ) );
			gibs.WriteByte( 8 ); //count
			gibs.WriteByte( 8 ); //life
			gibs.WriteByte( 2 ); //flags
			gibs.End();
		}
		else
		{
			// lots of smoke
			NetworkMessage smoke( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
			smoke.WriteByte( TE_SMOKE );
			smoke.WriteCoord( Math.RandomFloat( self.pev.absmin.x, self.pev.absmax.x ) );
			smoke.WriteCoord( Math.RandomFloat( self.pev.absmin.y, self.pev.absmax.y ) );
			smoke.WriteCoord( Math.RandomFloat( self.pev.absmin.z, self.pev.absmax.z ) );
			smoke.WriteShort( g_EngineFuncs.ModelIndex( SMOKE_SPRITE ) );
			smoke.WriteByte( 15 ); // scale * 10
			smoke.WriteByte( 8 ); // framerate
			smoke.End();
		}
		
		g_SoundSystem.EmitSound( self.edict(), CHAN_AUTO, GetKilledSound(), 1.0, ATTN_IDLE );
	}

	void te_spray(Vector pos, Vector dir, string sprite="sprites/ns/chamberdeath.spr", 
		uint8 count=8, uint8 speed=127, uint8 noise=255, uint8 rendermode=0,
		NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null)
	{
		NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);
		m.WriteByte(TE_SPRAY);
		m.WriteCoord(pos.x);
		m.WriteCoord(pos.y);
		m.WriteCoord(pos.z);
		m.WriteCoord(dir.x);
		m.WriteCoord(dir.y);
		m.WriteCoord(dir.z);
		m.WriteShort(g_EngineFuncs.ModelIndex(sprite));
		m.WriteByte(count);
		m.WriteByte(speed);
		m.WriteByte(noise);
		m.WriteByte(rendermode);
		m.End();
	}

	void SetInactive()
	{

	} 

	void SetNextAttack()
	{
		m_flTimeOfNextAttack = g_Engine.time + GetRateOfFire();
	}

	int	GetActiveAnimation()
	{
		return 1;
	}

	//HLSDK implementation of RadiusDamage, plus some tweaks to ensure turrets can't hurt themselves or friendlies
	void RadiusDamage( Vector vecSrc, entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, float flRadius, int iClassIgnore, int bitsDamageType )
	{
		CBaseEntity@ pEntity;
		TraceResult	tr;
		float flAdjustedDamage, falloff;
		Vector vecSpot;

		if ( flRadius > 0 )
			falloff = flDamage / flRadius;
		else
			falloff = 1.0;

		bool bInWater = ( g_EngineFuncs.PointContents( vecSrc ) == CONTENTS_WATER );

		vecSrc.z += 1; // in case grenade is lying on the ground

		if ( pevAttacker is null )
			@pevAttacker = @pevInflictor;

		// iterate on all entities in the vicinity.
		while( ( @pEntity = g_EntityFuncs.FindEntityInSphere( pEntity, vecSrc, flRadius, "*", "classname" ) ) != null )
		{
			if ( pEntity.pev.takedamage != DAMAGE_NO )
			{
				//Don't hurt yourself or friendlies!
				if( pEntity == g_EntityFuncs.Instance( pevInflictor ) || !( g_EntityFuncs.Instance( pevInflictor ).IRelationship( pEntity ) > 0 ) )
					continue;
				// UNDONE: this should check a damage mask, not an ignore
				if ( iClassIgnore != CLASS_NONE && pEntity.Classify() == iClassIgnore )
				{// houndeyes don't hurt other houndeyes with their attack
					continue;
				}

				// blast's don't tavel into or out of water
				if( bInWater && pEntity.pev.waterlevel == 0 )
					continue;
				if( !bInWater && pEntity.pev.waterlevel == 3 )
					continue;

				vecSpot = pEntity.BodyTarget( vecSrc );
				
				g_Utility.TraceLine( vecSrc, vecSpot, dont_ignore_monsters, g_EntityFuncs.Instance( pevInflictor ).edict(), tr );

				if( tr.flFraction == 1.0 || g_EntityFuncs.Instance( tr.pHit ).entindex() == pEntity.entindex() )
				{// the explosion can 'see' this entity, so hurt them!
					if( tr.fStartSolid != 0 )
					{
						// if we're stuck inside them, fixup the position and distance
						tr.vecEndPos = vecSrc;
						tr.flFraction = 0.0;
					}
					
					// decrease damage for an ent that's farther from the bomb.
					flAdjustedDamage = ( vecSrc - tr.vecEndPos ).Length() * falloff;
					flAdjustedDamage = flDamage - flAdjustedDamage;
				
					if( flAdjustedDamage < 0 )
						flAdjustedDamage = 0;
				
					// ALERT( at_console, "hit %s\n", STRING( pEntity.pev.classname ) );
					if( tr.flFraction != 1.0 )
					{
						g_WeaponFuncs.ClearMultiDamage( );
						pEntity.TraceAttack( pevInflictor, flAdjustedDamage, ( tr.vecEndPos - vecSrc ).Normalize( ), tr, bitsDamageType );
						g_WeaponFuncs.ApplyMultiDamage( pevInflictor, pevAttacker );
					}
					else
					{
						pEntity.TakeDamage ( pevInflictor, pevAttacker, flAdjustedDamage, bitsDamageType );
					}
				}
			}
		}
	}	
}
}
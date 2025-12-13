//AlienShooter MAP effect//
//email:Dr.Abc@foxmail.con//
//请勿擅自修改

const Vector VECTOR_CONE_ALIEN_SHOTGUN( 0.17365, 0.04362, 0.00 );
const uint SHOTGUN_CONE_ALIEN_PELLETCOUNT = 12;

void Precache()
	{
		g_Game.PrecacheModel( "models/xen_rockgib_small.mdl" );
		g_Game.PrecacheModel( "sprites/crosshairs.spr" );
		g_Game.PrecacheModel( "sprites/laserbeam.spr" );
		g_Game.PrecacheModel( "models/alienshooter/alien_health_huge.mdl" );
		g_Game.PrecacheModel( "models/alienshooter/alien_vest_red.mdl" );
		g_Game.PrecacheModel( "models/hlclassic/grenade.mdl" );

		g_SoundSystem.PrecacheSound( "alienshooter/take_healh.wav" );
		g_SoundSystem.PrecacheSound( "alienshooter/pick_armor.wav" );
	}

void AlienSshoottr(Vector pos, float velocity,int amount)
	{
			NetworkMessage m(MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY, null);
				m.WriteByte(TE_EXPLODEMODEL);
				m.WriteCoord(pos.x);
				m.WriteCoord(pos.y);
				m.WriteCoord(pos.z);
				m.WriteCoord(velocity);
				m.WriteShort(g_EngineFuncs.ModelIndex("models/xen_rockgib_small.mdl"));
				m.WriteShort(amount);
				m.WriteByte(10);
			m.End();
	}
	
void AlienSexplosionte_explodemodel(Vector pos, float velocity,
		string model, uint16 count, uint8 life,
		NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null)
	{
			NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);
				m.WriteByte(TE_EXPLODEMODEL);
				m.WriteCoord(pos.x);
				m.WriteCoord(pos.y);
				m.WriteCoord(pos.z);
				m.WriteCoord(velocity);
				m.WriteShort(g_EngineFuncs.ModelIndex(model));
				m.WriteShort(count);
				m.WriteByte(life);
			m.End();
			
			NetworkMessage m1(msgType, NetworkMessages::SVC_TEMPENTITY, dest);
				m1.WriteByte(TE_TAREXPLOSION);
				m1.WriteCoord(pos.x);
				m1.WriteCoord(pos.y);
				m1.WriteCoord(pos.z);
			m1.End();
	}
	
void AlienSexplosion( Vector origin, string sprite, int scale, int frameRate, int flags )//过程explosion
	{
		NetworkMessage exp1( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY);//调用spr
			exp1.WriteByte ( TE_EXPLOSION );
			exp1.WriteCoord( origin.x );
			exp1.WriteCoord( origin.y );
			exp1.WriteCoord( origin.z );
			exp1.WriteShort( g_EngineFuncs.ModelIndex(sprite) );
			exp1.WriteByte ( int((scale-2) * .3) );//spr缩放大小
			exp1.WriteByte ( frameRate );//spr播放速率
			exp1.WriteByte ( flags );
		exp1.End();
	}
	
void AlienTrail (CBaseEntity@ wut,int r,int g,int b,int a,int time,int size)
	{
	    int tailId = g_EntityFuncs.EntIndex(wut.edict());
        int sprId  = g_EngineFuncs.ModelIndex("sprites/laserbeam.spr");
        NetworkMessage nm(MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY, null);
			nm.WriteByte(TE_BEAMFOLLOW);
			nm.WriteShort(tailId);
			nm.WriteShort(sprId);
			nm.WriteByte(time);    // 时间
			nm.WriteByte(size);    // 大小
			nm.WriteByte(r);  // R
			nm.WriteByte(g);  // G
			nm.WriteByte(b);  // B
			nm.WriteByte(a);   // A
        nm.End();
	}
	
void AlienSExplode(int ExpDmg,int ExpRad, CBaseEntity@pItem)//过程Explode
	{	
		TraceResult tr;
		tr = g_Utility.GetGlobalTrace();
		
		entvars_t@ pevOwner = pItem.pev.owner.vars;
		AlienSexplosion( pItem.pev.origin, "sprites/eexplo.spr", ExpDmg, 30, TE_EXPLFLAG_NONE );//调用explosion
		AlienSexplosionte_explodemodel(pItem.pev.origin,500,"models/metalgibs.mdl",24,45);
		g_WeaponFuncs.RadiusDamage( pItem.pev.origin,pItem.pev, pevOwner, ExpDmg, ExpRad,CLASS_NONE, DMG_BLAST | DMG_ALWAYSGIB );
		g_Utility.DecalTrace( tr, DECAL_SCORCH1 + Math.RandomLong(0,1) );
	}
	
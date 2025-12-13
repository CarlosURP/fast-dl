//AlienShooter Items//
//email:Dr.Abc@foxmail.con//
//请勿擅自修改

class item_alien_hugemed: ScriptBasePlayerAmmoEntity
{
	void Spawn()
	{ 
		g_EntityFuncs.SetModel( self, "models/alienshooter/alien_health_huge.mdl" );
		BaseClass.Spawn();
		g_EntityFuncs.SetSize(self.pev, Vector( -4, -4, -4 ), Vector( 4, 4, 4 ));
	}
	
	bool AddAmmo(CBaseEntity@ pOther)
	{
		CBasePlayer@ pPlayer = cast<CBasePlayer@>(pOther);
		NetworkMessage message( MSG_ONE, NetworkMessages::ItemPickup, pPlayer.edict() );
			message.WriteString("item_healthkit"); 
		message.End();
		
		g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, "alienshooter/take_healh.wav", 1, ATTN_NORM);
		pPlayer.pev.health += 200;
				
		return true;
	}
}

class item_alien_hugearm: ScriptBasePlayerAmmoEntity
{
	void Spawn()
	{ 
		g_EntityFuncs.SetModel( self, "models/alienshooter/alien_vest_red.mdl" );
		BaseClass.Spawn();
		g_EntityFuncs.SetSize(self.pev, Vector( -4, -4, -4 ), Vector( 4, 4, 4 ));
	}
	
	bool AddAmmo(CBaseEntity@ pOther)
	{
		CBasePlayer@ pPlayer = cast<CBasePlayer@>(pOther);
		NetworkMessage message( MSG_ONE, NetworkMessages::ItemPickup, pPlayer.edict() );
			message.WriteString("item_battery");
		message.End();
		
		g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, "alienshooter/pick_armor.wav", 1, ATTN_NORM);
		pPlayer.pev.armorvalue += 200;
				
		return true;
	}
}

class alien_arnade : ScriptBaseEntity 
{
    void Spawn() 
	{
        pev.solid = SOLID_SLIDEBOX;
        pev.movetype = MOVETYPE_TOSS;
        pev.scale = 1;
        g_EntityFuncs.SetModel( self, "models/hlclassic/grenade.mdl");
    }

    void Touch ( CBaseEntity@ pOther ) 
	{
		if( g_EngineFuncs.PointContents( self.pev.origin ) == CONTENTS_SKY )
		{
			g_EntityFuncs.Remove( self );
			return;
		}
			entvars_t@ pevOwner = self.pev.owner.vars;
            AlienSExplode(60,150,self);
            g_EntityFuncs.Remove( self ); 
	}
}

class alien_rpg : ScriptBaseEntity 
{
    void Spawn() 
	{
        pev.solid = SOLID_SLIDEBOX;
        pev.movetype = MOVETYPE_FLY;
        pev.scale = 1;
        g_EntityFuncs.SetModel( self, "models/hlclassic/grenade.mdl");
    }

    void Touch ( CBaseEntity@ pOther ) 
	{
		if( g_EngineFuncs.PointContents( self.pev.origin ) == CONTENTS_SKY )
		{
			g_EntityFuncs.Remove( self );
			return;
		}
			entvars_t@ pevOwner = self.pev.owner.vars;
            AlienSExplode(80,150,self);
            g_EntityFuncs.Remove( self ); 
	}
}

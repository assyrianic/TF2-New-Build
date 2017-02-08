

methodmap CBaseStructure < Handle {
	public CBaseStructure()
	{
		return view_as<CBaseStructure>( new StringMap() );
	}
	
	property int iEntity		/* automatically converts between entity indexes and references */
	{
		public get()
		{
			int item; AsMap(this).GetValue("iEntity", item);
			return EntRefToEntIndex( item );
		}
		public set( const int val )
		{
			AsMap(this).SetValue("iEntity", EntIndexToEntRef(val));
		}
	}
	property int iFlags		/* structure flags */
	{
		public get()
		{
			int item; AsMap(this).GetValue("iFlags", item);
			return item;
		}
		public set( const int val )
		{
			AsMap(this).SetValue("iFlags", val);
		}
	}
	property int iType
	{
		public get()
		{
			int item; AsMap(this).GetValue("iType", item);
			return (item);
		}
		public set( const int val )
		{
			AsMap(this).SetValue("iType", val);
		}
	}
	property int iBuilder		/* set as userid, returns client index */
	{
		public get()
		{
			int item; AsMap(this).GetValue("iBuilder", item);
			return GetClientOfUserId(item);
		}
		public set( const int val )
		{
			AsMap(this).SetValue("iBuilder", val);
		}
	}
	property int iMetal		/* if metal flag, how much metal it currently has in it */
	{
		public get()
		{
			int item; AsMap(this).GetValue("iMetal", item);
			return item;
		}
		public set( const int val )
		{
			AsMap(this).SetValue("iMetal", val);
		}
	}
	property int iMaxMetal
	{
		public get()
		{
			int item; AsMap(this).GetValue("iMaxMetal", item);
			return item;
		}
		public set( const int val )
		{
			AsMap(this).SetValue("iMaxMetal", val);
		}
	}
	property int iHealth
	{
		public get()
		{
			int ent = this.iEntity; //AsMap(this).GetValue("iHealth", item);
			return GetEntProp(ent, Prop_Data, "m_iHealth");
		}
		public set( const int val )
		{
			int ent = this.iEntity;
			SetEntProp(ent, Prop_Data, "m_iHealth", val);
		}
	}
	property int iMaxHealth
	{
		public get()
		{
			int item; AsMap(this).GetValue("iMaxHealth", item);
			return (item);
		}
		public set( const int val )
		{
			AsMap(this).SetValue("iMaxHealth", val);
		}
	}
	property int iMetalBuild	/* metal required to build this */
	{
		public get()
		{
			int item; AsMap(this).GetValue("iMetalBuild", item);
			return (item);
		}
		public set( const int val )
		{
			AsMap(this).SetValue("iMetalBuild", val);
		}
	}
	property int iUpgradeLvl
	{
		public get()
		{
			int item; AsMap(this).GetValue("iUpgradeLvl", item);
			return (item);
		}
		public set( const int val )
		{
			AsMap(this).SetValue("iUpgradeLvl", val);
		}
	}
	property int iGlowRef
	{
		public get()
		{
			int item; AsMap(this).GetValue("iGlowRef", item);
			return EntRefToEntIndex(item);
		}
		public set( const int val )
		{
			AsMap(this).SetValue("iGlowRef", EntIndexToEntRef(val));
		}
	}
	property float flBuildTime
	{
		public get()
		{
			float item; AsMap(this).GetValue("flBuildTime", item);
			return (item);
		}
		public set( const float val )
		{
			AsMap(this).SetValue("flBuildTime", val);
		}
	}
	property Handle hPlugin
	{
		public get()
		{
			Handle item; AsMap(this).GetValue("hPlugin", item);
			return (item);
		}
		public set( const Handle val )
		{
			AsMap(this).SetValue("hPlugin", val);
		}
	}
};

StringMap AsMap(Handle h)
{
	return view_as<StringMap>(h);
}


// SDKHooks-style Forwards
methodmap PrivForws < Handle
{
	public PrivForws( const Handle forw )
	{
		if (forw)
			return view_as<PrivForws>( forw );
		return null;
	}
	property int FuncCount {
		public get()	{ return GetForwardFunctionCount(this); }
	}
	public bool Add(Handle plugin, Function func)
	{
		return AddToForward(this, plugin, func);
	}
	public bool Remove(Handle plugin, Function func)
	{
		return RemoveFromForward(this, plugin, func);
	}
	public int RemoveAll(Handle plugin)
	{
		return RemoveAllFromForward(this, plugin);
	}
	public void Start()
	{
		Call_StartForward(this);
	}
};

ArrayList hArrayBuildings = null;	// List <Subplugin Index>
StringMap hTrieBuildings = null;	// Map <Boss Name, Subplugin Handle>

PrivForws pNBForws[OnMenuSelected+1];




methodmap CBaseStructure < Handle {
	public CBaseStructure() {
		return view_as<CBaseStructure>( new StringMap() );
	}
	
	property int iEntity {		/* automatically converts between entity indexes and references */
		public get() {
			int item; AsMap(this).GetValue("iEntity", item);
			return EntRefToEntIndex( item );
		}
		public set( const int val ) {
			AsMap(this).SetValue("iEntity", EntIndexToEntRef(val));
		}
	}
	property int iFlags {		/* structure flags */
		public get() {
			int item; AsMap(this).GetValue("iFlags", item);
			return item;
		}
		public set( const int val ) {
			AsMap(this).SetValue("iFlags", val);
		}
	}
	property int iType {
		public get() {
			int item; AsMap(this).GetValue("iType", item);
			return (item);
		}
		public set( const int val ) {
			AsMap(this).SetValue("iType", val);
		}
	}
	property int iBuilder {		/* set as userid, returns client index */
		public get() {
			int item; AsMap(this).GetValue("iBuilder", item);
			return GetClientOfUserId(item);
		}
		public set( const int val ) {
			AsMap(this).SetValue("iBuilder", val);
		}
	}
	property int iUpgradeMetal {		/* if metal flag, how much metal it currently has in it */
		public get() {
			int item; AsMap(this).GetValue("iUpgradeMetal", item);
			return item;
		}
		public set( const int val ) {
			AsMap(this).SetValue("iUpgradeMetal", val);
		}
	}
	property int iMaxUpgradeMetal {
		public get() {
			int item; AsMap(this).GetValue("iMaxUpgradeMetal", item);
			return item;
		}
		public set( const int val ) {
			AsMap(this).SetValue("iMaxUpgradeMetal", val);
		}
	}
	/*property int iCollisionGroup {
		public get() {
			return GetEntProp(this.iEntity, Prop_Send, "m_CollisionGroup");
		}
	}*/
	property int iHealth {
		public get() {
			return GetEntProp(this.iEntity, Prop_Data, "m_iHealth");
		}
		public set( const int val ) {
			SetEntProp(this.iEntity, Prop_Data, "m_iHealth", val);
		}
	}
	property int iGoalHealth {
		public get() {
			int item; AsMap(this).GetValue("iGoalHealth", item);
			return (item);
		}
		public set( const int val ) {
			AsMap(this).SetValue("iGoalHealth", val);
		}
	}
	property int iMaxHealth {
		public get() {
			int item; AsMap(this).GetValue("iMaxHealth", item);
			return (item);
		}
		public set( const int val ) {
			AsMap(this).SetValue("iMaxHealth", val);
		}
	}
	property int iMetalBuild {	/* metal required to build this */
		public get() {
			int item; AsMap(this).GetValue("iMetalBuild", item);
			return (item);
		}
		public set( const int val ) {
			AsMap(this).SetValue("iMetalBuild", val);
		}
	}
	property int iUpgradeLvl {
		public get() {
			int item; AsMap(this).GetValue("iUpgradeLvl", item);
			return (item);
		}
		public set( const int val ) {
			AsMap(this).SetValue("iUpgradeLvl", val);
		}
	}
	property int iGoalUpgradeLvl {
		public get() {
			int item; AsMap(this).GetValue("iGoalUpgradeLvl", item);
			return (item);
		}
		public set( const int val ) {
			AsMap(this).SetValue("iGoalUpgradeLvl", val);
		}
	}
	property int iMaxUpgradeLvl {
		public get() {
			int item; AsMap(this).GetValue("iMaxUpgradeLvl", item);
			return (item);
		}
		public set( const int val ) {
			AsMap(this).SetValue("iMaxUpgradeLvl", val);
		}
	}
	property int iGlowRef {
		public get() {
			int item; AsMap(this).GetValue("iGlowRef", item);
			return EntRefToEntIndex(item);
		}
		public set( const int val ) {
			AsMap(this).SetValue("iGlowRef", EntIndexToEntRef(val));
		}
	}
	/*property int iTeam {
		public get() {
			return GetEntProp( this.iEntity, Prop_Send, "m_iTeamNum" );
		}
		public set( const int val ) {
			SetEntProp( this.iEntity, Prop_Send, "m_iTeamNum", val );
		}
	}*/
	property float flBuildTime {
		public get() {
			float item; AsMap(this).GetValue("flBuildTime", item);
			return (item);
		}
		public set( const float val ) {
			AsMap(this).SetValue("flBuildTime", val);
		}
	}
	
	property float flBuildTimeLeft {
		public get() {
			float item; AsMap(this).GetValue("flBuildTimeLeft", item);
			return (item);
		}
		public set( const float val ) {
			AsMap(this).SetValue("flBuildTimeLeft", val);
		}
	}
	/*property Handle hPlugin {
		public get() {
			Handle item; AsMap(this).GetValue("hPlugin", item);
			return (item);
		}
		public set( const Handle val ) {
			AsMap(this).SetValue("hPlugin", val);
		}
	}
	public void MakeCarriedObject() {
		this.flBuildTimeLeft = this.flBuildTime/2.0;
		this.iFlags &= ~FLAG_BUILT;
		this.iFlags |= FLAG_CARRIED;
		this.iGoalHealth = this.iHealth;
		CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(this.iEntity) );
		this.iEntity = 0;
		this.iGoalUpgradeLvl = this.iUpgradeLvl;
	}*/
};

StringMap AsMap(Handle h)
{
	return view_as<StringMap>(h);
}


// SDKHooks-style Forwards
methodmap PrivForws < Handle
{
	public PrivForws( const Handle forw ) {
		if (forw)
			return view_as<PrivForws>( forw );
		return null;
	}
	property int FuncCount {
		public get()	{ return GetForwardFunctionCount(this); }
	}
	public bool Add(Handle plugin, Function func) {
		return AddToForward(this, plugin, func);
	}
	public bool Remove(Handle plugin, Function func) {
		return RemoveFromForward(this, plugin, func);
	}
	public int RemoveAll(Handle plugin) {
		return RemoveAllFromForward(this, plugin);
	}
	public void Start() {
		Call_StartForward(this);
	}
};

ArrayList hArrayBuildings = null;	// List <Subplugin Index>
StringMap hTrieBuildings = null;	// Map <Boss Name, Subplugin Handle>

PrivForws pNBForws[OnMenuSelected+1];

int giStructsBuilt[2];


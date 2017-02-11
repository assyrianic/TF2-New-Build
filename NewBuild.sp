#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <sdkhooks>
#include <morecolors>
#include <newbuild>

#pragma semicolon		1
#pragma newdecls		required

#define PLUGIN_VERSION		"1.1.2 Alpha"

public Plugin myinfo = {
	name 			= "New Structure Buildings",
	author 			= "Nergal / Assyrian / Ashurian",
	description 		= "customizable buildings for engineers to make",
	version 		= PLUGIN_VERSION,
	url 			= "hue"	// will fill later
};

enum {	// convar enum
	AllowRed,
	AllowBlu,
	Enabled
};

ConVar NewBuildCvars[Enabled+1];

ArrayList hConstructs[2];	// 2 is red and blue team

//char gszBuildingHudInfo[512];

#include "NBModules/base.sp"

public void OnPluginStart()
{
	hArrayBuildings = new ArrayList();
	hTrieBuildings = new StringMap();
	
	pNBForws[OnBuild]		=new PrivForws( CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell) );
	pNBForws[OnMenuSelected]	=new PrivForws( CreateForward(ET_Ignore, Param_Cell, Param_Cell) );
	pNBForws[OnThink]		=new PrivForws( CreateForward(ET_Ignore, Param_Cell, Param_Cell) );
	
	pNBForws[OnInteract]		=new PrivForws( CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef, Param_Cell) );
	pNBForws[OnInteractPost]	=new PrivForws( CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell) );
	
	pNBForws[OnConstructInteract]	=new PrivForws( CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_FloatByRef) );
	pNBForws[OnConstructInteractPost]=new PrivForws( CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float) );
	
	RegConsoleCmd("sm_structures",	CreateNewStructureMenu);
	RegConsoleCmd("sm_structure",	CreateNewStructureMenu);
	RegConsoleCmd("sm_bases",	CreateNewStructureMenu);
	RegConsoleCmd("sm_base",	CreateNewStructureMenu);
	RegConsoleCmd("sm_build",	CreateNewStructureMenu);
	RegConsoleCmd("sm_building",	CreateNewStructureMenu);
	
	RegConsoleCmd("sm_destroy",	DestroyStructureMenu);
	
	NewBuildCvars[Enabled] = CreateConVar("newbuildings_enabled", "1", "Enable the Custom Buildings/Structures plugin", FCVAR_NONE, true, 0.0, true, 1.0);

	NewBuildCvars[AllowBlu] = CreateConVar("newbuildings_blu", "1", "(Dis)Allow Custom Buildings for BLU team", FCVAR_NONE|FCVAR_NOTIFY, true, 0.0, true, 1.0);

	NewBuildCvars[AllowRed] = CreateConVar("newbuildings_red", "1", "(Dis)Allow Custom Buildings for RED team", FCVAR_NONE|FCVAR_NOTIFY, true, 0.0, true, 1.0);

	hConstructs[0] = new ArrayList();
	hConstructs[1] = new ArrayList();
	AutoExecConfig(true, "Custom-Buildings");
	

	//HookEvent("player_death", PlayerDeath);
	/*HookEvent("player_hurt", PlayerHurt, EventHookMode_Pre);
	//HookEvent("player_spawn", PlayerSpawn, EventHookMode_Pre);
	HookEvent("post_inventory_application", Resupply);
	//HookEvent("player_changeclass", ChangeClass, EventHookMode_Pre);
	HookEvent("player_builtobject", ObjectBuilt);
	HookEvent("player_upgradedobject", ObjectBuilt);
	HookEvent("teamplay_round_win", RoundEnd);
*/
	for (int i=MaxClients ; i ; --i) {
		if ( !IsValidClient(i) )
			continue;
		OnClientPutInServer(i);
	}
	CreateTimer(0.1, Timer_BuildingThink, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}
/*
// If player dies while carrying a custom building, custom building dies too.
public Action PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!NewBuildCvars[Enabled].BoolValue)
		return Plugin_Continue;

	int victim = GetClientOfUserId(event.GetInt("userid"));
	int team = GetClientTeam(victim);
	
	CBaseStructure destroy = null;
	int i;
	for (i=0 ; i<hConstructs[team-2].Length ; ++i) {
		destroy=hConstructs[team-2].Get(i);
		if (destroy==null)
			continue;
		else if (destroy.iBuilder != victim)
			continue;
		else if ( !(destroy.iFlags & FLAG_CARRIED) )
			continue;
		
		if ( IsValidEntity(destroy.iEntity) )
			CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(destroy.iEntity) );
		delete destroy;
		hConstructs[team-2].Erase(i);
	}
	
	return Plugin_Continue;
}
*/
public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PreThink, OnPreThink);
}

public void OnMapStart()
{
	//ManageDownloads();
	PrecacheSound("weapons/wrench_hit_build_success1.wav", true);
	PrecacheSound("weapons/wrench_hit_build_success2.wav", true);
	PrecacheSound("weapons/wrench_hit_build_fail.wav", true);
}

public Action DestroyStructureMenu(int client, int args)
{
	if (!NewBuildCvars[Enabled].BoolValue or client <= 0)
		return Plugin_Continue;
	else if ( !IsPlayerAlive(client) or IsClientObserver(client) or GetClientTeam(client) < 2 ) {
		ReplyToCommand(client, "[NewBuild] You need to be alive, on a team to destroy a building!");
		return Plugin_Handled;
	}
	
	int count = hArrayBuildings.Length;
	if (count <= 0) {
		ReplyToCommand(client, "[NewBuild] No Building Modules Loaded! You can't destroy what isn't loaded...");
		return Plugin_Handled;
	}
	int team = GetClientTeam(client);
	
	char name[64], num[10];
	Menu bases = new Menu( MenuHandler_KillStructure );
	bases.SetTitle("NewBuild Buildings to Destroy");
	bases.AddItem("0", "**** Destroy ALL Structures ****");
	
	CBaseStructure destroy = null;
	int i=0;
	for ( int j=0 ; j<hConstructs[team-2].Length ; ++j ) {
		destroy = hConstructs[team-2].Get(j);
		if ( destroy == null )
			continue;
		else if ( destroy.iBuilder != client )
			continue;
		else if ( !IsValidEntity(destroy.iEntity) )
			continue;
		
		StringMap subplugin = hArrayBuildings.Get(destroy.iType);
		subplugin.GetString("Name", name, sizeof(name));
		IntToString(i, num, 10);
		++i;
		bases.AddItem(num, name);
	}
	bases.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int MenuHandler_KillStructure(Menu menu, MenuAction action, int client, int select)
{
	if ( client <= 0 )
		return;
	
	// make sure they don't activate menu, then change to unwanted state!
	else if ( IsClientObserver(client) or !IsPlayerAlive(client) or GetClientTeam(client) < 2 )
		return;
	
	char info1[16]; menu.GetItem(select, info1, sizeof(info1));
	int option = StringToInt(info1);
	
	if (action == MenuAction_Select) {
		int team = GetClientTeam(client);
		if (select) {
			CBaseStructure destroy = hConstructs[team-2].Get(select);
			if (destroy == null)
				return;
			
			StringMap subplugin = hArrayBuildings.Get( destroy.iType );
			char pluginName[64];
			subplugin.GetString( "Name", pluginName, sizeof(pluginName) );
			
			if ( IsValidEntity(destroy.iEntity) )
				CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(destroy.iEntity) );
			delete destroy;
			hConstructs[team-2].Erase(select);
			ReplyToCommand(client, "[NewBuild] Destroying %s Structure!", pluginName);
			--giStructsBuilt[team-2];
		}
		else {	// delete every one that the player owns
			CBaseStructure destroy = null;
			for ( int i=0 ; i<hConstructs[team-2].Length ; ++i ) {
				destroy = hConstructs[team-2].Get(i);
				if ( destroy == null )
					continue;
				else if ( destroy.iBuilder != client )
					continue;
		
				if ( IsValidEntity(destroy.iEntity) )
					CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(destroy.iEntity) );
				delete destroy;
				hConstructs[team-2].Erase(i);
				--giStructsBuilt[team-2];
			}
			ReplyToCommand(client, "[NewBuild] Destroying All Structures!");
		}
	}
	if (action == MenuAction_End)
		delete menu;
}

public Action CreateNewStructureMenu(int client, int args)
{
	if (!NewBuildCvars[Enabled].BoolValue or client <= 0)
		return Plugin_Continue;
	else if ( !IsPlayerAlive(client) or IsClientObserver(client) or GetClientTeam(client) < 2 ) {
		ReplyToCommand(client, "[NewBuild] You need to be alive, on a team to build!");
		return Plugin_Handled;
	}
	else if ( (GetClientTeam(client) == 3 and !NewBuildCvars[AllowBlu].BoolValue)
		or (GetClientTeam(client) == 2 and !NewBuildCvars[AllowRed].BoolValue) )
	{
		ReplyToCommand(client, "[NewBuild] Your Team isn't allowed to build custom buildings!");
		return Plugin_Handled;
	}
	
	int count = hArrayBuildings.Length;
	if (count <= 0) {
		ReplyToCommand(client, "[NewBuild] No Building Modules Loaded! Please install a Building Module to use this command.");
		return Plugin_Handled;
	}
	
	char name[64], num[10];
	Menu bases = new Menu( MenuHandler_BuildStructure );
	bases.SetTitle("NewBuild Available Building to Create");
	for ( int i=0 ; i<count ; ++i ) {
		StringMap subplugin = hArrayBuildings.Get(i);
		subplugin.GetString("Name", name, sizeof(name));
		IntToString(i, num, 10);
		bases.AddItem(num, name);
	}
	bases.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int MenuHandler_BuildStructure(Menu menu, MenuAction action, int client, int select)
{
	if ( client <= 0 )
		return;
	// make sure they don't activate menu, then change to unwanted state!
	else if ( IsClientObserver(client) or !IsPlayerAlive(client) or GetClientTeam(client) < 2 )
		return;
	
	char info1[16]; menu.GetItem(select, info1, sizeof(info1));
	//int flags = StringToInt(info1);
	
	if (action == MenuAction_Select) {
		StringMap subplugin = hArrayBuildings.Get( select );
		char pluginName[64];
		subplugin.GetString( "Name", pluginName, sizeof(pluginName) );

		CBaseStructure build = new CBaseStructure();
		build.iType = select;
		//build.hPlugin = GetSubPlugin( subplugin );
		build.iBuilder = GetClientUserId(client);
		
		NB_OnMenuSelected(build);
		if ( NB_OnBuild(build) ) {
			int team = GetClientTeam(client);
			/*for (int i=0 ; i<hConstructs[team-2].Length ; ++i) {
				CBaseStructure map = hConstructs[team-2].Get(i);
				if (map==null)
					continue;
				
				// if the entity of a structure doesn't exist, then delete it so we can recycle its index for a new structure
				if (!IsValidEntity(map.iEntity)) {
					delete map;
					hConstructs[team-2].Erase(i);
				}
			}*/
			hConstructs[team-2].Push(build);
			//ReplyToCommand(client, "[NewBuild] Building %s Structure!", pluginName);
			
			Event pBuilt = CreateEvent("player_builtobject", true);
			if (pBuilt != null) {
				pBuilt.SetInt("userid", GetClientUserId(client));
				pBuilt.SetInt("object", build.iType+4);
				pBuilt.SetInt("index", build.iEntity);
				pBuilt.Fire();
			}
		}
		else CreateNewStructureMenu(client, -1);
	}
	if (action == MenuAction_End)
		delete menu;
}

public void NB_OnMenuSelected(const CBaseStructure base) // 2
{
	pNBForws[OnMenuSelected].Start();	// SET FLAG INFORMATION HERE
	Call_PushCell(base.iType);
	Call_PushCell(base);
	Call_Finish();
}
public bool NB_OnBuild(const CBaseStructure base) // 2
{
	if (base.iBuilder <= 0)
		return false;
	
	int client = base.iBuilder;
	int team = GetClientTeam(client);
	
	int iBuilding = CreateEntityByName("prop_dynamic_override");
	if ( iBuilding <= 0 or !IsValidEdict(iBuilding) )
		return false;
	
	int flags = base.iFlags;
	
	if ( (flags & FLAG_REQENG) and TF2_GetPlayerClass(client) != TFClass_Engineer) {
		CPrintToChat(client, "{red}[NewBuild] {white}You need to be an Engineer to build that!");
		CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(iBuilding) );
		return false;
	}
	
	if (flags & FLAG_METALREQ) {	// check if it requires metal
		if ( !(flags & FLAG_REQENG) )	// if it requires metal, it requires engie to build
			base.iFlags |= FLAG_REQENG;
		
		if (TF2_GetPlayerClass(client) != TFClass_Engineer) {
			CPrintToChat(client, "{red}[NewBuild] {white}You need to be an Engineer to build that!");
			CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(iBuilding) );
			return false;
		}
		else if ( GetEntProp(client, Prop_Data, "m_iAmmo", 4, 3) < base.iMetalBuild ) {
			CPrintToChat(client, "{red}[NewBuild] {white}You need %i Metal to build that!", base.iMetalBuild);
			CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(iBuilding) );
			return false;
		}
	}
	if (flags & FLAG_REQGUNSLINGER) {
		int melee = GetPlayerWeaponSlot(client, 2);
		if (melee > MaxClients and GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex") != 142) {
			CPrintToChat(client, "{red}[NewBuild] {white}This building requires you to have the Gunslinger.");
			CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(iBuilding) );
			return false;
		}
	}
	if (flags & FLAG_METALREQFIX) {
		if ( !(flags & FLAG_FIXENG) )	// if it requires metal to fix, it requires engie to fix then
			base.iFlags |= FLAG_FIXENG;
	}
	if (flags & FLAG_METALREQUPGRADE) {
		if ( !(flags & FLAG_UPGRADEENG) )	// if it requires metal to upgrade, it requires engie to upgrade then
			base.iFlags |= FLAG_UPGRADEENG;
	}
	if (flags & FLAG_HITSPEEDENG) {
		if ( !(flags & FLAG_HITSPEEDSBUILD) )	// if set that engie's can speed up construction, set the flag
			base.iFlags |= FLAG_HITSPEEDSBUILD;
	}
	if (flags & FLAG_TEAM) {		// check if teammates have already built one of this
		CBaseStructure construct = null;
		for (int i=0 ; i<hConstructs[team-2].Length ; ++i) {
			construct = hConstructs[team-2].Get(i);
			if (construct == null)
				continue;
			else if (construct.iType != base.iType)		// if not the same thing, then skip
				continue;
			else if ( !(construct.iFlags & FLAG_TEAM) )
				continue;
			else if (!IsValidEntity(construct.iEntity))
				continue;
			
			CPrintToChat(client, "{red}[NewBuild] {white}This building is Team limited and your Team already has one built.");
			CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(iBuilding) );
			return false;
		}
	}
	if (flags & FLAG_PLAYER) {	// check if player has already built one of these
		CBaseStructure construct = null;
		for (int i=0 ; i<hConstructs[team-2].Length ; ++i) {
			construct = hConstructs[team-2].Get(i);
			if (construct == null)
				continue;
			else if (construct.iType != base.iType)
				continue;

			if (IsValidEntity(construct.iEntity) and construct.iBuilder == client) {
				CPrintToChat(client, "{red}[NewBuild] {white}You have already built that stupid!");
				CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(iBuilding) );
				return false;
			}
		}
	}
	SetEntProp( iBuilding, Prop_Send, "m_iTeamNum", team );
	
	pNBForws[OnBuild].Start();
	Call_PushCell(base.iType);
	Call_PushCell(base);
	Call_PushCell(EntIndexToEntRef(iBuilding));	// set the model, health, other props, and targetname during this phase
	Call_Finish();
	
	base.iFlags |= ( (team==2) ? FLAG_REDBUILT : FLAG_BLUBUILT );
	
	float mins[3], maxs[3];
	mins = Vec_GetEntPropVector(iBuilding, Prop_Send, "m_vecMins");
	maxs = Vec_GetEntPropVector(iBuilding, Prop_Send, "m_vecMaxs");

	float flEndPos[3];
	if (IsPlacementPosValid(client, mins, maxs, flEndPos)) {
		if (TR_PointOutsideWorld(flEndPos)) {
			CPrintToChat(client, "{red}[NewBuild] {white}You can't build outside the Playable Area!");
			return false;
		}
		DispatchSpawn(iBuilding);
		SetEntProp( iBuilding, Prop_Send, "m_nSolidType", 6 );
		float flAng[3]; GetClientAbsAngles(client, flAng);	// set the building straight up
		TeleportEntity(iBuilding, flEndPos, flAng, NULL_VECTOR);

		int beamcolor[4] = {0, 255, 90, 255};
		float vecMins[3], vecMaxs[3];

		vecMins = Vec_AddVectors(flEndPos, mins); //AddVectors(flEndPos, mins, vecMins);
		vecMaxs = Vec_AddVectors(flEndPos, maxs); //AddVectors(flEndPos, maxs, vecMaxs);

		int laser = PrecacheModel("sprites/laser.vmt", true);
		TE_SendBeamBoxToAll( vecMaxs, vecMins, laser, laser, 1, 1, 5.0, 8.0, 8.0, 5, 2.0, beamcolor, 0 );
		if (flags & FLAG_KILLABLE) {
			SetEntProp(iBuilding, Prop_Data, "m_takedamage", 2, 1);
			SDKHook(iBuilding, SDKHook_OnTakeDamage, OnBuildingTakeDamage);
			SetEntProp(iBuilding, Prop_Data, "m_iHealth", 1);	// set the health to 1 while it builds
		}
		if (flags & FLAG_TEAMUNCOLLIDEABLE) {
			SDKHook(iBuilding, SDKHook_ShouldCollide, OnBuildingCollide);
		}
		
		if (flags & FLAG_GLOW) {
			int iGlow = CreateEntityByName("tf_taunt_prop");
			if (iGlow != -1) {
				base.iGlowRef = iGlow;
				char modelname[PLATFORM_MAX_PATH];
				GetEntPropString(iBuilding, Prop_Data, "m_ModelName", modelname, PLATFORM_MAX_PATH);
				SetEntityModel(iGlow, modelname);
				SetEntProp( iGlow, Prop_Send, "m_iTeamNum", team );

				DispatchSpawn(iGlow);
				ActivateEntity(iGlow);
				SetEntityRenderMode(iGlow, RENDER_TRANSCOLOR);
				SetEntityRenderColor(iGlow, 0, 0, 0, 0);
				SetEntProp(iGlow, Prop_Send, "m_bGlowEnabled", 1);
				float flModelScale = GetEntPropFloat(iBuilding, Prop_Send, "m_flModelScale");
				SetEntPropFloat(iGlow, Prop_Send, "m_flModelScale", flModelScale);

				int iFlags = GetEntProp(iGlow, Prop_Send, "m_fEffects");
				SetEntProp(iGlow, Prop_Send, "m_fEffects", iFlags|(1 << 0));

				SetVariantString("!activator");
				AcceptEntityInput(iGlow, "SetParent", iBuilding);

				SDKHook(iGlow, SDKHook_SetTransmit, OnEffectTransmit);
			}
		}
		if (flags & FLAG_TEAM) {	// if team-limited, message to teammates that the object is built.
			StringMap subplugin = hArrayBuildings.Get(base.iType);
			char pluginName[64];
			subplugin.GetString( "Name", pluginName, sizeof(pluginName) );
			for (int i=MaxClients ; i ; --i) {
				if (!IsValidClient(i))
					continue;
				else if (GetClientTeam(i) != team)
					continue;
				
				CPrintToChat(i, "{red}[NewBuild] {white}%s Built, Will activate in %f Seconds.", pluginName, base.flBuildTime);
			}
		}
	}
	else {
		CPrintToChat(client, "{red}[NewBuild] {white}You can't build the structure there.");
		CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(iBuilding) );
		return false;
	}
	base.iEntity = iBuilding;
	base.iUpgradeLvl = 1;
	base.flBuildTimeLeft = 1.0;
	if ( flags & FLAG_METALREQ ) {
		int iCurrentMetal = GetEntProp(client, Prop_Data, "m_iAmmo", 4, 3);
		iCurrentMetal -= base.iMetalBuild;
		SetEntProp(client, Prop_Data, "m_iAmmo", iCurrentMetal, 4, 3);
	}
	++giStructsBuilt[team-2];
	return true;
}

public Action OnBuildingTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!IsClientValid(attacker) or victim < MaxClients)
		return Plugin_Continue;
	
	int team = GetClientTeam(attacker);
	if ( team == GetEntProp(victim, Prop_Data, "m_iTeamNum") and IsClientValid(attacker) ) {
		//char tName[64]; GetEntPropString(victim, Prop_Data, "m_iName", tName, sizeof(tName));
		damage = 0.0;
		int teamindex, vecindex;
		vecindex = FindBaseByEntIndex(victim, teamindex);
		if (vecindex == -1) {
			CPrintToChat(attacker, "{red}[NewBuild] {white}OnBuildingTakeDamage::Invalid Structure.");
			return Plugin_Continue;
		}
		//char classname[32];
		//if ( IsValidEdict(weapon) )
		//	GetEdictClassname(weapon, classname, sizeof(classname));

		if ( weapon == GetPlayerWeaponSlot(attacker, 2) ) {
			CBaseStructure building = hConstructs[team-2].Get(vecindex);
			int flags = building.iFlags;
			if (flags & FLAG_BUILT) {
				if (building.iHealth < building.iMaxHealth) {	// do repairs first
					int repairamount = 25;
					int mult = 4;	// TODO: ADD CVAR FOR FIX MULTIPLIER
					
					if ( (flags & FLAG_FIXENG) and TF2_GetPlayerClass(attacker) != TFClass_Engineer)
						repairamount = 0 ;	// if flag requires engie, deny fixing if not engie!
					
					pNBForws[OnInteract].Start();
					Call_PushCell(building.iType);
					Call_PushCell(building);
					Call_PushCell(GetClientUserId(attacker));
					Call_PushCellRef(repairamount);
					Call_PushCell(true);
					Call_Finish();
					
					if (flags & FLAG_METALREQFIX) {
						int iCurrentMetal = GetEntProp(attacker, Prop_Data, "m_iAmmo", 4, 3);
						
						if (iCurrentMetal < repairamount)
							repairamount = iCurrentMetal;

						if ( building.iMaxHealth-building.iHealth < repairamount*mult )
							repairamount = RoundToCeil( float(building.iMaxHealth - building.iHealth)/float(mult) );

						iCurrentMetal -= repairamount;
						SetEntProp(attacker, Prop_Data, "m_iAmmo", iCurrentMetal, 4, 3);
					}
					
					building.iHealth += repairamount*mult;
					
					if (building.iHealth > building.iMaxHealth)
						building.iHealth = building.iMaxHealth;
					
					if (repairamount)
						EmitSoundToClient(attacker, ( !GetRandomInt(0,1) ) ? "weapons/wrench_hit_build_success1.wav" : "weapons/wrench_hit_build_success2.wav" );
					else EmitSoundToClient(attacker, "weapons/wrench_hit_build_fail.wav");
					
					pNBForws[OnInteractPost].Start();
					Call_PushCell(building.iType);
					Call_PushCell(building);
					Call_PushCell(GetClientUserId(attacker));
					Call_PushCell(repairamount);
					Call_PushCell(true);
					Call_Finish();
				}
				// Can't upgrade if damaged.
				else if ( (flags & FLAG_UPGRADEABLE) and building.iUpgradeLvl < building.iMaxUpgradeLvl ) {
					int upgradeamount = 25;
					
					if ( (flags & FLAG_UPGRADEENG) and TF2_GetPlayerClass(attacker) != TFClass_Engineer )
						upgradeamount = 0 ;	// flag requires engie, deny upgrading if not engie.
					
					pNBForws[OnInteract].Start();
					Call_PushCell(building.iType);
					Call_PushCell(building);
					Call_PushCell(GetClientUserId(attacker));
					Call_PushCellRef(upgradeamount);
					Call_PushCell(false);
					Call_Finish();
					
					if (flags & FLAG_METALREQUPGRADE) {
						int iCurrentMetal = GetEntProp(attacker, Prop_Data, "m_iAmmo", 4, 3);
						
						if (iCurrentMetal < upgradeamount)
							upgradeamount = iCurrentMetal;
					
						iCurrentMetal -= upgradeamount;
						SetEntProp(attacker, Prop_Data, "m_iAmmo", iCurrentMetal, 4, 3);
					}
					
					building.iUpgradeMetal += upgradeamount;
					if (upgradeamount)
						EmitSoundToClient(attacker, ( !GetRandomInt(0,1) ) ? "weapons/wrench_hit_build_success1.wav" : "weapons/wrench_hit_build_success2.wav" );
					else EmitSoundToClient(attacker, "weapons/wrench_hit_build_fail.wav");
					
					pNBForws[OnInteractPost].Start();
					Call_PushCell(building.iType);
					Call_PushCell(building);
					Call_PushCell(GetClientUserId(attacker));
					Call_PushCell(upgradeamount);
					Call_PushCell(false);
					Call_Finish();
					
					if (building.iUpgradeMetal >= building.iMaxUpgradeMetal) {
						Event pUpgraded = CreateEvent("player_upgradedobject", true);
						if (pUpgraded != null) {
							pUpgraded.SetInt("userid", GetClientUserId(building.iBuilder));
							pUpgraded.SetInt("object", building.iType+4);
							pUpgraded.SetInt("index", building.iEntity);
							pUpgraded.SetBool("isbuilder", attacker==building.iBuilder);
							pUpgraded.Fire();
						}
					}
				}
			}
			else if (flags & FLAG_HITSPEEDSBUILD) {
				float buildincrease = 2.0;
				if ((flags & FLAG_HITSPEEDENG) and TF2_GetPlayerClass(attacker) != TFClass_Engineer)
					buildincrease=0.0 ;
				
				pNBForws[OnConstructInteract].Start();
				Call_PushCell(building.iType);
				Call_PushCell(building);
				Call_PushCell(GetClientUserId(attacker));
				Call_PushFloatRef(buildincrease);
				Call_Finish();
				
				building.flBuildTimeLeft += buildincrease;
				if (buildincrease > 0.0)
					EmitSoundToClient(attacker, ( !GetRandomInt(0,1) ) ? "weapons/wrench_hit_build_success1.wav" : "weapons/wrench_hit_build_success2.wav" );
				else EmitSoundToClient(attacker, "weapons/wrench_hit_build_fail.wav");
				
				pNBForws[OnConstructInteractPost].Start();
				Call_PushCell(building.iType);
				Call_PushCell(building);
				Call_PushCell(GetClientUserId(attacker));
				Call_PushFloat(buildincrease);
				Call_Finish();
			}
		}
		return Plugin_Changed;
	}
	else {
		
	}
	return Plugin_Continue;
}
public Action OnEffectTransmit(int entity, int client)
{
	if (!IsClientValid(client))
		return Plugin_Continue;

	int team = GetEntProp(entity, Prop_Data, "m_iTeamNum");
	if (GetClientTeam(client) != team)
		return Plugin_Handled;

	return Plugin_Continue;
}

#define CONTENTS_REDTEAM			0x800
#define CONTENTS_BLUTEAM			0x1000
#define COLLISION_GROUP_PLAYER_MOVEMENT		8	// found in TF2Classic/src/public/const.h
#define TFCOLLISION_GROUP_OBJECT_SOLIDTOPLAYERMOVEMENT	22	// found in TF2Classic/src/game/shared/tf/tf_shareddefs.h
#define LAST_SHARED_COLLISION_GROUP		20

public bool OnBuildingCollide(int entity, int collisiongroup, int contentsmask, bool originalResult)
{
	if ( entity and IsValidEntity(entity) ) {
		int ent_team = GetEntProp( entity, Prop_Send, "m_iTeamNum" );
		//char tName[64]; GetEntPropString(entity, Prop_Data, "m_iName", tName, sizeof(tName));
		
		if ( collisiongroup == COLLISION_GROUP_PLAYER_MOVEMENT ) {
			switch ( ent_team ) {	// Do collisions by team
				case 2: if ( !(contentsmask & CONTENTS_REDTEAM) ) return false;
				case 3: if ( !(contentsmask & CONTENTS_BLUTEAM) ) return false;
			}
		}
	}
	return true;
}

public void OnPreThink(int client)
{
	if ( IsClientObserver(client) or !IsPlayerAlive(client) )
		return;
	
	int entity = GetClientAimTarget(client, false);
	if (entity > MaxClients) {
		int teamindex, vecindex;
		vecindex = FindBaseByEntIndex(entity, teamindex);
		if (vecindex == -1)
			return ;
		
		CBaseStructure building = hConstructs[teamindex].Get(vecindex);
		SetHudTextParams(0.93, -1.0, 0.1, 0, 255, 0, 255);
		
		int flags = building.iFlags;
		char info[256];
		if (flags & FLAG_KILLABLE)
			Format(info, sizeof(info), "%sBuilding Health: %i/%i\n", info, building.iHealth, building.iMaxHealth);
		
		if (flags & FLAG_BUILT) {
			if (flags & FLAG_UPGRADEABLE) {
				if (building.iUpgradeLvl < building.iMaxUpgradeLvl)
					Format(info, sizeof(info), "%sBuilding Level: %i\nBuilding Metal: %i/%i", info, building.iUpgradeLvl, building.iUpgradeMetal, building.iMaxUpgradeMetal);
				else Format(info, sizeof(info), "%sBuilding Level: %i\n", info, building.iUpgradeLvl);
			}
		}
		else Format(info, sizeof(info), "%sBuilding Time: %i\n", info, RoundFloat(building.flBuildTime-building.flBuildTimeLeft));
		ShowHudText(client, -1, info);
	}
}

public void NB_OnThink(const CBaseStructure base) // 2
{
	pNBForws[OnThink].Start();
	Call_PushCell(base.iType);
	Call_PushCell(base);
	Call_Finish();
}
public Action Timer_BuildingThink(Handle timer)
{
	if ( !NewBuildCvars[Enabled].BoolValue )
		return Plugin_Continue;
	
	CBaseStructure building = null;
	for (int team=0 ; team<2 ; ++team) {
		if (hConstructs[team] == null)
			continue;
		
		for (int i=0 ; i<hConstructs[team].Length ; ++i) {
			building = hConstructs[team].Get(i);
			if (building == null)
				continue;
			
			int flags = building.iFlags;
			// if the entity of a structure doesn't exist, then delete it so we can recycle its index for a new structure
			if ( !IsValidEntity(building.iEntity) ) {
				delete building;
				hConstructs[team].Erase(i);
				--giStructsBuilt[team];
				continue;
			}
			if ( (flags & FLAG_KILLDISC) and building.iBuilder <= 0 ) {
				CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(building.iEntity) );
				delete building;
				hConstructs[team].Erase(i);
				--giStructsBuilt[team];
				continue;
			}
			if ( (flags & FLAG_KILLTEAMSWITCH) and GetClientTeam(building.iBuilder) != GetEntProp( building.iEntity, Prop_Send, "m_iTeamNum" ) )
			{
				CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(building.iEntity) );
				delete building;
				hConstructs[team].Erase(i);
				--giStructsBuilt[team];
				continue;
			}
			if ( (flags & FLAG_KILLDEATH) and !IsPlayerAlive(building.iBuilder) ) {
				CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(building.iEntity) );
				delete building;
				hConstructs[team].Erase(i);
				--giStructsBuilt[team];
				continue;
			}
			
			if ( !(flags & FLAG_BUILT) ) {	// handle building time
				building.flBuildTimeLeft += 0.1;
				if (building.flBuildTimeLeft >= building.flBuildTime) {
					building.flBuildTimeLeft = building.flBuildTime;
					building.iFlags |= FLAG_BUILT;
				}
				// like engie's buildings, we want the custom buildings to gradually increase in health until built.
				building.iHealth = RoundFloat(building.iMaxHealth*(building.flBuildTimeLeft/building.flBuildTime));
			}
			else {		// is finally built, let's think
				if ( (flags & FLAG_UPGRADEABLE) and building.iUpgradeMetal >= building.iMaxUpgradeMetal ) {
					building.iUpgradeLvl++;
					building.iUpgradeMetal = 0;
				}
				NB_OnThink(building);
			}
			/*if (building.iBuilder) {
				gszBuildingHudInfo[0] = 0;
				SetHudTextParams( 0.93+i/100.0, -1.0, 0.1, 0, 255, 0, 255 );
				if (flags & FLAG_KILLABLE)
					Format(gszBuildingHudInfo, sizeof(gszBuildingHudInfo), "%sBuilding Health: %i/%i\n", gszBuildingHudInfo, building.iHealth, building.iMaxHealth);
				
				if (flags & FLAG_BUILT) {
					if (flags & FLAG_UPGRADEABLE) {
						if (building.iUpgradeLvl < building.iMaxUpgradeLvl)
							Format(gszBuildingHudInfo, sizeof(gszBuildingHudInfo), "%sBuilding Level: %i\nBuilding Metal: %i/%i", gszBuildingHudInfo, building.iUpgradeLvl, building.iUpgradeMetal, building.iMaxUpgradeMetal);
						else Format(gszBuildingHudInfo, sizeof(gszBuildingHudInfo), "%sBuilding Level: %i\n", gszBuildingHudInfo, building.iUpgradeLvl);
					}
				}
				else Format(gszBuildingHudInfo, sizeof(gszBuildingHudInfo), "%sBuilding Time: %i\n", gszBuildingHudInfo, RoundFloat(building.flBuildTime-building.flBuildTimeLeft));
				ShowHudText(building.iBuilder, -1, gszBuildingHudInfo);
			}*/
		}
		if ( giStructsBuilt[team]<0 )
			giStructsBuilt[team] = 0;
	}
	return Plugin_Continue;
}
/*
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (!NewBuildCvars[Enabled].BoolValue)
		return Plugin_Continue;
	else if (!IsPlayerAlive(client) or IsClientObserver(client) or GetClientTeam(client) < 2)
		return Plugin_Continue;
	
	if ( (buttons & IN_ATTACK2) ) {
		if (TryToPickupBuilding(client)) {}
		else TryReDeploy(client);
	}
	
	return Plugin_Continue;
}
stock bool TryToPickupBuilding(const int client)
{
	if ( client <= 0 )
		return false;
	
	float vecForward[3];
	float angEyes[3];
	GetClientEyeAngles(client, angEyes);
	GetAngleVectors(angEyes, vecForward, NULL_VECTOR, NULL_VECTOR);
	
	float vecSwingStart[3];
	GetClientAbsOrigin(client, vecSwingStart);
	
	float flRange = 150.0;	// 5500.0 if using Rescue Ranger!
	// Vector vecSwingEnd = vecSwingStart + vecForward * flRange;
	float vecSwingEnd[3];
	{
		ScaleVector(vecForward, flRange);
		AddVectors(vecSwingStart, vecForward, vecSwingEnd);
	}
	//int entity = GetClientAimTarget(client, false);
	TR_TraceRayFilter(vecSwingStart, vecSwingEnd, MASK_SOLID, RayType_EndPoint, TraceRayDontHitPlayers);
	if (TR_GetFraction() < 1.0 and TR_GetEntityIndex() > MaxClients ) {
		int entity = TR_GetEntityIndex();
		int entteam = GetEntProp(entity, Prop_Data, "m_iTeamNum");
		if ( entteam != GetClientTeam(client) )
			return false;
		
		int index = FindBaseByEntTeamIndex(entity, entteam);
		CBaseStructure building = hConstructs[entteam-2].Get(index);
		if ( CanPickupBuilding(client, building) ) {
			building.MakeCarriedObject();
			return true;
		}
	}
				  
	return false;
}
public bool TraceRayDontHitPlayers(int entity, int mask, any data)
{
	return (entity > MaxClients);
}
bool CanPickupBuilding( const int client, CBaseStructure pBuilding )
{
	if ( pBuilding == null )
		return false;
	
	if ( client <= 0 )
		return false;

	// if we can't pick object up or another object is already picked up then return false.
	if ( !(pBuilding.iFlags & FLAG_MOVEABLE) or (pBuilding.iFlags & FLAG_CARRIED) )
		return false;

	if ( GameRules_GetRoundState() > RoundState_RoundRunning )
		return false;

	if ( pBuilding.iBuilder != client )
		return false;

	if ( !(pBuilding.iFlags & FLAG_BUILT) )
		return false;

	return true;
}
stock void TryReDeploy(const int client)
{
	if ( client <= 0 )
		return ;
	else if ( !IsPlayerAlive(client) or IsClientObserver(client) or GetClientTeam(client) < 2 )
		return ;
	
	int team = GetClientTeam(client);
	if ( hConstructs[team-2] == null )
		return ;
	
	CBaseStructure rebuild = null;
	for (int i=0 ; i<hConstructs[team-2].Length ; ++i) {
		rebuild=hConstructs[team-2].Get(i);
		if (rebuild==null)
			continue;
		else if (rebuild.iBuilder != client)
			continue;
		else if ( !(rebuild.iFlags & FLAG_CARRIED) )
			continue;
		
		NB_OnBuild(rebuild);
		break;
	}
}*/
stock int FindBaseByEntIndex(const int entity, int& teamind=0)	// O(n) time
{
	for (int i=0 ; i<2 ; ++i) {
		if (hConstructs[i] == null)
			continue;
		
		for (int k=0 ; k<hConstructs[i].Length ; ++k) {
			CBaseStructure building = hConstructs[i].Get(k);
			if (building==null)
				continue;
			if (building.iEntity == entity) {
				teamind = i;
				return k;
			}
		}
	}
	teamind = -1;
	return -1;
}
stock int FindBaseByEntTeamIndex(const int entity, const int team)	// O(n) time
{
	if (hConstructs[team-2] == null)
		return -1;
	
	for (int k=0 ; k<hConstructs[team-2].Length ; ++k) {
		CBaseStructure building = hConstructs[team-2].Get(k);
		if (building==null)
			continue;
		if (building.iEntity == entity)
			return k;
	}
	return -1;
}
stock CBaseStructure FindBaseByEnt(const int entity)	// O(n) time
{
	for (int i=0 ; i<2 ; ++i) {
		if (hConstructs[i] == null)
			continue;
		
		for (int k=0 ; k<hConstructs[i].Length ; ++k) {
			CBaseStructure building = hConstructs[i].Get(k);
			if (building==null)
				continue;
			if (building.iEntity == entity)
				return building;
		}
	}
	return null;
}
stock CBaseStructure FindBaseByEntTeam(const int entity, const int team)	// O(n) time
{
	if (hConstructs[team-2] == null)
		return null;
		
	for (int k=0 ; k<hConstructs[team-2].Length ; ++k) {
		CBaseStructure building = hConstructs[team-2].Get(k);
		if (building==null)
			continue;
		if (building.iEntity == entity)
			return building;
	}
	return null;
}
stock Handle FindPlugin(const char[] name)
{
	Handle h;
	if (GetTrieValueCaseInsensitive(hTrieBuildings, name, h))
		return h;
	return null;
}
public int RegisterPlugin(Handle pluginhndl, const char longname[64])
{
	if ( !ValidateName(longname) ) {
		LogError("**** RegisterPlugin - Invalid Name For Building Structure ****");
		return -1;
	}
	else if (FindPlugin(longname) != null)
	{
		LogError("**** RegisterPlugin - Building Structure Already Exists ****");
		return -1;
	}
	// Create the trie to hold the data about the plugin
	StringMap BuildingMap = new StringMap();
	BuildingMap.SetValue("Subplugin", pluginhndl);
	BuildingMap.SetString("Name", longname);

	// Then push it to the global array and trie
	// Don't forget to convert the string to lower cases!
	hArrayBuildings.Push(BuildingMap);
	SetTrieValueCaseInsensitive(hTrieBuildings, longname, BuildingMap);

	return hArrayBuildings.Length-1;
}
stock PrivForws GetNBHookType(const int hook)
{
	int safety = hook;
	if (safety < 0)		// make sure it doesn't go out of bounds
		safety = 0;
	if (safety > OnMenuSelected)
		safety = OnMenuSelected;
	
	return (pNBForws[safety] != null) ? pNBForws[safety] : null;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// N A T I V E S ============================================================================================================
	CreateNative("NewBuild_Register", Native_RegisterSubplugin);
	CreateNative("NewBuild_Hook", Native_Hook);
	CreateNative("NewBuild_HookEx", Native_HookEx);
	CreateNative("NewBuild_Unhook", Native_Unhook);
	CreateNative("NewBuild_UnhookEx", Native_UnhookEx);
	
	CreateNative("NewBuild_BuiltOnRed", Native_RedBuilt);
	CreateNative("NewBuild_BuiltOnBlu", Native_BluBuilt);
	
	CreateNative("CStructure.CStructure", Native_StructureInstance);

	CreateNative("CStructure.GetProperty", Native_GetProp);
	CreateNative("CStructure.SetProperty", Native_SetProp);
	//===========================================================================================================================

	RegPluginLibrary("newbuild");
	MarkNativeAsOptional("NewBuild_Register");
	MarkNativeAsOptional("NewBuild_Hook");
	MarkNativeAsOptional("NewBuild_HookEx");
	MarkNativeAsOptional("NewBuild_Unhook");
	MarkNativeAsOptional("NewBuild_UnhookEx");
	
	MarkNativeAsOptional("NewBuild_BuiltOnRed");
	MarkNativeAsOptional("NewBuild_BuiltOnBlu");

	MarkNativeAsOptional("CStructure.CStructure");
	MarkNativeAsOptional("CStructure.GetProperty");
	MarkNativeAsOptional("CStructure.SetProperty");
	return APLRes_Success;
}
public int Native_RegisterSubplugin(Handle plugin, int numParams)
{
	char ModuleName[64]; GetNativeString(1, ModuleName, sizeof(ModuleName));
	return RegisterPlugin(plugin, ModuleName);	// ALL PROPS TO COOKIES.NET AKA COOKIES.IO
}
public int Native_Hook(Handle plugin, int numParams)
{
	int hook = GetNativeCell(1);
	PrivForws FwdHandle = GetNBHookType(hook);

	Function Func = GetNativeFunction(2);
	if (FwdHandle != null)
		FwdHandle.Add(plugin, Func);
	return 0;
}

public int Native_HookEx(Handle plugin, int numParams)
{
	int hook = GetNativeCell(1);
	PrivForws FwdHandle = GetNBHookType(hook);
	
	Function Func = GetNativeFunction(2);
	if (FwdHandle != null)
		return FwdHandle.Add(plugin, Func);
	return 0;
}

public int Native_Unhook(Handle plugin, int numParams)
{
	int hook = GetNativeCell(1);
	PrivForws FwdHandle = GetNBHookType(hook);

	if (FwdHandle != null)
		FwdHandle.Remove(plugin, GetNativeFunction(2));
	return 0;
}
public int Native_UnhookEx(Handle plugin, int numParams)
{
	int hook = GetNativeCell(1);
	PrivForws FwdHandle = GetNBHookType(hook);

	if (FwdHandle != null)
		return FwdHandle.Remove(plugin, GetNativeFunction(2));
	return 0;
}

public int Native_StructureInstance(Handle plugin, int numParams)
{
	return view_as< int >(new CBaseStructure());
}
public int Native_GetProp(Handle plugin, int numParams)
{
	CBaseStructure buildingmap = GetNativeCell(1);
	char prop_name[64]; GetNativeString(2, prop_name, 64);
	any item;
	if (AsMap(buildingmap).GetValue(prop_name, item))
		return view_as< int >(item);
	return 0;
}
public int Native_SetProp(Handle plugin, int numParams)
{
	CBaseStructure buildingmap = GetNativeCell(1);
	char prop_name[64]; GetNativeString(2, prop_name, 64);
	any item = GetNativeCell(3);
	AsMap(buildingmap).SetValue(prop_name, item);
	return 0;
}

public int Native_RedBuilt(Handle plugin, int numParams)
{
	return giStructsBuilt[0];
}
public int Native_BluBuilt(Handle plugin, int numParams)
{
	return giStructsBuilt[1];
}

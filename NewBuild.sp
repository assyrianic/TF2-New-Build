#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <sdkhooks>
#include <morecolors>
#include <newbuild>

#pragma semicolon		1
#pragma newdecls		required

#define PLUGIN_VERSION		"1.0.0 Alpha"

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

#include "NBModules/base.sp"
//#include "NBModules/events.sp"

public void OnPluginStart()
{
	hArrayBuildings = new ArrayList();
	hTrieBuildings = new StringMap();
	
	pNBForws[OnBuild]		=new PrivForws( CreateForward(ET_Ignore, Param_Cell, Param_Cell) );
	pNBForws[OnEngieInteract]	=new PrivForws( CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell) );
	pNBForws[OnMenuSelected]	=new PrivForws( CreateForward(ET_Ignore, Param_Cell, Param_Cell) );
	pNBForws[OnThink]		=new PrivForws( CreateForward(ET_Ignore, Param_Cell, Param_Cell) );
	
	RegConsoleCmd("sm_structures",	CreateNewStructureMenu);
	RegConsoleCmd("sm_structure",	CreateNewStructureMenu);
	RegConsoleCmd("sm_bases",	CreateNewStructureMenu);
	RegConsoleCmd("sm_base",	CreateNewStructureMenu);
	RegConsoleCmd("sm_build",	CreateNewStructureMenu);
	RegConsoleCmd("sm_building",	CreateNewStructureMenu);
	
	NewBuildCvars[Enabled] = CreateConVar("newbuildings_enabled", "1", "Enable the Custom Buildings/Structures plugin", FCVAR_NONE, true, 0.0, true, 1.0);

	NewBuildCvars[AllowBlu] = CreateConVar("newbuildings_blu", "1", "(Dis)Allow Custom Buildings for BLU team", FCVAR_NONE|FCVAR_NOTIFY, true, 0.0, true, 1.0);

	NewBuildCvars[AllowRed] = CreateConVar("newbuildings_red", "1", "(Dis)Allow Custom Buildings for RED team", FCVAR_NONE|FCVAR_NOTIFY, true, 0.0, true, 1.0);

	hConstructs[0] = new ArrayList();
	hConstructs[1] = new ArrayList();
	AutoExecConfig(true, "Custom-Buildings");
	
/*
	HookEvent("player_death", PlayerDeath, EventHookMode_Pre);
	HookEvent("player_hurt", PlayerHurt, EventHookMode_Pre);
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
}

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
	CreateTimer(0.1, Timer_BuildingThink, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action CreateNewStructureMenu(int client, int args)
{
	if (!NewBuildCvars[Enabled].BoolValue)
		return Plugin_Continue;
	else if ( client <= 0 )
		return Plugin_Handled;
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
	
	for (int i=0 ; i<count ; ++i) {
		StringMap map = hArrayBuildings.Get(i);
		map.GetString("Name", name, sizeof(name));
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
		StringMap smMap = hArrayBuildings.Get(select);
		char pluginName[64];
		smMap.GetString( "Name", pluginName, sizeof(pluginName) );

		CBaseStructure build = new CBaseStructure();
		build.iType = select;
		build.hPlugin = GetSubPlugin( smMap );
		build.iBuilder = GetClientUserId(client);
		
		NB_OnMenuSelected(build);
		if (NB_OnBuild(build)) {
			int team = GetClientTeam(client);
			for (int i=0 ; i<hConstructs[team-2].Length ; ++i) {
				CBaseStructure map = hConstructs[team-2].Get(i);
				if (map==null)
					continue;
				// if the entity of a structure doesn't exist, then delete it so we can recycle its index for a new structure
				if (!IsValidEntity(map.iEntity)) {
					delete map;
					hConstructs[team-2].Erase(i);
				}
			}
			hConstructs[team-2].Push(build);
			ReplyToCommand(client, "[NewBuild] Building %s Structure!", pluginName);
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
		if ( !(flags & FLAG_REQENG) )	// if it requires metal, it requires engie then
			base.iFlags |= FLAG_REQENG;
		
		if (TF2_GetPlayerClass(client) != TFClass_Engineer) {
			CPrintToChat(client, "{red}[NewBuild] {white}You need to be an Engineer to build that!");
			CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(iBuilding) );
			return false;
		}
		else if (GetEntProp(client, Prop_Data, "m_iAmmo", 4, 3) < base.iMetalBuild) {
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
	if (flags & FLAG_TEAM) {		// check if teammates have already built one of this
		CBaseStructure map;
		for (int i=0 ; i<hConstructs[team-2].Length ; ++i) {
			map = hConstructs[team-2].Get(i);
			if (map == null)
				continue;
			else if (map.iType != base.iType)	// if not the same thing, then skip
				continue;
			else if ( !(map.iFlags & FLAG_TEAM) )
				continue;

			if (IsValidEntity(map.iEntity)) {
				CPrintToChat(client, "{red}[NewBuild] {white}This building is Team limited and your Team already has one built.");
				CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(iBuilding) );
				return false;
			}
		}
	}
	if (flags & FLAG_PLAYER) {	// check if player has already built one of these
		CBaseStructure map;
		for (int i=0 ; i<hConstructs[team-2].Length ; ++i) {
			map = hConstructs[team-2].Get(i);
			if (map == null)
				continue;
			else if (map.iType != base.iType)
				continue;

			if (IsValidEntity(map.iEntity) and map.iBuilder == client) {
				CPrintToChat(client, "{red}[NewBuild] {white}You already have this building built dumby head!");
				CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(iBuilding) );
				return false;
			}
		}
	}
	
	pNBForws[OnBuild].Start();
	Call_PushCell(base.iType);
	Call_PushCell(base);
	Call_PushCell(iBuilding);	// set the model, health, other props, and targetname during this phase
	Call_Finish();
	
	SetEntProp( iBuilding, Prop_Send, "m_iTeamNum", team );
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
				base.iGlowRef = EntIndexToEntRef(iGlow);
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
			StringMap smMap = hArrayBuildings.Get(base.iType);
			char pluginName[64];
			smMap.GetString( "Name", pluginName, sizeof(pluginName) );
			for (int i=MaxClients ; i ; --i) {
				if (!IsValidClient(i))
					continue;
				else if (GetClientTeam(i) != team)
					continue;

				CPrintToChat(i, "{red}[NewBuild] {white}%s Built, Will activate in %f Minutes.", pluginName, base.flBuildTime/60.0);
			}
		}
	}
	else {
		CPrintToChat(client, "{red}[NewBuild] {white}You can't build the structure there.");
		CreateTimer( 0.1, RemoveEnt, EntIndexToEntRef(iBuilding) );
		return false;
	}
	base.iEntity = iBuilding;
	return true;
}

public Action OnBuildingTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!IsClientValid(attacker))
		return Plugin_Continue;
	
	int team = GetClientTeam(attacker);
	if ( team == GetEntProp(victim, Prop_Data, "m_iTeamNum") and IsClientValid(attacker) ) {
		//char tName[64]; GetEntPropString(victim, Prop_Data, "m_iName", tName, sizeof(tName));
		
		int teamindex, vecindex;
		vecindex = FindBaseByEntIndex(victim, teamindex);
		if (teamindex == -1 or vecindex == -1)
			return Plugin_Continue;

		char classname[32];
		if ( IsValidEdict(weapon) )
			GetEdictClassname(weapon, classname, sizeof(classname));

		if ( !strcmp(classname, "tf_weapon_wrench", false) or !strcmp(classname, "tf_weapon_robot_arm", false) )
		{
			// OnEngieInteract
			CBaseStructure map = hConstructs[teamindex].Get(vecindex);
			NB_OnEngieInteract(map, GetClientUserId(attacker));
		}
		damage = 0.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}
public void NB_OnEngieInteract(const CBaseStructure base, const int userid) // 2
{
	pNBForws[OnEngieInteract].Start();
	Call_PushCell(base.iType);
	Call_PushCell(base);
	Call_PushCell(userid);
	Call_Finish();
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
#define COLLISION_GROUP_PLAYER_MOVEMENT		8

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
		if (teamindex == -1 or vecindex == -1)
			return ;
		
		CBaseStructure building = hConstructs[teamindex].Get(vecindex);
		SetHudTextParams(0.93, -1.0, 0.1, 0, 255, 0, 255);
		
		char info[256];
		if (building.iFlags & FLAG_BUILT) {
			if (building.iFlags & FLAG_KILLABLE)
				Format(info, sizeof(info), "%sBuilding Health: %i/%i\n", info, building.iHealth, building.iMaxHealth);
			if (building.iFlags & FLAG_UPGRADEABLE)
				Format(info, sizeof(info), "%sBuilding Level: %i\n", info, building.iUpgradeLvl);
		}
		else {
			if (building.iFlags & FLAG_KILLABLE)
				Format(info, sizeof(info), "%sBuilding Health: %i/%i\n", info, GetEntProp(entity, Prop_Data, "m_iHealth"), building.iMaxHealth);
			Format(info, sizeof(info), "%sBuilding Time: %i\n", info, RoundFloat(building.flBuildTime));
		}
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
	
	CBaseStructure map = null;
	for (int team=0 ; team<2 ; ++team) {
		if (hConstructs[team] == null)
			continue;
		
		for (int i=0 ; i<hConstructs[team].Length ; ++i) {
			map = hConstructs[team].Get(i);
			if (map == null)
				continue;
			// if the entity of a structure doesn't exist, then delete it so we can recycle its index for a new structure
			else if (!IsValidEntity(map.iEntity)) {
				delete map;
				hConstructs[team].Erase(i);
				continue;
			}
			
			if ( !(map.iFlags & FLAG_BUILT) ) {	// handle building time
				map.flBuildTime -= 0.1;
				if (map.flBuildTime <= 0.0) {
					map.flBuildTime = 0.0;
					map.iFlags |= FLAG_BUILT;
				}
				else {
					//int buildinghp = GetEntProp(map.iEntity, Prop_Data, "m_iHealth");
					if (map.flBuildTime >= 1.0) {	// avoid dividing by 0
						int increase = map.iHealth/RoundFloat(map.flBuildTime);
						if (increase < 0)
							increase = 0;
						SetEntProp(map.iEntity, Prop_Data, "m_iHealth", increase);
					}
				}
			}
			else {	// is finally built, let's think
				NB_OnThink(map);
			}
		}
	}
	return Plugin_Continue;
}
stock int FindBaseByEntIndex(const int entity, int& teamind)	// O(n) time
{
	for (int i=0 ; i<2 ; ++i) {
		if (hConstructs[i] == null)
			continue;
		
		for (int k=0 ; k<hConstructs[i].Length ; ++k) {
			CBaseStructure map = hConstructs[i].Get(k);
			if (map==null)
				continue;
			if (map.iEntity == entity) {
				teamind = i;
				return k;
			}
		}
	}
	teamind = -1;
	return -1;
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

	if(FwdHandle != null)
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

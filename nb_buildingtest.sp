#include <sourcemod>
#include <morecolors>
#include <newbuild>

#pragma semicolon		1
#pragma newdecls		required

int ThisPluginIndex = -1;

public Plugin myinfo = {
	name = "nb_natives_tester",
	author = "Assyrian/Nergal",
	description = "plugin for testing newbuild's natives and forwards",
	version = "1.0",
	url = "http://www.sourcemod.net/"
};

public void OnPluginStart()
{

}

/* YOU NEED TO USE OnAllPluginsLoaded() TO REGISTER PLUGINS BECAUSE WE NEED TO MAKE SURE THE NewBuild PLUGIN LOADS FIRST */

//int ThisPluginIndex;
public void OnAllPluginsLoaded()
{
	ThisPluginIndex = NewBuild_Register("Tester");
	LoadNewBuildHooks();
}

public void fwdOnBuildCalled(const int iModuleIndex, const CStructure building, const int buildingRef)
{
	if (iModuleIndex != ThisPluginIndex) {
		LogError("NewBuild Error: Called Wrong Plugin!!!");
		return ;
	}
	/*
		FLAG_PLAYER|FLAG_KILLABLE|FLAG_METALREQ
				|FLAG_REQENG|FLAG_FIXENG|FLAG_GLOW
				|FLAG_TEAMUNCOLLIDEABLE|FLAG_KILLDISC|FLAG_KILLTEAMSWITCH
				|FLAG_UPGRADEABLE;
	*/
	building.SetProperty("iMaxHealth", 175);
	building.SetProperty("flBuildTime", 45.0);
	building.SetProperty("iMaxUpgradeLvl", 2);
	building.SetProperty("iMaxMetal", 200);
	building.SetProperty("iMetal", 0);
	
	int ent = EntRefToEntIndex(buildingRef);
	if (!IsValidEntity(ent))
		return;
	
	char tName[32]; tName[0] = 0;
	
	char szModelPath[PLATFORM_MAX_PATH];
	szModelPath = "models/structures/combine/barracks.mdl";
	Format(tName, sizeof(tName), "combine_barracks%i", GetRandomInt(0, 9999999));
	
	DispatchKeyValue(ent, "targetname", tName);

	PrecacheModel(szModelPath, true);
	SetEntityModel(ent, szModelPath);
	SetEntPropFloat(ent, Prop_Send, "m_flModelScale", 0.5);
}

public void fwdOnEngieInteract(const int iModuleIndex, const CStructure building, const int userid)
{
	if (iModuleIndex != ThisPluginIndex) {
		LogError("NewBuild Error: Called Wrong Plugin!!!");
		return ;
	}
	int engie = GetClientOfUserId(userid);
	if (engie) {
		CPrintToChat(engie, "{red}[NewBuild Test Plugin] {white}fwdOnEngieInteract::Called");
		if (building.GetProperty("iFlags") & FLAG_BUILT)
			CPrintToChat(engie, "{red}[NewBuild Test Plugin] {white}Fixing/Upgrading");
		else CPrintToChat(engie, "{red}[NewBuild Test Plugin] {white}Building Faster");
	}
}

public void fwdOnThink(const int iModuleIndex, const CStructure building)
{
	if (iModuleIndex != ThisPluginIndex) {
		LogError("NewBuild Error: Called Wrong Plugin!!!");
		return ;
	}
	int builder = GetClientOfUserId(building.GetProperty("iBuilder"));
	if (builder and IsClientInGame(builder))
		PrintToConsole(builder, "fwdOnThink::Called ; building flags ==> %i", building.GetProperty("iFlags"));
}
public void fwdOnMenuSelected(const int iModuleIndex, const CStructure building)
{
	if (iModuleIndex != ThisPluginIndex) {
		LogError("NewBuild Error: Called Wrong Plugin!!!");
		return ;
	}
	building.SetProperty("iMetalBuild", 200);
	int buildflags = FLAG_PLAYER|FLAG_KILLABLE|FLAG_METALREQ
				|FLAG_REQENG|FLAG_GLOW
				|FLAG_TEAMUNCOLLIDEABLE|FLAG_KILLDISC|FLAG_HITSPEEDSBUILD|FLAG_HITSPEEDENG
				|FLAG_UPGRADEABLE|FLAG_METALREQUPGRADE|FLAG_METALREQFIX;
	building.SetProperty("iFlags", buildflags);
}


public void LoadNewBuildHooks()
{
	if (!NewBuild_HookEx(OnBuild, fwdOnBuildCalled))
		LogError("Error loading OnBuild forwards for NewBuild Test plugin.");
		
	if (!NewBuild_HookEx(OnEngieInteract, fwdOnEngieInteract))
		LogError("Error loading OnEngieInteract forwards for NewBuild Test plugin.");
		
	if (!NewBuild_HookEx(OnThink, fwdOnThink))
		LogError("Error loading OnTouchPlayer forwards for NewBuild Test plugin.");
		
	if (!NewBuild_HookEx(OnMenuSelected, fwdOnMenuSelected))
		LogError("Error loading OnTouchBuilding forwards for NewBuild Test plugin.");
}

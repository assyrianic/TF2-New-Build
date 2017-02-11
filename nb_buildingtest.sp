#include <sourcemod>
#include <morecolors>
#include <newbuild>

#pragma semicolon		1
#pragma newdecls		required

public Plugin myinfo = {
	name = "nb_natives_tester",
	author = "Assyrian/Nergal",
	description = "plugin for testing newbuild's natives and forwards",
	version = "1.0",
	url = "http://www.sourcemod.net/"
};

int ThisPluginIndex = -1;

public void OnPluginStart()
{

}

/* YOU NEED TO USE OnAllPluginsLoaded() TO REGISTER PLUGINS BECAUSE WE NEED TO MAKE SURE THE NewBuild PLUGIN LOADS FIRST */

public void OnAllPluginsLoaded()
{
	ThisPluginIndex = NewBuild_Register("Tester");
	LoadNewBuildHooks();
}

public void fwdOnMenuSelected(const int iModuleIndex, const CStructure building)
{
	if (iModuleIndex != ThisPluginIndex) {
		LogError("NewBuild Error: Called Wrong Plugin!!!");
		return ;
	}
	building.SetProperty("iMetalBuild", 200);
	int buildflags = FLAG_PLAYER|FLAG_KILLABLE|FLAG_METALREQ|FLAG_GLOW
				|FLAG_TEAMUNCOLLIDEABLE|FLAG_KILLDISC|FLAG_HITSPEEDENG
				|FLAG_UPGRADEABLE|FLAG_METALREQUPGRADE|FLAG_METALREQFIX;
	building.SetProperty("iFlags", buildflags);
}

public void fwdOnBuildCalled(const int iModuleIndex, const CStructure building, const int buildingRef)
{
	if (iModuleIndex != ThisPluginIndex) {
		LogError("NewBuild Error: Called Wrong Plugin!!!");
		return ;
	}
	
	building.SetProperty("iMaxHealth", 175);
	building.SetProperty("flBuildTime", 45.0);
	building.SetProperty("iMaxUpgradeLvl", 2);
	building.SetProperty("iMaxUpgradeMetal", 200);
	building.SetProperty("iUpgradeMetal", 0);
	
	int ent = EntRefToEntIndex(buildingRef);
	if (!IsValidEntity(ent))
		return;
	
	char tName[32]; tName[0] = 0;
	
	char szModelPath[PLATFORM_MAX_PATH];
	szModelPath = "models/custom/daimler/daimler.mdl";
	Format(tName, sizeof(tName), "spenzer%i", GetRandomInt(0, 999999));
	
	DispatchKeyValue(ent, "targetname", tName);
	
	PrecacheModel(szModelPath, true);
	SetEntityModel(ent, szModelPath);
	DispatchKeyValue(ent, "skin", GetEntProp(ent, Prop_Data, "m_iTeamNum")==2 ? "0" : "1");

	//SetEntPropFloat(ent, Prop_Send, "m_flModelScale", 0.5);
}

public void fwdOnThink(const int iModuleIndex, const CStructure building)
{
	if (iModuleIndex != ThisPluginIndex) {
		LogError("NewBuild Error: Called Wrong Plugin!!!");
		return ;
	}
	int builder = GetClientOfUserId( building.GetProperty("iBuilder") );
	if ( builder )
		PrintToConsole(builder, "fwdOnThink::Called ; building flags ==> %i", building.GetProperty("iFlags"));
}

public void fwdOnInteract(const int iModuleIndex, const CStructure building, const int fixerid, int& amount, const bool fixing)
{
	if (iModuleIndex != ThisPluginIndex) {
		LogError("NewBuild Error: Called Wrong Plugin!!!");
		return ;
	}
	int engie = GetClientOfUserId(fixerid);
	if (engie and amount > 0) {	// check if amount is over 0 to see if they're allowed to fix/upgrade.
		if (fixing) {
			amount = 26;
			CPrintToChat(engie, "{red}[NewBuild Test Plugin] {white}fwdOnInteract::Fixing : %i", amount);
		} else {
			amount = 50;
			CPrintToChat(engie, "{red}[NewBuild Test Plugin] {white}fwdOnInteract::Upgrading : %i", amount);
		}
	}
}

public void fwdOnConstructInteract(const int iModuleIndex, const CStructure building, const int fixerid, float& amount)
{
	if (iModuleIndex != ThisPluginIndex) {
		LogError("NewBuild Error: Called Wrong Plugin!!!");
		return ;
	}
	
	int engie = GetClientOfUserId(fixerid);
	if (amount > 0.0) {	// check if amount is over 0 to see if they're allowed to fix/upgrade.
		amount = 10.0;
		CPrintToChat(engie, "{red}[NewBuild Test Plugin] {white}fwdOnConstructInteract::Building Faster : %f", amount);
	}
}

public void fwdOnInteractPost(const int iModuleIndex, const CStructure building, const int fixerid, const int amount, const bool fixing)
{
	if (iModuleIndex != ThisPluginIndex) {
		LogError("NewBuild Error: Called Wrong Plugin!!!");
		return ;
	}
	int engie = GetClientOfUserId(fixerid);
	if (engie and amount > 0) {	// check if amount is over 0 to see if they're allowed to fix/upgrade.
		if (fixing)
			CPrintToChat(engie, "{red}[NewBuild Test Plugin] {white}fwdOnInteractPost::Fixing : %i", amount);
		else CPrintToChat(engie, "{red}[NewBuild Test Plugin] {white}fwdOnInteractPost::Upgrading : %i", amount);
	}
}

public void fwdOnConstructInteractPost(const int iModuleIndex, const CStructure building, const int fixerid, const float amount)
{
	if (iModuleIndex != ThisPluginIndex) {
		LogError("NewBuild Error: Called Wrong Plugin!!!");
		return ;
	}
	
	int engie = GetClientOfUserId(fixerid);
	if (amount > 0.0)	// check if amount is over 0 to see if they're allowed to fix/upgrade.
		CPrintToChat(engie, "{red}[NewBuild Test Plugin] {white}fwdOnConstructInteractPost::Building Faster : %f", amount);
}

public void LoadNewBuildHooks()
{
	if (!NewBuild_HookEx(OnBuild, fwdOnBuildCalled))
		LogError("Error loading OnBuild forwards for NewBuild Test plugin.");
		
	if (!NewBuild_HookEx(OnThink, fwdOnThink))
		LogError("Error loading OnThink forwards for NewBuild Test plugin.");
		
	if (!NewBuild_HookEx(OnMenuSelected, fwdOnMenuSelected))
		LogError("Error loading OnMenuSelected forwards for NewBuild Test plugin.");
		
	if (!NewBuild_HookEx(OnInteract, fwdOnInteract))
		LogError("Error loading OnInteract forwards for NewBuild Test plugin.");
			
	if (!NewBuild_HookEx(OnConstructInteract, fwdOnConstructInteract))
		LogError("Error loading OnConstructInteract forwards for NewBuild Test plugin.");
			
	if (!NewBuild_HookEx(OnInteractPost, fwdOnInteractPost))
		LogError("Error loading OnInteractPost forwards for NewBuild Test plugin.");
			
	if (!NewBuild_HookEx(OnConstructInteractPost, fwdOnConstructInteractPost))
		LogError("Error loading OnConstructInteractPost forwards for NewBuild Test plugin.");
}

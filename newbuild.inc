#if defined _newbuild_included
	#endinput
#endif
	#define _newbuild_included

#include <sdktools>

#define IsClientValid(%1)	( (%1) && (%1) <= MaxClients && IsClientInGame((%1)) )
#define PLYR			MAXPLAYERS+1

#define and			&&
#define or			||

// use these for custom flags on custom buildings.
#define	SetBit(%1, %2)		( (%1) |= 1 << ((%2)) )
#define	ClearBit(%1, %2)	( (%1) &= ~(1 << ((%2)) )
#define	TestBit(%1, %2)		( (%1) & (1 << ((%2)) )


enum { __a = 1, __b, __c, __d, __e, __f, __g, __h, __i, __j, __k, __l, __m,
	__n, __o, __p, __q, __r, __s, __t, __u, __v, __w, __x, __y, __z
};

enum {		// flag enum, mostly used internally by the plugin
	FLAG_RED = 1<<__a,		// useable by red team
	FLAG_BLU = 1<<__b,		// useable by blu team. You can set both flags for the building to share with both teams
	FLAG_REDBUILT = 1<<__c,		// built by someone in red team, set internally by the core plugin
	FLAG_BLUBUILT = 1<<__d,		// built by someone in blu team, set internally by the core plugin
	FLAG_TEAM = 1<<__e,		// limited by team instead of player
	FLAG_PLAYER = 1<<__f,		// limited by player. You can limit by both player and team if necessary.
	FLAG_KILLABLE = 1<<__g,		// is destroyable structure
	FLAG_METALREQ = 1<<__h,		// requires metal to build ?
	FLAG_UPGRADEABLE = 1<<__i,	// can this structure be upgraded ?
	FLAG_TEAMUNCOLLIDEABLE = 1<<__j,	// can teammates go through this ? Advised if structure can block paths
	//FLAG_CARRIED = 1<<__k,		// is building being carried ?
	FLAG_REQENG = 1<<__l,		// do you need to be an engie to build this ?
	FLAG_UPGRADEENG = 1<<__m,	// do you need to be an engie to upgrade this ?
	FLAG_FIXENG = 1<<__n,		// do you need to be an engie to fix this ?
	//FLAG_MOVEABLE = 1<<__o,		// is the structure moveable by the player ? doesn't work right, try it yourself.
	FLAG_GLOW = 1<<__p,		// can builder and team see the structure through the walls ?
	FLAG_KILLDISC = 1<<__q,		// destroy structure when owner disconnects?
	FLAG_KILLTEAMSWITCH = 1<<__r,	// destroy structure when owner switches team?
	FLAG_KILLDEATH = 1<<__s,	// destroy structure when owner dies?
	FLAG_METALREQUPGRADE = 1<<__t,	// requires metal to upgrade? if set, automatically sets FLAG_UPGRADEENG flag
	FLAG_REQGUNSLINGER = 1<<__u,	// building requires gunslinger to build?
	FLAG_BUILT = 1<<__v,		// fully built and is doing its job.
	FLAG_METALREQFIX = 1<<__w,	// requires metal to fix? If set, will automatically set FLAG_FIXENG flag
	FLAG_HITSPEEDSBUILD = 1<<__x,	// does wrenches or melees speed up building?
	FLAG_HITSPEEDENG = 1<<__y,	// only engie melees can speed up building?  If set, will automatically set FLAG_HITSPEEDSBUILD flag
};

/*************************************************/
/******************* STOCKS **********************/
/*************************************************/
public Action RemoveEnt(Handle timer, any entid)
{
	int ent = EntRefToEntIndex(entid);
	if (ent and IsValidEntity(ent))
		AcceptEntityInput(ent, "Kill");
	return Plugin_Continue;
}
stock int GetHealingTarget(const int client)
{
	int medigun = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
	if (!IsValidEdict(medigun) or !IsValidEntity(medigun))
		return -1;

	char s[32]; GetEdictClassname(medigun, s, sizeof(s));
	if ( !strcmp(s, "tf_weapon_medigun", false) ) {
		if ( GetEntProp(medigun, Prop_Send, "m_bHealing") )
			return GetEntPropEnt( medigun, Prop_Send, "m_hHealingTarget" );
	}
	return -1;
}
stock bool IsNearDispenser(const int client)
{
	int medics=0;
	for ( int i=MaxClients ; i ; --i ) {
		if (!IsValidClient(i))
			continue;
		else if ( GetHealingTarget(i) == client )
			++medics;
	}
	return (GetEntProp(client, Prop_Send, "m_nNumHealers") > medics);
}
public bool TraceRayDontHitSelf(int entity, int mask, any data)
{
	return (entity != data);
}
stock bool IsInRange(const int entity, const int target, const float dist, bool pTrace=false)
{
	float entitypos[3]; GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", entitypos);
	float targetpos[3]; GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", targetpos);

	if ( GetVectorDistance(entitypos, targetpos) <= dist ) {
		if (!pTrace)
			return true;
		else {
			TR_TraceRayFilter( entitypos, targetpos, MASK_SHOT, RayType_EndPoint, TraceRayDontHitSelf, entity );
			if ( TR_GetFraction() > 0.98 )
				return true;
		}
	}
	return false;
}

stock int AttachParticle(const int ent, const char[] particleType, float offset=0.0, bool battach=true)
{
	int particle = CreateEntityByName("info_particle_system");
	char tName[128];
	float pos[3]; GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
	pos[2] += offset;
	TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
	Format(tName, sizeof(tName), "target%i", ent);
	DispatchKeyValue(ent, "targetname", tName);
	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", tName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(tName);
	if (battach) {
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", ent);
	}
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	CreateTimer(3.0, RemoveEnt, EntIndexToEntRef(particle));
	return particle;
}

stock void CreateParticles(const char[] particlename, float Pos[3] = NULL_VECTOR, const float time)
{
	int particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle)) {
		DispatchKeyValue(particle, "effect_name", particlename);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		TeleportEntity(particle, Pos, NULL_VECTOR, NULL_VECTOR);
		CreateTimer(time, RemoveEnt, EntIndexToEntRef(particle));
	}
	else LogError("CreateParticles: **** Couldn't Create 'info_particle_system Entity' ****");
}

stock int SetWeaponAmmo(const int weapon, const int ammo)
{
	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	if (owner <= 0)
		return 0;

	if (IsValidEntity(weapon)) {
		int iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		int iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		SetEntData(owner, iAmmoTable+iOffset, ammo, 4, true);
	}
	return 0;
}

stock int GetWeaponClip(const int weapon)
{
	if (IsValidEntity(weapon)) {
		int AmmoClipTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
		return GetEntData(weapon, AmmoClipTable);
	}
	return 0;
}

stock int SetWeaponClip(const int weapon, const int ammo)
{
	if (IsValidEntity(weapon)) {
		int iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
		SetEntData(weapon, iAmmoTable, ammo, 4, true);
	}
	return 0;
}

stock void SetClientOverlay(const int client, const char[] strOverlay)
{
	int iFlags = GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT);
	SetCommandFlags("r_screenoverlay", iFlags);
	ClientCommand(client, "r_screenoverlay \"%s\"", strOverlay);
}

stock bool IsValidClient(const int client, bool replaycheck=true)
{
	if (client <= 0 or client > MaxClients)
		return false;
	if (!IsClientInGame(client))
		return false;
	if (GetEntProp(client, Prop_Send, "m_bIsCoaching"))
		return false;
	if (replaycheck)
		if (IsClientSourceTV(client) or IsClientReplay(client))
			return false;
	return true;
}

stock int GetOwner(const int ent)
{
	if ( IsValidEdict(ent) and IsValidEntity(ent) )
		return GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
	return -1;
}

stock void MakeExplosion(const int owner, const int damage, const int radius, const float pos[3])
{
	int explode = CreateEntityByName("env_explosion");
	if ( !IsValidEntity(explode) )
		return;

	DispatchKeyValue(explode, "targetname", "exploder");
	DispatchKeyValue(explode, "spawnflags", "4");
	DispatchKeyValue(explode, "rendermode", "5");

	SetEntPropEnt(explode, Prop_Data, "m_hOwnerEntity", owner);
	SetEntProp(explode, Prop_Data, "m_iMagnitude", damage);
	SetEntProp(explode, Prop_Data, "m_iRadiusOverride", radius);

	int team = GetClientTeam(owner);
	SetVariantInt(team); AcceptEntityInput(explode, "TeamNum");
	SetVariantInt(team); AcceptEntityInput(explode, "SetTeam");

	TeleportEntity(explode, pos, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(explode);
	ActivateEntity(explode);
	AcceptEntityInput(explode, "Explode");
	AcceptEntityInput(explode, "Kill");
}
stock int GetWeaponAmmo(const int weapon)
{
	int owner = GetOwner(weapon);
	if (owner == -1)
		return 0;
	if (IsValidEntity(weapon)) {
		int iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
		int iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
		return GetEntData(owner, iAmmoTable+iOffset, 4);
	}
	return 0;
}
stock void TE_SendBeamBoxToAll (const float upc[3], const float btc[3], int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, const float Life, const float Width, const float EndWidth, int FadeLength, const float Amplitude, const int Color[4], const int Speed)
{
	// Create the additional corners of the box
	float tc1[] = {0.0, 0.0, 0.0};
	float tc2[] = {0.0, 0.0, 0.0};
	float tc3[] = {0.0, 0.0, 0.0};
	float tc4[] = {0.0, 0.0, 0.0};
	float tc5[] = {0.0, 0.0, 0.0};
	float tc6[] = {0.0, 0.0, 0.0};

	tc1 = Vec_AddVectors(tc1, upc); //AddVectors(tc1, upc, tc1);
	tc2 = Vec_AddVectors(tc2, upc); //AddVectors(tc2, upc, tc2);
	tc3 = Vec_AddVectors(tc3, upc); //AddVectors(tc3, upc, tc3);
	tc4 = Vec_AddVectors(tc4, btc); //AddVectors(tc4, btc, tc4);
	tc5 = Vec_AddVectors(tc5, btc); //AddVectors(tc5, btc, tc5);
	tc6 = Vec_AddVectors(tc6, btc); //AddVectors(tc6, btc, tc6);

	tc1[0] = btc[0];
	tc2[1] = btc[1];
	tc3[2] = btc[2];
	tc4[0] = upc[0];
	tc5[1] = upc[1];
	tc6[2] = upc[2];

	// Draw all the edges
	TE_SetupBeamPoints(upc, tc1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(upc, tc2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(upc, tc3, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc6, tc1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc6, tc2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc6, btc, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc4, btc, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc5, btc, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc5, tc1, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc5, tc3, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc4, tc3, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
	TE_SetupBeamPoints(tc4, tc2, ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
	TE_SendToAll();
}

stock int SpawnWeapon(const int client, char[] name, int index, int level, int qual, char[] att)
{
	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	if (hWeapon == null)
		return -1;
	
	TF2Items_SetClassname(hWeapon, name);
	TF2Items_SetItemIndex(hWeapon, index);
	TF2Items_SetLevel(hWeapon, level);
	TF2Items_SetQuality(hWeapon, qual);
	char atts[32][32];
	int count = ExplodeString(att, " ; ", atts, 32, 32);
	count &= ~1;
	if (count > 0) {
		TF2Items_SetNumAttributes(hWeapon, count/2);
		int i2=0;
		for (int i=0 ; i<count ; i += 2) {
			TF2Items_SetAttribute(hWeapon, i2, StringToInt(atts[i]), StringToFloat(atts[i+1]));
			i2++;
		}
	}
	else TF2Items_SetNumAttributes(hWeapon, 0);

	int entity = TF2Items_GiveNamedItem(client, hWeapon);
	delete (hWeapon);
	EquipPlayerWeapon(client, entity);
	return entity;
}

stock void SetWeaponInvis(const int client, const int alpha)
{
	int transparent = alpha;
	for (int i=0; i<5; i++) {
		int entity = GetPlayerWeaponSlot(client, i);
		if ( IsValidEdict(entity) and IsValidEntity(entity) )
		{
			if (transparent > 255)
				transparent = 255;
			if (transparent < 0)
				transparent = 0;
			SetEntityRenderMode(entity, RENDER_TRANSCOLOR); 
			SetEntityRenderColor(entity, 150, 150, 150, transparent); 
		}
	}
}
/*
stock TF2Item PrepareItemHandle(TF2Item hItem, char[] name = "", int index = -1, const char[] att = "", bool dontpreserve = false)
{
	static TF2Item hWeapon = null;
	int addattribs = 0;

	char weaponAttribsArray[32][32];
	int attribCount = ExplodeString(att, " ; ", weaponAttribsArray, 32, 32);

	int flags = OVERRIDE_ATTRIBUTES;
	if (!dontpreserve)
		flags |= PRESERVE_ATTRIBUTES;

	if ( !hWeapon )
		hWeapon = new TF2Item(flags);
	else hWeapon.iFlags = flags;
//	Handle hWeapon = TF2Items_CreateItem(flags);	//null;

	if (hItem != null) {
		addattribs = hItem.iNumAttribs;
		if (addattribs) {
			for (int i=0; i < 2*addattribs; i+=2) {
				bool dontAdd = false;
				int attribIndex = hItem.GetAttribID(i);
				for (int z=0; z < attribCount+i; z += 2) {
					if (StringToInt(weaponAttribsArray[z]) == attribIndex)
					{
						dontAdd = true;
						break;
					}
				}
				if (!dontAdd) {
					IntToString(attribIndex, weaponAttribsArray[i+attribCount], 32);
					FloatToString(hItem.GetAttribValue(i), weaponAttribsArray[i+1+attribCount], 32);
				}
			}
			attribCount += 2*addattribs;
		}
		delete hItem;
	}

	if (name[0] != '\0') {
		flags |= OVERRIDE_CLASSNAME;
		hWeapon.SetClassname(name);
	}
	if (index != -1) {
		flags |= OVERRIDE_ITEM_DEF;
		hWeapon.iItemIndex = index;
	}
	if (attribCount > 1) {
		hWeapon.iNumAttribs = (attribCount/2);
		int i2 = 0;
		for (int i=0; i<attribCount and i<32; i += 2)
		{
			hWeapon.SetAttribute(i2, StringToInt(weaponAttribsArray[i]), StringToFloat(weaponAttribsArray[i+1]));
			i2++;
		}
	}
	else hWeapon.iNumAttribs = 0;
	hWeapon.iFlags = flags;
	return hWeapon;
}
*/
/**
 * Wrapper function for easily setting up non-repeating timers
 *
 * @param func			Function pointer to call desired function when time elapses
 * @param thinktime		time in seconds when timer function will be called
 * @param param1		1st param for the call back function
 * @param param2		2nd param for the call back function
 *
 * @noreturn
 */

/*
If you need to use this and your function uses 3 parameters, modify it if necessary.
BUG/GLITCH: For some strange reason, SetPawnTimer doesn't work when u attempt to callback stock functions, interesting...
*/
stock void SetPawnTimer(Function func, float thinktime = 0.1, any param1 = -999, any param2 = -999, any param3 = -999)
{
	DataPack thinkpack = new DataPack();
	thinkpack.WriteFunction(func);
	thinkpack.WriteCell(param1);
	thinkpack.WriteCell(param2);
	thinkpack.WriteCell(param3);
	CreateTimer(thinktime, DoThink, thinkpack, TIMER_DATA_HNDL_CLOSE);
}

public Action DoThink(Handle hTimer, DataPack hndl)
{
	hndl.Reset();
	Function pFunc = hndl.ReadFunction();
	Call_StartFunction( null, pFunc );

	any param1 = hndl.ReadCell();
	if ( param1 != -999 )
		Call_PushCell(param1);

	any param2 = hndl.ReadCell();
	if ( param2 != -999 )
		Call_PushCell(param2);
		
	any param3 = hndl.ReadCell();
	if ( param3 != -999 )
		Call_PushCell(param3);

	Call_Finish();
	return Plugin_Continue;
}

stock float[] Vec_SubtractVectors(const float vec1[3], const float vec2[3])
{
	float result[3]; SubtractVectors(vec1, vec2, result);
	return result;
}
stock float[] Vec_AddVectors(const float vec1[3], const float vec2[3])
{
	float result[3]; AddVectors(vec1, vec2, result);
	return result;
}
stock float[] Vec_ScaleVector(const float vec[3], const float scale)
{
	float result[3];
	result[0] = vec[0] * scale;
	result[1] = vec[1] * scale;
	result[2] = vec[2] * scale;
	return result;
}
stock float[] Vec_NegateVector(const float vec[3])
{
	float result[3];
	result[0] = -vec[0];
	result[1] = -vec[1];
	result[2] = -vec[2];
	return result;
}
stock float[] Vec_GetVectorAngles(const float vec[3])
{
	float angResult[3]; GetVectorAngles(vec, angResult);
	return angResult;
}
stock float[] Vec_GetVectorCrossProduct(const float vec1[3], const float vec2[3])
{
	float result[3]; GetVectorCrossProduct(vec1, vec2, result);
	return result;
}
stock float[] Vec_MakeVectorFromPoints(const float pt1[3], const float pt2[3])
{
	float output[3]; MakeVectorFromPoints(pt1, pt2, output);
	return output;
}
stock float[] Vec_GetEntPropVector(const int entity, const PropType type, const char[] prop, int element=0)
{
	float output[3]; GetEntPropVector(entity, type, prop, output, element);
	return output;
}
stock float[] Vec_NormalizeVector(const float vec[3])
{
	float output[3]; NormalizeVector(vec, output);
	return output;
}
stock float[] Vec_GetAngleVecForward(const float angle[3])
{
	float output[3]; GetAngleVectors(angle, output, NULL_VECTOR, NULL_VECTOR);
	return output;
}
stock float[] Vec_GetAngleVecRight(const float angle[3])
{
	float output[3]; GetAngleVectors(angle, NULL_VECTOR, output, NULL_VECTOR);
	return output;
}
stock float[] Vec_GetAngleVecUp(const float angle[3])
{
	float output[3]; GetAngleVectors(angle, NULL_VECTOR, NULL_VECTOR, output);
	return output;
}

stock int QueryEntities(const float origin[3], const float radius, int[] array, const int size)
{
	array = new int[size];
	int count = 0;
	float xyz[3];
	for (int l=1 ; l<2048 ; ++l) {
		if ( !IsValidEdict(l) or !IsValidEntity(l) ) 
			continue;
		else if (count >= size)
			break;

		xyz = Vec_GetEntPropVector(l, Prop_Data, "m_vecAbsOrigin");
		if (GetVectorDistance(xyz, origin) <= radius)
			array[count++] = l;
	}
	return count;
}

stock int QueryPlayers(const float origin[3], const float radius, int[] array, const int size, const int team)
{
	array = new int[size];
	int count = 0;
	float xyz[3];
	for (int l=MaxClients ; l ; l--) {
		if ( !IsClientInGame(l) ) 
			continue;
		else if ( !IsPlayerAlive(l) or GetClientTeam(l) != team )
			continue;
		else if (count >= size)
			break;

		GetClientAbsOrigin(l, xyz);
		if (GetVectorDistance(xyz, origin) <= radius)
			array[count++] = GetClientUserId(l);
	}
	return count;
}
stock bool IsClientStuck(const int iEntity, const float flOrigin[3])
{
	//float flOrigin[3]; GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", flOrigin);
	float flMins[3]; GetEntPropVector(iEntity, Prop_Send, "m_vecMins", flMins);
	float flMaxs[3]; GetEntPropVector(iEntity, Prop_Send, "m_vecMaxs", flMaxs);

	TR_TraceHullFilter(flOrigin, flOrigin, flMins, flMaxs, MASK_PLAYERSOLID, TraceFilterNotSelf, iEntity);
	return TR_DidHit();
}
public bool TraceFilterNotSelf(int entity, int contentsMask, any client)
{
	if (entity == client)
		return false;
	return true;
}
stock bool BringClientToSide(const int client, const float flOrigin[3])
{
	float vec_modifier[3];
	const float flMove = 85.0;
	vec_modifier = flOrigin; vec_modifier[0] += flMove;	// check x-axis
	if (!IsClientStuck(client, vec_modifier)) {
		TeleportEntity(client, vec_modifier, NULL_VECTOR, NULL_VECTOR);
		return true;
	}
	vec_modifier = flOrigin; vec_modifier[0] -= flMove;
	if (!IsClientStuck(client, vec_modifier)) {
		TeleportEntity(client, vec_modifier, NULL_VECTOR, NULL_VECTOR);
		return true;
	}
	vec_modifier = flOrigin; vec_modifier[1] += flMove;	// check y-axis
	if (!IsClientStuck(client, vec_modifier)) {
		TeleportEntity(client, vec_modifier, NULL_VECTOR, NULL_VECTOR);
		return true;
	}
	vec_modifier = flOrigin; vec_modifier[1] -= flMove;
	if (!IsClientStuck(client, vec_modifier)) {
		TeleportEntity(client, vec_modifier, NULL_VECTOR, NULL_VECTOR);
		return true;
	}
	vec_modifier = flOrigin; vec_modifier[2] += flMove;	// check z-axis
	if (!IsClientStuck(client, vec_modifier)) {
		TeleportEntity(client, vec_modifier, NULL_VECTOR, NULL_VECTOR);
		return true;
	}
	vec_modifier = flOrigin; vec_modifier[2] -= flMove;
	if (!IsClientStuck(client, vec_modifier)) {
		TeleportEntity(client, vec_modifier, NULL_VECTOR, NULL_VECTOR);
		return true;
	}
	return false;
}
stock float fmax(float a, float b)
{
	return (a > b) ? a : b ;
}

stock float Vec2DLength(float v[2])
{
	float length = 0.0;
	for (int i=0 ; i<2 ; ++i)
		length += v[i]*v[i];
	
	length = SquareRoot (length);
	return length;
}

stock bool CalcBuildPos(const int builder, const float flMins[3], const float flMaxs[3], float flBuildBuffer[3])
{
	if (builder <= 0)
		return false ;
	
	float vec_forward[3];
	float vec_angles[3], vec_objangles[3];
	GetClientEyeAngles(builder, vec_angles);
	// we only need the y-angle
	vec_angles[0] = 0.0, vec_angles[2] = 0.0;
	vec_objangles = vec_angles;
	GetAngleVectors(vec_angles, vec_forward, NULL_VECTOR, NULL_VECTOR);
	
	float vec_objradius[2];
	vec_objradius[0] = fmax( flMins[0], flMaxs[0] );
	vec_objradius[1] = fmax( flMins[1], flMaxs[1] );
	
	float vec_playerRadius[2];
	float vecPlayerMins[3], vecPlayerMaxs[3];
	
	GetClientMaxs(builder, vecPlayerMaxs);
	GetClientMins(builder, vecPlayerMins);
	vec_playerRadius[0] = fmax( vecPlayerMins[0], vecPlayerMaxs[0] );
	vec_playerRadius[1] = fmax( vecPlayerMins[1], vecPlayerMaxs[1] );
	
	float fldist = Vec2DLength(vec_objradius) + Vec2DLength(vec_playerRadius) + 4.0;
	
	float vecBuildOrigin[3];
	float vec_playerorigin[3];
	GetClientAbsOrigin(builder, vec_playerorigin);
	
	ScaleVector(vec_forward, fldist);
	AddVectors(vec_playerorigin, vec_forward, vecBuildOrigin);
	
	flBuildBuffer = vecBuildOrigin;
	
	float vBuildDims[3];
	SubtractVectors(flMaxs, flMins, vBuildDims);
	
	float vHalfBuildDims[3];
	vHalfBuildDims = vBuildDims;
	ScaleVector(vHalfBuildDims, 0.5);
	
	
	//Vector vErrorOrigin = vecBuildOrigin - (m_vecBuildMaxs - m_vecBuildMins) * 0.5f - m_vecBuildMins;
	float vErrorOrigin[3];
	{
		SubtractVectors(vecBuildOrigin, vHalfBuildDims, vErrorOrigin);
		SubtractVectors(vErrorOrigin, flMins, vErrorOrigin);
	}
	
	float vHalfPlayerDims[3];
	{
		float mins[3]; GetClientMins(builder, mins);
		float maxs[3]; GetClientMaxs(builder, maxs);
		SubtractVectors(maxs, mins, vHalfPlayerDims);
		ScaleVector(vHalfPlayerDims, 0.5);
	}
	float flBoxTopZ = vec_playerorigin[2] + vHalfPlayerDims[2] + vBuildDims[2];
	float flBoxBottomZ = vec_playerorigin[2] - vHalfPlayerDims[2] - vBuildDims[2];
	
	float bottomZ = 0.0;
	int nIterations = 8;
	float topZ = flBoxTopZ;
	float topZInc = (flBoxBottomZ - flBoxTopZ) / (nIterations-1);
	int iIteration;
	
	float checkOriginTop[3];
	checkOriginTop = vecBuildOrigin;
	float checkOriginBottom[3];
	checkOriginBottom = vecBuildOrigin;
	
	float endpos[3];
	for (iIteration=0 ; iIteration<nIterations ; ++iIteration) {
		//checkOriginTop[2] = topZ;
		//checkOriginBottom[2] = flBoxBottomZ;
		
		TR_TraceHull( vecBuildOrigin, vecBuildOrigin, flMins, flMaxs, MASK_SOLID );
		TR_GetEndPosition(endpos);
		bottomZ = endpos[2];
		
		if (TR_GetFraction() == 1.0 /*or TR_PointOutsideWorld(endpos)*/) {	// no ground, can't build here!
			flBuildBuffer = vErrorOrigin;
			return false;
		}
		
		// if we found enough space to fit our object, place here
		if ( topZ - bottomZ > vBuildDims[2]
			and !(TR_GetPointContents(vecBuildOrigin) & MASK_SOLID)
			and !(TR_GetPointContents(vecBuildOrigin) & MASK_SOLID) )
			break;
		
		++vecBuildOrigin[2];
		topZ += topZInc;
	}
	if ( iIteration == nIterations ) {
		flBuildBuffer = vErrorOrigin;
		return false;
	}
		
	// Now see if the range we've got leaves us room for our box.
	if ( topZ-bottomZ < vBuildDims[2] ) {
		flBuildBuffer = vErrorOrigin;
		return false;
	}
	
	// Ok, now we know the Z range where this box can fit.
	float vBottomLeft[3];
	SubtractVectors(vecBuildOrigin, vHalfBuildDims, vBottomLeft);
	vBottomLeft[2] = bottomZ;
	
	SubtractVectors(vBottomLeft, flMins, vecBuildOrigin);
	flBuildBuffer = vecBuildOrigin;
	return true;
	
	/*
	bool bSuccess;
	for ( int i=301 ; i ; --i ) {
		TR_TraceHull( vecBuildOrigin, vecBuildOrigin, flMins, flMaxs, MASK_SOLID );
		if (bSuccess)
			break;
		
		if (TR_GetFraction() == 0.99 or TR_GetFraction() == 0.98)
			bSuccess = true; //PrintToConsole(builder, "tr.fraction");
		else if (TR_DidHit())
			vecBuildOrigin[2] += 0.1;
	}
	flBuildBuffer = vecBuildOrigin;
	PrintToConsole(builder, "%i", (bSuccess == true));
	return bSuccess;
	*/
}

stock bool IsPlacementPosValid(const int builder, const float flMins[3], const float flMaxs[3], float flBuildBuffer[3])
{
	bool bValid = CalcBuildPos(builder, flMins, flMaxs, flBuildBuffer);

	if ( !bValid )
		return false;
	
	if ( builder <= 0 )
		return false;
	
	// Make sure we can see the final position
	float EyePos[3]; GetClientEyePosition(builder, EyePos);
	float BuildOriginSum[3];
	{
		float tempvec[3];
		tempvec[0] = 0.0, tempvec[1] = 0.0, tempvec[2] = flMaxs[2] * 0.5;
		AddVectors(flBuildBuffer, tempvec, BuildOriginSum);
	}
	TR_TraceRayFilter( EyePos, BuildOriginSum, MASK_PLAYERSOLID_BRUSHONLY, RayType_EndPoint, TraceRayDontHitSelf, builder );
	if ( TR_GetFraction() < 1.0 )
		return false;

	return true;
}
stock bool SetTrieValueCaseInsensitive(StringMap trie, const char[] key, any value)
{
	int length = strlen(key)+1;
	char[] trieKey = new char[length];
	StringToLower(key, trieKey, length);
	return trie.SetValue(trieKey, value); //SetTrieValue(trie, trieKey, value);
}

stock void StringToLower(const char[] input, char[] output, int size)
{
	for (int i=0 ; i<size ; ++i)
		output[i] = input[i] | ' ';
}
stock void StringToUpper(const char[] input, char[] output, int size)
{
	for (int i=0 ; i<size ; ++i)
		output[i] = input[i] & '_';
}
stock bool ValidateName(const char[] name)
{
	int length = strlen(name);
	for (int i=0 ; i<length ; ++i) {
		int holder = name[i];
		// Invalid name, names may only contains numbers, underscores and normal letters
		if (!(IsCharAlpha(holder) || IsCharNumeric(holder) || holder == '_'))
			return false;
	}
	// A name is, of course, only valid if it's 1 or more chars long, though longer is recommended
	return (length > 0);
}
stock bool GetTrieValueCaseInsensitive(StringMap trie, const char[] key, any& value)
{
	if (trie == null)
		return false;
	int length = strlen(key)+1;
	char[] trieKey = new char[length];
	StringToLower(key, trieKey, length);
	return trie.GetValue(trieKey, value); //GetTrieValue(trie, trieKey, value);
}
stock Handle GetSubPlugin(StringMap hndl)
{
	Handle plugin;
	if ( hndl.GetValue("Subplugin", plugin) )
		return plugin;
	// Shouldn't actually get here, but we keep it just incase
	return null;
}
stock int GetBuilder(const int ent)
{
	if ( IsValidEdict(ent) && IsValidEntity(ent) )
		return GetEntPropEnt(ent, Prop_Send, "m_hBuilder");
	return -1;
}
///////////////////////////////////////////////////////////////////////////////////////////////////////////////


methodmap CStructure < Handle {
	public native CStructure();

	public native any GetProperty(const char prop_name[64]);	
	public native void SetProperty(const char prop_name[64], any value);
	//	Notice:
	//	You can add new properties, using SetProperty, for your subplugin to use!
	
	/*			Available Useable Properties.
	property int iEntity			- entity index of this building.
	property int iFlags			- building flags.
	property int iType			- building type, uses plugin index SO BE VERY CAREFUL.
	property int iBuilder			- client index of builder; set using userid, returns client index.
	property int iUpgradeMetal		- current amount of metal building has in it.
	property int iMaxUpgradeMetal		- maxmetal required to upgrade this.
	property int iHealth			- if destructable, current health
	property int iMaxHealth			- ditto, max health it can go to
	property int iMetalBuild		- how much metal is required to first create this building?
	property int iUpgradeLvl		- current upgrade level
	property int iMaxUpgradeLvl		- max level building can reach
	property float flBuildTime		- when created, how long it takes for building to start doing its thing?
	*/
};

native int NewBuild_Register(const char plugin_name[64]);

enum {	// call back types
	OnBuild=0,		// checks if the building already exists or not depending on flags, set building stuff like the model here
	OnThink,		// 0.1 second timer, use GetGameTime within hook for lesser time
	OnInteract,		// when a player melees a building that's fully built, will either fix or upgrade.
	OnInteractPost,
	OnConstructInteract,	// when a player melees a building that is constructing
	OnConstructInteractPost,
	OnMenuSelected		// LEAVE THIS AS LAST ONE, set flags when this calls
};

typeset NBHookCB {
	// OnThink - called ever 0.1 seconds (timer)
	// OnMenuSelected - called after selecting a building from the menu.
	function void	(const int iModuleIndex, const CStructure building);
	
	// OnBuild - called right after OnMenuSelected is called. Initiates building
	function void	(const int iModuleIndex, const CStructure building, const int buildingRef);
	
	// OnInteract - called during fixing and upgrading
	// amount will be the upgrade/fix amount that will be applied to the building.
	// if engie and metal is required, amount will be subtracted from metal supply.
	// fixing var is to see if the interaction is fixing or upgrading; false if upgrading.
	// this forward is called BEFORE applying the metal and subtracting engie metal.
	function void	(const int iModuleIndex, const CStructure building, const int fixerid, int& amount, const bool fixing);
	
	// OnInteractPost
	function void	(const int iModuleIndex, const CStructure building, const int fixerid, const int amount, const bool fixing);
	
	// OnConstructInteract
	function void	(const int iModuleIndex, const CStructure building, const int fixerid, float& amount);
	
	// OnConstructInteractPost
	function void	(const int iModuleIndex, const CStructure building, const int fixerid, const float amount);
};

native void	NewBuild_Hook		(int type, NBHookCB func);
native bool	NewBuild_HookEx		(int type, NBHookCB func);


native void	NewBuild_Unhook		(int type, NBHookCB func);
native bool	NewBuild_UnhookEx	(int type, NBHookCB func);

/*
	returns the number of structures built per team
*/
native int	NewBuild_BuiltOnRed	();
native int	NewBuild_BuiltOnBlu	();


public SharedPlugin __pl_NewBuild = {
	name = "newbuild",
	file = "NewBuild.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_NewBuild_SetNTVOptional()
{
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
}
#endif

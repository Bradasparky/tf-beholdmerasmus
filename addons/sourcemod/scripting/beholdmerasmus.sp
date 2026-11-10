#include <sdkhooks>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define EF_NODRAW 32
#define EF_NOSHADOW 16

#define KUKRI 3
#define JARATE 58

#define MAX_BOMBS_PER_TICK 4
#define BOMB_START_OFFSET_Z 150.0
#define BOMB_VERT_VEL 750.0
#define BOMB_HALF_HEIGHT 30.0 // Accurate enough

#define MERASMUS_NPC_MODEL		"models/bots/merasmus/merasmus.mdl"
#define MERASMUS_PLAYER_MODEL	"models/player/merasmus_player/merasmus_player.mdl"
#define MERASMUS_STAFF			"models/weapons/c_models/c_merasmus_staff/c_merasmus_staff.mdl"
#define BOMB_MODEL				"models/props_lakeside_event/bomb_temp.mdl"
#define HELD_BOMB_MODEL			"models/weapons/c_models/c_heldbomb/c_heldbomb.mdl"

#define SND_SPAWN				"Halloween.MerasmusBossSpawn"
#define SND_APPEAR				"Halloween.MerasmusAppears"
#define SND_FLOAT				"Halloween.Merasmus_Float"
#define SND_STAFF_HIT			"Halloween.HeadlessBossAxeHitFlesh"
#define SND_STAFF_ATTACK		"Halloween.MerasmusStaffAttack"
#define SND_STAFF_ATTACK_RARE	"Halloween.MerasmusStaffAttackRare"
#define SND_GRENADE_THROW		"Halloween.MerasmusGrenadeThrow"
#define SND_GRENADE_THROW_RARE	"Halloween.MerasmusGrenadeThrowRare"
#define SND_SPELL 				"Halloween.Merasmus_Spell"
#define SND_FIRESPELL 			"Halloween.MerasmusCastFireSpell"
#define SND_LAUNCHSPELL			"Halloween.MerasmusLaunchSpell"
#define SND_DEATH				"Halloween.Merasmus_Death"
#define SND_BANISH				"Halloween.MerasmusBanish"

#define PLUGIN_VERSION "1.0.0"

public Plugin myinfo =
{
	name = "[TF2] Behold, Merasmus!",
	author = "Bradasparky",
	description = "Allows for admins and other plugins to turn players into Merasmus",
	version = PLUGIN_VERSION,
	url = "https://github.com/Bradasparky/tf-beholdmerasmus"
}

enum
{
	Taunt_None,
	Taunt_Repurpose,
	Taunt_UsesWeapon
}

// This is so players' eardrums don't get blown out
enum
{
	LastPlayed_Spawn,
	LastPlayed_Death,
	LastPlayed_Max
}

char g_sModelFiles[][] =
{
	MERASMUS_PLAYER_MODEL,
	"models/player/merasmus_player/merasmus_player.dx80.vtx",
	"models/player/merasmus_player/merasmus_player.dx90.vtx",
	"models/player/merasmus_player/merasmus_player.phy",
	"models/player/merasmus_player/merasmus_player.vvd",
	HELD_BOMB_MODEL,
	"models/weapons/c_models/c_heldbomb/c_heldbomb.dx80.vtx",
	"models/weapons/c_models/c_heldbomb/c_heldbomb.dx90.vtx",
	"models/weapons/c_models/c_heldbomb/c_heldbomb.phy",
	"models/weapons/c_models/c_heldbomb/c_heldbomb.vvd",
	MERASMUS_STAFF,
	"models/weapons/c_models/c_merasmus_staff/c_merasmus_staff.dx80.vtx",
	"models/weapons/c_models/c_merasmus_staff/c_merasmus_staff.dx90.vtx",
	"models/weapons/c_models/c_merasmus_staff/c_merasmus_staff.phy",
	"models/weapons/c_models/c_merasmus_staff/c_merasmus_staff.vvd"
};

char g_sLaughSnd[][] = 
{
	"vo/halloween_merasmus/sf12_combat_idle01.mp3",
	"vo/halloween_merasmus/sf12_combat_idle02.mp3"
};

ConVar cvDropAmmo;
ConVar cvMaxHealth;
ConVar cvMeleeDamage;
ConVar cvHellfireCooldown;
ConVar cvHellfireDamageMin;
ConVar cvHellfireDamageMax;
ConVar cvHellfireIgnite;
ConVar cvAoECooldown;
ConVar cvAoEDamage;
ConVar cvAoERadius;
ConVar cvGrenadeDamage;
ConVar cvGrenadeRadius;

bool g_bIsMerasmus[MAXPLAYERS + 1];
bool g_bInAnimation[MAXPLAYERS + 1];
bool g_bInAoEAttack[MAXPLAYERS + 1];
bool g_bInHellfireAttack[MAXPLAYERS + 1];
int g_iZapParticle = -1;
int g_iSpawnParticle = -1;
int g_iLastWinningTeam = -1;
int g_iOffset_m_flDetonateTime;
int g_iAnimProp[MAXPLAYERS + 1] = { -1, ... };
int g_iSceneFile[MAXPLAYERS + 1] = { -1, ... };
int g_iStaffWorldModel[MAXPLAYERS + 1] = { -1, ... };
int g_iBombWorldModel[MAXPLAYERS + 1] = { -1, ... };
int g_iAoEParticle[MAXPLAYERS + 1] = { -1, ... };
float g_flLastSndPlayTime[LastPlayed_Max];
float g_flNextBombAttack[MAXPLAYERS + 1];
float g_flNextBombSpawnTick[MAXPLAYERS + 1];
float g_flNextHellfireTime[MAXPLAYERS + 1];
float g_flNextAoETime[MAXPLAYERS + 1];
Handle g_hSDKCall_GetMaxHealth;
Handle g_hSDKCall_InitGrenade;
Handle g_hHudSyncronizer;
Handle g_hHudTimer[MAXPLAYERS + 1];
Handle g_hAbilityTimer[MAXPLAYERS + 1];
ArrayList g_hBombs;
ArrayList g_hCritBoostedGrenades;
ArrayList g_hBombQueue[MAXPLAYERS + 1];

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("beholdmerasmus.phrases");

    GameData hGameData = new GameData("sdkhooks.games/engine.ep2v");
    if (!hGameData)
        SetFailState("Failed to find gamedata at %s", "sdkhooks.games/engine.ep2v");

    StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "GetMaxHealth");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);

    g_hSDKCall_GetMaxHealth = EndPrepSDKCall();
    if (!g_hSDKCall_GetMaxHealth)
    {
        delete g_hSDKCall_GetMaxHealth;
        SetFailState("Failed to hook SDKCall GetMaxHealth");
    }

    delete hGameData;
	hGameData = new GameData("tf2.beholdmerasmus");
	if (!hGameData)
		SetFailState("Failed to find gamedata tf2.beholdmerasmus.txt");

	int iOffset = hGameData.GetOffset("CBaseGrenade::m_flDetonateTime");
	if (iOffset == -1)
		SetFailState("Failed to find gamedata for CBaseGrenade::m_flDetonateTime");
	
	g_iOffset_m_flDetonateTime = FindSendPropInfo("CBaseGrenade", "m_hThrower") + iOffset;

	iOffset = hGameData.GetOffset("CTFWeaponBaseGrenadeProj::InitGrenade");
	if (iOffset == -1)
		SetFailState("Failed to find gamedata for CTFWeaponBaseGrenadeProj::InitGrenade");
		
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(iOffset);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_ByValue);
	g_hSDKCall_InitGrenade = EndPrepSDKCall();

	if (!g_hSDKCall_InitGrenade)
		SetFailState("Failed to hook CTFWeaponBaseGrenadeProj::InitGrenade");
		
	CreateConVar("sm_beholdmerasmus_version", PLUGIN_VERSION, "Plugin version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	cvDropAmmo = CreateConVar("sm_beholdmerasmus_dropammo", "0", "Whether Merasmus should drop an ammo kit on death.", _, true, 0.0, true, 1.0);
	cvMaxHealth = CreateConVar("sm_beholdmerasmus_maxhealth", "1000", "Merasmus default max health if no health parameter is specified.", _, true, 1.0);
	cvMeleeDamage = CreateConVar("sm_beholdmerasmus_melee_damage", "70", "Merasmus melee damage.", FCVAR_NOTIFY, true, 0.0);
	cvHellfireCooldown = CreateConVar("sm_beholdmerasmus_hellfire_cooldown", "8.0", "Merasmus hellfire attack cooldown.", _, true, 0.0);
	cvHellfireDamageMin = CreateConVar("sm_beholdmerasmus_hellfire_damage_min", "20", "Merasmus hellfire attack minimum damage.", _, true, 0.0);
	cvHellfireDamageMax = CreateConVar("sm_beholdmerasmus_hellfire_damage_max", "50", "Merasmus hellfire attack maximum damage.", _, true, 0.0);
	cvHellfireIgnite = CreateConVar("sm_beholdmerasmus_hellfire_ignite", "1", "Whether the Merasmus hellfire attack ignites players.", _, true, 0.0, true, 1.0);
	cvAoECooldown = CreateConVar("sm_beholdmerasmus_aoe_cooldown", "30.0", "Merasmus AoE attack cooldown.", _, true, 0.0);
	cvAoEDamage = CreateConVar("sm_beholdmerasmus_aoe_damage", "50", "Merasmus AoE bomb damage.", _, true, 0.0);
	cvAoERadius = CreateConVar("sm_beholdmerasmus_aoe_radius", "300.0", "Merasmus AoE bomb explosion radius.", _, true, 0.0);
	cvGrenadeDamage = CreateConVar("sm_beholdmerasmus_grenade_damage", "50", "Merasmus grenade damage.", _, true, 0.0);
	cvGrenadeRadius = CreateConVar("sm_beholdmerasmus_grenade_radius", "300.0", "Merasmus grenade explosion radius.", _, true, 0.0);

	AutoExecConfig(true, "beholdmerasmus");

	RegAdminCmd("sm_bemeras", Command_BeMerasmus, ADMFLAG_ROOT, "sm_bemeras <#userid|name> [health]");
	RegAdminCmd("sm_bemerasmus", Command_BeMerasmus, ADMFLAG_ROOT, "sm_bemerasmus <#userid|name> [health]");
	
	HookEvent("arrow_impact", Event_OnArrowImpact, EventHookMode_Pre);
	HookEvent("post_inventory_application", Event_OnPlayerResupply, EventHookMode_Pre);
	HookEvent("player_team", Event_OnPlayerChangeTeam);
	HookEvent("player_death", Event_OnPlayerDeathPre, EventHookMode_Pre);
	HookEvent("player_death", Event_OnPlayerDeathPost, EventHookMode_Post);
	HookEvent("teamplay_round_win", Event_OnRoundEnd);
	HookEvent("teamplay_round_start", Event_OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", Event_OnRoundStart, EventHookMode_PostNoCopy);

	AddNormalSoundHook(SoundHook_Merasmus);

	g_hHudSyncronizer = CreateHudSynchronizer();
	g_hBombs = new ArrayList();
	g_hBombs.Resize(GetMaxEntities());
	g_hCritBoostedGrenades = new ArrayList();
	g_hCritBoostedGrenades.Resize(GetMaxEntities());

	for (int i = MaxClients; i; i--)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
}

public void OnPluginEnd()
{
	for (int i = MaxClients; i; i--)
		if (g_bIsMerasmus[i])
			RemoveMerasmus(i);
}

public void OnMapStart()
{
	for (int i; i < sizeof(g_sModelFiles); i++)
	{
		if (FileExists(g_sModelFiles[i], true))
			AddFileToDownloadsTable(g_sModelFiles[i]);
		else
			SetFailState("Failed to add '%s' to the downloads table. File does not exist.", g_sModelFiles[i]);
	}

	int iTableIndex = FindStringTable("ParticleEffectNames");
	if (iTableIndex != -1)
	{
		g_iSpawnParticle = FindStringIndex(iTableIndex, "merasmus_spawn");
		g_iZapParticle = FindStringIndex(iTableIndex, "merasmus_zap");
	}

	PrecacheModel(MERASMUS_PLAYER_MODEL, true);
	PrecacheModel(BOMB_MODEL, true);
	PrecacheModel(HELD_BOMB_MODEL, true);
	PrecacheScriptSound(SND_SPAWN);
	PrecacheScriptSound(SND_APPEAR);
	PrecacheScriptSound(SND_FLOAT);
	PrecacheScriptSound(SND_STAFF_HIT);
	PrecacheScriptSound(SND_STAFF_ATTACK);
	PrecacheScriptSound(SND_STAFF_ATTACK_RARE);
	PrecacheScriptSound(SND_GRENADE_THROW);
	PrecacheScriptSound(SND_GRENADE_THROW_RARE);
	PrecacheScriptSound(SND_SPELL);
	PrecacheScriptSound(SND_FIRESPELL);
	PrecacheScriptSound(SND_LAUNCHSPELL);
	PrecacheScriptSound(SND_FLOAT);
	PrecacheScriptSound(SND_DEATH);
	PrecacheScriptSound(SND_BANISH);

	for (int i; i < sizeof(g_sLaughSnd); i++)
		PrecacheSound(g_sLaughSnd[i], true);
}

public void OnClientPutInServer(int iClient)
{
	g_bIsMerasmus[iClient] = false;
	g_bInAnimation[iClient] = false;
	g_iAnimProp[iClient] = -1;
	g_iSceneFile[iClient] = -1;
	g_iStaffWorldModel[iClient] = -1;
	g_iBombWorldModel[iClient] = -1;
	g_flNextHellfireTime[iClient] = 0.0;
	g_flNextAoETime[iClient] = 0.0;

	SDKHook(iClient, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

public void OnClientDisconnect(int iClient)
{
	if (g_bIsMerasmus[iClient])
		RemoveMerasmus(iClient);
}

Action Command_BeMerasmus(int iClient, int iArgs)
{
	if (!iClient && iArgs < 1)
	{
		ReplyToCommand(iClient, "%t", "Command is in-game only");
		return Plugin_Handled;
	}

	if (iArgs < 1)
	{
		char sCmd[16];
		GetCmdArg(0, sCmd, sizeof(sCmd));
		ReplyToCommand(iClient, "[SM] Usage: %s <#userid|target> [health]", sCmd);
		return Plugin_Handled;
	}
		
	char sPattern[MAX_TARGET_LENGTH];
	GetCmdArg(1, sPattern, sizeof(sPattern));

	bool bTargetNameIsMultilingual;
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargetList[MAXPLAYERS], iTargetCount;
	if ((iTargetCount = ProcessTargetString(
			sPattern,
			iClient,
			iTargetList,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE | (StrEqual(sPattern, "@me") ? COMMAND_FILTER_NO_IMMUNITY : 0),
			sTargetName,
			sizeof(sTargetName),
			bTargetNameIsMultilingual)) <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);
		return Plugin_Handled;
	}

	int iHealth;
	if (iArgs > 1)
	{
		iHealth = GetCmdArgInt(2);
		if (iHealth < 1)
			iHealth = cvMaxHealth.IntValue;
	}
	else
		iHealth = cvMaxHealth.IntValue;
	
	for (int i; i < iTargetCount; i++)
		if (!g_bIsMerasmus[iTargetList[i]])
			CreateMerasmus(iTargetList[i], iHealth);

	if (bTargetNameIsMultilingual)
        ShowActivity2(iClient, "[SM] ", "%t", "Create Merasmus", sTargetName);
    else
        ShowActivity2(iClient, "[SM] ", "%t", "Create Merasmus", "_s", sTargetName);

	return Plugin_Handled;
}

/*
*	Merasmus Creation
*/

void CreateMerasmus(int iClient, int iHealth = 0)
{
	RemoveMerasmus(iClient);
	TF2_RemoveCondition(iClient, TFCond_Taunting);
	TF2_SetPlayerClass(iClient, TFClass_Sniper);
	TF2_RegeneratePlayer(iClient);
	TF2_RemoveAllItems(iClient);

	SetVariantInt(1);
	AcceptEntityInput(iClient, "SetForcedTauntCam");
	
	SetVariantString("2.0");
	AcceptEntityInput(iClient, "SetModelScale");

	SetVariantString(MERASMUS_PLAYER_MODEL);
	AcceptEntityInput(iClient, "SetCustomModelWithClassAnimations");
	
	GiveWizardWeapons(iClient, iHealth);

	if (GetGameTime() - g_flLastSndPlayTime[LastPlayed_Spawn] > 5.0)
	{
		EmitGameSoundToAll(SND_SPAWN);
		g_flLastSndPlayTime[LastPlayed_Spawn] = GetGameTime();
	}

	EmitGameSoundToAll(SND_FLOAT, iClient);
	EmitGameSoundToAll(SND_APPEAR, iClient);

	SDKHook(iClient, SDKHook_PostThinkPost, Hook_OnPostThinkPost);

	float flGameTime = GetGameTime();
	g_flNextHellfireTime[iClient] = flGameTime + cvHellfireCooldown.FloatValue;
	g_flNextAoETime[iClient] = flGameTime + cvAoECooldown.FloatValue;
	g_hHudTimer[iClient] = CreateTimer(0.1, Timer_Hud, GetClientSerial(iClient), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_hBombQueue[iClient] = new ArrayList(3);
	g_bIsMerasmus[iClient] = true;
}

void RemoveMerasmus(int iClient)
{
	if (!g_bIsMerasmus[iClient])
		return;
	
	SDKUnhook(iClient, SDKHook_PostThinkPost, Hook_OnPostThinkPost);

	g_bIsMerasmus[iClient] = false;
	EndAbility(iClient);
	delete g_hBombQueue[iClient];
	delete g_hHudTimer[iClient];

	int iEntity = EntRefToEntIndex(g_iStaffWorldModel[iClient]);
	if (iEntity != -1)
	{
		RemoveEntity(iEntity);
		g_iStaffWorldModel[iClient] = -1;
	}

	iEntity = EntRefToEntIndex(g_iBombWorldModel[iClient]);
	if (iEntity != -1)
	{
		RemoveEntity(iEntity);
		g_iBombWorldModel[iClient] = -1;
	}

	SetVariantInt(0);
	AcceptEntityInput(iClient, "SetForcedTauntCam");

	SetVariantString("1.0");
	AcceptEntityInput(iClient, "SetModelScale");

	SetVariantString("");
	AcceptEntityInput(iClient, "SetCustomModelWithClassAnimations");

	SetEntityInvis(iClient, false);

	if (IsPlayerAlive(iClient))
	{
		TF2_RemoveCondition(iClient, TFCond_Taunting);
		TF2_RemoveAllItems(iClient);
		TF2_RegeneratePlayer(iClient);
		SetEntProp(iClient, Prop_Send, "m_iHealth", GetMaxHealth(iClient));
	}
}

void GiveWizardWeapons(int iClient, int iHealth)
{
	int iStaff = CreateEntityByName("tf_weapon_club");
	SetEntProp(iStaff, Prop_Send, "m_bInitialized", true);
	SetEntProp(iStaff, Prop_Send, "m_bValidatedAttachedEntity", true);
	SetEntProp(iStaff, Prop_Send, "m_iItemDefinitionIndex", KUKRI);
	SetEntProp(iStaff, Prop_Send, "m_iEntityLevel", 100);
	SetEntProp(iStaff, Prop_Send, "m_bOnlyIterateItemViewAttributes", true);
	SetEntProp(iStaff, Prop_Send, "m_iAccountID", GetSteamAccountID(iClient, false));

	char sNetClass[32];
	GetEntityNetClass(iStaff, sNetClass, sizeof(sNetClass));
    SetEntData(iStaff, FindSendPropInfo(sNetClass, "m_iEntityQuality"), 5); // Unusual

	char sFormat[128];
	FormatEx(sFormat, sizeof(sFormat), "self.AddAttribute(\"max health additive bonus\", %i, -1)", iHealth - 125);
	RunScriptCode(iStaff, sFormat);

	static const float BASE_MELEE_DAMAGE = 65.0;
	float flDamageMult = cvMeleeDamage.FloatValue / BASE_MELEE_DAMAGE;
	Format(sFormat, sizeof(sFormat), "self.AddAttribute(\"damage bonus\", %f, -1)", flDamageMult);
	RunScriptCode(iStaff, sFormat);
	RunScriptCode(iStaff, "self.AddAttribute(\"fire rate penalty\", 1.65, -1)");
	RunScriptCode(iStaff, "self.AddAttribute(\"health from packs decreased\", 0.0, -1)");
	RunScriptCode(iStaff, "self.AddAttribute(\"health from healers reduced\", 0.0, -1)");
	RunScriptCode(iStaff, "self.AddAttribute(\"cancel falling damage\", 1.0, -1)");
	RunScriptCode(iStaff, "self.AddAttribute(\"cannot be backstabbed\", 1.0, -1)");
	RunScriptCode(iStaff, "self.AddAttribute(\"crit mod disabled\", 0.0, -1)");
	SetEntProp(iClient, Prop_Send, "m_iHealth", iHealth);
	DispatchSpawn(iStaff);
	EquipPlayerWeapon(iClient, iStaff);

	AddEffectFlags(iStaff, EF_NOSHADOW);
	SetEntityRenderMode(iStaff, RENDER_TRANSALPHA);
	SetEntityInvis(iStaff, true);

	SetVariantString("!activator");
    AcceptEntityInput(iStaff, "SetParent", iClient, iStaff);

	int iBomb = CreateEntityByName("tf_weapon_jar");
	SetEntProp(iBomb, Prop_Send, "m_bInitialized", true);
	SetEntProp(iBomb, Prop_Send, "m_bValidatedAttachedEntity", true);
	SetEntProp(iBomb, Prop_Send, "m_iItemDefinitionIndex", JARATE);
	SetEntProp(iBomb, Prop_Send, "m_iEntityLevel", 100);
	SetEntProp(iBomb, Prop_Send, "m_bOnlyIterateItemViewAttributes", true);
	SetEntProp(iBomb, Prop_Send, "m_iAccountID", GetSteamAccountID(iClient, false));

	GetEntityNetClass(iBomb, sNetClass, sizeof(sNetClass));
    SetEntData(iBomb, FindSendPropInfo(sNetClass, "m_iEntityQuality"), 5); // Unusual

	// Change the projectile to a grenade because jarate explodes instantly if someone is stuck within us or we're in a wall
	RunScriptCode(iBomb, "self.AddAttribute(\"override projectile type\", 5.0, -1)");
	RunScriptCode(iBomb, "self.AddAttribute(\"crit mod disabled\", 0.0, -1)");	

	DispatchSpawn(iBomb);
	EquipPlayerWeapon(iClient, iBomb);
	
	SetEntityRenderMode(iBomb, RENDER_TRANSALPHA);
	SetEntityInvis(iBomb, true);
	AddEffectFlags(iBomb, EF_NOSHADOW);
	
	SetVariantString("!activator");
    AcceptEntityInput(iBomb, "SetParent", iClient, iBomb);

	SetEntPropEnt(iClient, Prop_Data, "m_hActiveWeapon", iStaff);
	RequestFrame(NextFrame_CreateWeaponWorldModels, GetClientSerial(iClient));
}

void NextFrame_CreateWeaponWorldModels(int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!iClient || !g_bIsMerasmus[iClient])
		return;
	
	g_iStaffWorldModel[iClient] = EntIndexToEntRef(CreateClientWorldModel(iClient, MERASMUS_STAFF));
	g_iBombWorldModel[iClient] = EntIndexToEntRef(CreateClientWorldModel(iClient, HELD_BOMB_MODEL));
}

/*
*	Events
*/

Action Event_OnArrowImpact(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	// Block arrows from getting stuck in Merasmus so when the player is made invis
	// during an ability animation, you won't see arrows sticking out of them
	int iClient = hEvent.GetInt("attachedEntity");
	if (IsEntityClient(iClient) && g_bIsMerasmus[iClient])
		hEvent.BroadcastDisabled = true;

	return Plugin_Continue;
}

void Event_OnPlayerChangeTeam(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if (hEvent.GetInt("disconnect"))
		return;
	
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if (g_bIsMerasmus[iClient])
		RemoveMerasmus(iClient);
}

void Event_OnPlayerResupply(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if (g_bIsMerasmus[iClient])
		RemoveMerasmus(iClient);
}

Action Event_OnPlayerDeathPre(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if (hEvent.GetInt("attacker") != 0)
	{
		int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));
		if (g_bIsMerasmus[iAttacker] && hEvent.GetInt("damagebits") & DMG_CLUB)
		{
			hEvent.SetInt("customkill", TF_CUSTOM_MERASMUS_DECAPITATION);
			hEvent.SetString("weapon", "merasmus_decap");
			return Plugin_Changed;
		}
	}

	if (hEvent.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)
		return Plugin_Continue;

	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if (!g_bIsMerasmus[iClient])
		return Plugin_Continue;

	PlayAnimation(iClient, "death");

	if (GetGameTime() - g_flLastSndPlayTime[LastPlayed_Death] > 5.0)
	{
		EmitGameSoundToAll(SND_DEATH);
		g_flLastSndPlayTime[LastPlayed_Death] = GetGameTime();
	}
	
	EmitGameSoundToAll(SND_BANISH, iClient);
	EmitGameSoundToAll(SND_SPAWN, _, SND_STOP);

	RequestFrame(NextFrame_MerasmusDeath, GetClientSerial(iClient));

	return Plugin_Continue;
}

void Event_OnPlayerDeathPost(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if (!g_bIsMerasmus[iClient])
		return;
	
	for (int iEnt; (iEnt = FindEntityByClassname(iEnt, "tf_dropped_weapon")) != -1;)
	{
		int iAccountID = GetSteamAccountID(iClient, false);
		if (iAccountID == GetEntProp(iEnt, Prop_Send, "m_iAccountID"))
			RemoveEntity(iEnt);
	}

	if (!cvDropAmmo.BoolValue)
	{
		for (int iEnt; (iEnt = FindEntityByClassname(iEnt, "tf_ammo_pack")) != -1;)
		{
			int iOwner = GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity");
			if (IsEntityClient(iOwner))
			{
				RemoveEntity(iEnt);
				break;
			}
		}
	}
}

void NextFrame_MerasmusDeath(int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (iClient)
		RemoveMerasmus(iClient);
	
	int iRagdoll = GetEntPropEnt(iClient, Prop_Send, "m_hRagdoll");
	if (iRagdoll != -1)
		SetEdictFlags(iRagdoll, FL_EDICT_DONTSEND);
}

void Event_OnRoundStart(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	g_iLastWinningTeam = -1;
}

void Event_OnRoundEnd(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	g_iLastWinningTeam = hEvent.GetInt("team");
}

/*
*	Hooks
*/

public void OnEntityCreated(int iEntity, const char[] sName)
{
	if (StrEqual(sName, "tf_projectile_syringe"))
		RequestFrame(NextFrame_KillJarateProjectile, EntIndexToEntRef(iEntity));
	else if (StrEqual(sName, "instanced_scripted_scene"))
		RequestFrame(NextFrame_OnSceneCreated, EntIndexToEntRef(iEntity));
}

void NextFrame_OnSceneCreated(int iRef)
{
	int iEntity = EntRefToEntIndex(iRef);
	if (iEntity == -1)
		return;
	
	int iOwner = GetEntPropEnt(iEntity, Prop_Data, "m_hOwner");
	if (!IsEntityClient(iOwner) || !g_bIsMerasmus[iOwner])
		return;
	
	char sScene[39];
	GetEntPropString(iEntity, Prop_Data, "m_iszSceneFile", sScene, sizeof(sScene));
	if (StrEqual(sScene, "scenes/bot/merasmus/low/bomb_attack_00", false))
		g_iSceneFile[iOwner] = EntIndexToEntRef(iEntity);
}

void NextFrame_KillJarateProjectile(int iRef)
{
	int iEntity = EntRefToEntIndex(iRef);
	if (iEntity == -1)
		return;
	
	int iOwner = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	if (iOwner != -1 && IsEntityClient(iOwner) && g_bIsMerasmus[iOwner])
	{
		float vOrigin[3];
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vOrigin);
		ThrowGrenade(iOwner, vOrigin);
		RemoveEntity(iEntity);
	}
}

public Action TF2_CalcIsAttackCritical(int iClient, int iWeapon, char[] sWeaponName, bool& bResult)
{
	if (!g_bIsMerasmus[iClient])
		return Plugin_Continue;
	
	int iMelee = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
	if (iMelee != -1 && iMelee == iWeapon)
	{
		// Directly from the source code
		if (GetRandomInt(0, 2) != 0)
			return Plugin_Continue;
		
		EmitGameSoundToAll(GetRandomInt(1, 5) == 1 ? SND_STAFF_ATTACK_RARE : SND_STAFF_ATTACK);
		return Plugin_Continue;
	}
	
	int iSecondary = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Secondary);
	if (iSecondary != -1 && iSecondary == iWeapon)
		SetEntPropFloat(iWeapon, Prop_Send, "m_flEffectBarRegenTime", GetGameTime() + 20.1);
	
	return Plugin_Continue;
}

Action SoundHook_Merasmus(int iClients[MAXPLAYERS], int &iNumClients, char sSample[PLATFORM_MAX_PATH], int &iEntity, int &iChannel, float &iVolume, int &iLevel, int &iPitch, int &iFlags, char sSoundEntry[256], int &iSeed)
{
	if (!IsEntityClient(iEntity) || !g_bIsMerasmus[iEntity]) 
		return Plugin_Continue;

	if (strncmp(sSample, "player/footsteps/", 17, false) == 0)
		return Plugin_Handled;

	if (strncmp(sSample, "vo/sniper", 9, false) != 0 && strncmp(sSample, "vo\\sniper", 9, false) != 0 
		&& strncmp(sSample, "vo/taunts/sniper", 16, false) != 0 && strncmp(sSample, "vo\\taunts\\sniper", 16, false) != 0)
		return Plugin_Continue;

	if (strncmp(sSample[10], "pain", 4, false) == 0)
		return Plugin_Handled;
	
	if (StrContains(sSample, "laugh", false) > -1)
	{
		Format(sSample, sizeof(sSample), g_sLaughSnd[GetRandomInt(0, sizeof(g_sLaughSnd) - 1)]);
		return Plugin_Changed;
	}

	return Plugin_Handled;
}

void Hook_OnPostThinkPost(int iClient)
{
	if (!g_bIsMerasmus[iClient])
		return;
	
	int iActiveWep = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	int iSecondary = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Secondary);
	int iMelee = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
	float flGameTime = GetGameTime();

	if (iSecondary != -1)
	{
		float flRegenTime = GetEntPropFloat(iSecondary, Prop_Send, "m_flEffectBarRegenTime");
		if (flGameTime < flRegenTime)
		{	
			// Bomb recharges in 5 seconds
			SetEntPropFloat(iSecondary, Prop_Send, "m_flEffectBarRegenTime", flRegenTime - (GetTickInterval() * 3.0));
		}
	}
	
	bool bControlStunned = IsControlStunned(iClient);
	if (bControlStunned && (g_bInHellfireAttack[iClient] || g_bInAoEAttack[iClient]))
		EndAbility(iClient);
	else if (g_bInAnimation[iClient])
	{
		if (EntRefToEntIndex(g_iStaffWorldModel[iClient]) != -1)
			AddEffectFlags(g_iStaffWorldModel[iClient], EF_NODRAW);
		
		if (EntRefToEntIndex(g_iBombWorldModel[iClient]) != -1)
			AddEffectFlags(g_iBombWorldModel[iClient], EF_NODRAW);

		float vPos[3], vAng[3];
		GetClientAbsOrigin(iClient, vPos);
		GetClientAbsAngles(iClient, vAng);
		
		if (EntRefToEntIndex(g_iAnimProp[iClient]) != -1)
		{
			SetEntPropVector(g_iAnimProp[iClient], Prop_Send, "m_vecOrigin", vPos);
			SetEntPropVector(g_iAnimProp[iClient], Prop_Send, "m_angRotation", vAng);
			SetEntPropFloat(g_iAnimProp[iClient], Prop_Data, "m_flSimulationTime", flGameTime);
		}

		if (g_bInAoEAttack[iClient] && !g_hAbilityTimer[iClient])
		{
			if (g_flNextBombAttack[iClient] < flGameTime)
			{
				g_flNextBombAttack[iClient] = flGameTime + 2.0;
				if (GetRandomInt(0, 1))
					QueueBombRingsForLaunch(iClient);
				else
					QueueBombSpokesForLaunch(iClient);
			}
			
			if (g_hBombQueue[iClient].Length && g_flNextBombSpawnTick[iClient] < flGameTime)
			{
				float vEnd[3], vVel[3];
				GetClientEyePosition(iClient, vPos);

				// The source code doesn't do a trace because Merasmus is supposed to use this on Lakeside mid, 
				// so let's make sure the bombs don't spawn in the ceiling
				vEnd = vPos;
				vEnd[2] += BOMB_START_OFFSET_Z + (BOMB_HALF_HEIGHT); // Add the bomb height ...
				TR_TraceRayFilter(vPos, vEnd, MASK_PLAYERSOLID_BRUSHONLY, RayType_EndPoint, TraceFilter_IgnoreEntities);
				TR_GetEndPosition(vEnd);

				// ... then move it down so bombs don't spawn in a brush
				if (TR_DidHit())
					vEnd[2] -= BOMB_HALF_HEIGHT * 2.0;
				else
					vEnd[2] -= BOMB_HALF_HEIGHT;

				int iGrenadeDamage = cvAoEDamage.IntValue;
				float flGrenadeRadius = cvAoERadius.FloatValue;
				int iNumGrenades = IntMin(g_hBombQueue[iClient].Length, MAX_BOMBS_PER_TICK);
				while (iNumGrenades)
				{
					g_hBombQueue[iClient].GetArray(0, vVel, sizeof(vVel));
					g_hBombQueue[iClient].Erase(0);
					CreateMerasmusGrenade(vEnd, vVel, iClient, iGrenadeDamage, flGrenadeRadius, false);
					--iNumGrenades;
				}

				g_flNextBombSpawnTick[iClient] = flGameTime + 0.1;
			}
		}

		return;
	}

	bool bTaunting = TF2_IsPlayerInCondition(iClient, TFCond_Taunting);
	bool bIsOnLosingTeam = IsOnLosingTeam(iClient);
	if (!bTaunting && iActiveWep != -1 && !bIsOnLosingTeam)
	{
		float flNextPrimaryAttack = GetEntPropFloat(iActiveWep, Prop_Send, "m_flNextPrimaryAttack");
		if (flNextPrimaryAttack < flGameTime)
		{
			int iButtons = GetEntProp(iClient, Prop_Data, "m_nButtons");
			if (iButtons & IN_ATTACK2 && g_flNextHellfireTime[iClient] < flGameTime && GetEntProp(iClient, Prop_Send, "m_hGroundEntity") != -1)
			{
				static const float HELLFIRE_ANIM_TIME = 3.0;
				if (iMelee != -1)
					SetEntPropFloat(iMelee, Prop_Send, "m_flNextPrimaryAttack", flGameTime + HELLFIRE_ANIM_TIME);
				
				if (iSecondary != -1)
					SetEntPropFloat(iSecondary, Prop_Send, "m_flNextPrimaryAttack", flGameTime + HELLFIRE_ANIM_TIME);
				
				HellfireAttack(iClient);
				return;
			}
			else if (iButtons & IN_RELOAD && g_flNextAoETime[iClient] < flGameTime)
			{
				static const float AOE_ANIM_TIME = 15.0;
				if (iMelee != -1)
					SetEntPropFloat(iMelee, Prop_Send, "m_flNextPrimaryAttack", flGameTime + AOE_ANIM_TIME);
				
				if (iSecondary != -1)
					SetEntPropFloat(iSecondary, Prop_Send, "m_flNextPrimaryAttack", flGameTime + AOE_ANIM_TIME);

				AoEAttack(iClient);
			}
		}
	}

	int iWorldModel = -1;
	if (iSecondary != -1 && iSecondary == iActiveWep)
	{
		if (EntRefToEntIndex(g_iBombWorldModel[iClient]) != -1)
			iWorldModel = g_iBombWorldModel[iClient];
		
		if (EntRefToEntIndex(g_iStaffWorldModel[iClient]) != -1)
			AddEffectFlags(g_iStaffWorldModel[iClient], EF_NODRAW);
	}
	else if (iMelee != -1 && iMelee == iActiveWep)
	{
		if (EntRefToEntIndex(g_iStaffWorldModel[iClient]) != -1)
			iWorldModel = g_iStaffWorldModel[iClient];
		
		if (EntRefToEntIndex(g_iBombWorldModel[iClient]) != -1)
			AddEffectFlags(g_iBombWorldModel[iClient], EF_NODRAW);
	}
	else
	{
		if (iSecondary != -1)
			SetEntityInvis(iSecondary, true);
		
		if (iMelee != -1)
			SetEntityInvis(iMelee, true);

		if (EntRefToEntIndex(g_iBombWorldModel[iClient]) != -1)
			AddEffectFlags(g_iBombWorldModel[iClient], EF_NODRAW);
		
		if (EntRefToEntIndex(g_iStaffWorldModel[iClient]) != -1)
			AddEffectFlags(g_iStaffWorldModel[iClient], EF_NODRAW);
		return;
	}

	if (bControlStunned || bIsOnLosingTeam)
		AddEffectFlags(iWorldModel, EF_NODRAW);
	else if (bTaunting) 
	{
		int iTauntIndex = GetEntProp(iClient, Prop_Send, "m_iTauntItemDefIndex");
		switch (GetTauntWeaponState(iTauntIndex))
		{
			case Taunt_None: 
			{
				SetEntityInvis(iActiveWep, true);
				if (iWorldModel != -1)
					AddEffectFlags(iWorldModel, EF_NODRAW);
			}
			case Taunt_Repurpose: 
			{
				SetEntityInvis(iActiveWep, false);
				if (iWorldModel != -1)
					AddEffectFlags(iWorldModel, EF_NODRAW);
			}
			case Taunt_UsesWeapon:
			{
				SetEntityInvis(iActiveWep, true);
				if (iWorldModel != -1)
					RemoveEffectFlags(iWorldModel, EF_NODRAW);
			}
		}
	}
	else
	{
		SetEntityInvis(iActiveWep, true);
		if (iWorldModel != -1)
			RemoveEffectFlags(iWorldModel, EF_NODRAW);
	}
}

Action Hook_OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &flDamage, int &iDamageType, int &iWeapon, float flDamageForce[3], float flDamagePosition[3], int iDamageCustom)
{
	int iGrenade = EntRefToEntIndex(g_hBombs.Get(iInflictor));
	if (iGrenade != -1)
	{
		if (GetEntProp(iInflictor, Prop_Send, "m_iTeamNum") == GetClientTeam(iVictim))
		{
			flDamage = 0.0;
			return Plugin_Changed;
		}

		iGrenade = EntRefToEntIndex(g_hCritBoostedGrenades.Get(iInflictor));
		if (iGrenade != -1)
		{
			iDamageType |= DMG_CRIT;
			return Plugin_Changed;
		}

		return Plugin_Continue;
	}
	
	if (IsEntityClient(iAttacker) && g_bIsMerasmus[iAttacker])
	{
		// This is the damage the attacker dealt below
		if (iDamageCustom == TF_CUSTOM_MERASMUS_DECAPITATION)
			return Plugin_Continue;
		
		int iMelee = GetPlayerWeaponSlot(iAttacker, TFWeaponSlot_Melee);
		if (iMelee != -1 && iMelee == iWeapon)
		{
			char sScript[1024];
			Format(sScript, sizeof(sScript), 
			"::meras <- EntIndexToHScript(%i), " ...
			"self.TakeDamageCustom(meras, meras, %i, Vector(0,0,0), Vector(0,0,0), %f, Constants.FDmgType.DMG_CLUB | %i, Constants.ETFDmgCustom.TF_DMG_CUSTOM_MERASMUS_DECAPITATION)",
			iAttacker, iMelee, flDamage, iDamageType & DMG_CRIT ? DMG_CRIT : 0);
			RunScriptCode(iVictim, sScript);

			float vOrigin[3], vOtherEyePos[3], vVel[3];
			GetClientAbsOrigin(iAttacker, vOrigin);
			GetClientEyePosition(iVictim, vOtherEyePos);
			SubtractVectors(vOtherEyePos, vOrigin, vVel);
			vVel[2] = 0.0;
			NormalizeVector(vVel, vVel);
			vVel[2] = 1.0;
			ScaleVector(vVel, 500.0);

			float vCurrVel[3];
			GetEntPropVector(iVictim, Prop_Data, "m_vecAbsVelocity", vCurrVel);
			AddVectors(vCurrVel, vVel, vVel);
			SetEntPropVector(iVictim, Prop_Data, "m_vecAbsVelocity", vVel);

			flDamage = 0.0;
			EmitGameSoundToAll(SND_STAFF_HIT, iAttacker);
			
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

/*
*	Abilities
*/

void HellfireAttack(int iClient)
{
	g_bInHellfireAttack[iClient] = true;
	PlayAnimation(iClient, "zap_attack");
	EmitGameSoundToAll(GetRandomInt(0, 1) ? SND_LAUNCHSPELL : SND_FIRESPELL);
	g_hAbilityTimer[iClient] = CreateTimer(1.3, Timer_HellfireAttack, GetClientSerial(iClient), TIMER_FLAG_NO_MAPCHANGE);
}

void Timer_HellfireAttack(Handle hTimer, int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!iClient || !g_bIsMerasmus[iClient] || !g_bInHellfireAttack[iClient])
		return;
	
	g_hAbilityTimer[iClient] = INVALID_HANDLE;

	bool bIgnite = cvHellfireIgnite.BoolValue;
	float flDist, flRange = 600.0 * 600.0, flMinDamage = cvHellfireDamageMin.FloatValue, flMaxDamage = cvHellfireDamageMax.FloatValue;
	int iTeam = GetClientTeam(iClient);
	int iMelee = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
	float vOrigin[3], vOtherDeltaPos[3], vEyePos[3], vOtherCenter[3];
	GetClientAbsOrigin(iClient, vOrigin);
	GetClientEyePosition(iClient, vEyePos);
	
	ArrayList hTargets = new ArrayList();
	
	// Collect targets
	for (int i = MaxClients; i; i--)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) == iTeam)
			continue;

		GetClientAbsOrigin(i, vOtherDeltaPos);
		flDist = GetVectorDistance(vOrigin, vOtherDeltaPos, true);
		if (flDist >= flRange)
			continue;
		
		// Trace from head to toe
		GetClientEyePosition(i, vOtherDeltaPos);
		TR_TraceRayFilter(vEyePos, vOtherDeltaPos, MASK_OPAQUE | CONTENTS_IGNORE_NODRAW_OPAQUE, RayType_EndPoint, TraceFilter_IgnoreEntities);
		if (TR_GetFraction() != 1.0)
		{
			GetClientCenter(i, vOtherDeltaPos);
			TR_TraceRayFilter(vEyePos, vOtherCenter, MASK_OPAQUE | CONTENTS_IGNORE_NODRAW_OPAQUE, RayType_EndPoint, TraceFilter_IgnoreEntities);
			if (TR_GetFraction() != 1.0)
			{
				GetClientAbsOrigin(i, vOtherDeltaPos);
				TR_TraceRayFilter(vEyePos, vOtherDeltaPos, MASK_OPAQUE | CONTENTS_IGNORE_NODRAW_OPAQUE, RayType_EndPoint, TraceFilter_IgnoreEntities);
				if (TR_GetFraction() != 1.0)
					continue;
			}
		}
		
		hTargets.Push(i);
	}

	// Limit our player targets to the max
	int iMaxTargets = 6;
	if (hTargets.Length > iMaxTargets)
		while (hTargets.Length && hTargets.Length != iMaxTargets)
			hTargets.Erase(GetRandomInt(0, hTargets.Length - 1));
	
	// Find all enemy sentries in range, there's no limit
	int iSentry = -1;
	while ((iSentry = FindEntityByClassname(iSentry, "obj_sentrygun")) != -1)
	{
		if (GetEntProp(iSentry, Prop_Send, "m_iTeamNum") == iTeam)
			continue;
		
		GetEntityCenter(iSentry, vOtherDeltaPos);
		if (GetVectorDistance(vEyePos, vOtherCenter) < flRange)
			hTargets.Push(iSentry);
	}

	if (hTargets.Length == 0)
	{
		delete hTargets;
		return;
	}

	char sScript[512];
	int iTarget, iDamage, iLength = hTargets.Length;
	float flTickInterval = GetTickInterval();
	for (int i; i < iLength; i++)
	{
		iTarget = hTargets.Get(i);
		if (IsEntityClient(iTarget))
		{
			if (bIgnite)
				TF2_IgnitePlayer(iTarget, iClient, 5.0);

			float vVel[3];
			GetEntPropVector(iTarget, Prop_Data, "m_vecAbsVelocity", vVel);
			AddVectors(vVel, { 0.0, 0.0, 1000.0 }, vVel);
			SetEntPropVector(iTarget, Prop_Data, "m_vecAbsVelocity", vVel);

			float flHalfMaxRangeSqr = 600.0 * 0.5;
			flHalfMaxRangeSqr *= flHalfMaxRangeSqr;
			GetClientCenter(iTarget, vOtherDeltaPos);
			float flDistSqr = GetVectorDistance(vEyePos, vOtherDeltaPos, true);
			iDamage = RoundToNearest(RemapValClamped(flDistSqr, 100.0, flHalfMaxRangeSqr, flMaxDamage, flMinDamage));

			GetClientEyePosition(iTarget, vOtherDeltaPos);
		}
		else
		{
			GetEntityCenter(iTarget, vOtherDeltaPos);
			iDamage = GetEntProp(iTarget, Prop_Send, "m_iHealth");
		}

		Format(sScript, sizeof(sScript), 
			"::meras <- EntIndexToHScript(%i), " ...
			"self.TakeDamageCustom(meras, meras, %i, Vector(0,0,0), Vector(0,0,0), %i, Constants.FDmgType.DMG_BURN, Constants.ETFDmgCustom.TF_DMG_CUSTOM_MERASMUS_ZAP)",
			iClient, iMelee, iDamage);
		RunScriptCode(iTarget, sScript);

		float vAttachStart[3], vAttachAngles[3];
		if (EntRefToEntIndex(g_iAnimProp[iClient]) != -1)
		{
			GetEntityAttachment(g_iAnimProp[iClient], LookupEntityAttachment(g_iAnimProp[iClient], "effect_staff"), vAttachStart, vAttachAngles);
			TE_SetupTFParticleEffect(g_iZapParticle, vAttachStart, vAttachStart, vAttachAngles, g_iAnimProp[iClient], PATTACH_CUSTOMORIGIN, _, 1, PATTACH_ABSORIGIN, vOtherDeltaPos);
			TE_SendToAll(i * flTickInterval); // Delay them by a tick each otherwise they'll all attach to a single target
		}
	}

	EmitGameSoundToAll(SND_SPELL, iClient);

	delete hTargets;
}

bool TraceFilter_IgnoreEntities(int iEntity, int iContentsMask)
{
	return false;
}

void AoEAttack(int iClient)
{
	g_bInAoEAttack[iClient] = true;
	PlayAnimation(iClient, "bomb_attack");
	g_hAbilityTimer[iClient] = CreateTimer(4.0, Timer_StartAoEAttack, GetClientSerial(iClient), TIMER_FLAG_NO_MAPCHANGE);

	char sScript[256];
	FormatEx(sScript, sizeof(sScript), "self.PlayScene(\"scenes/bot/merasmus/low/bomb_attack_00%i.vcd\", 0.0)", GetRandomInt(1, 9));
	RunScriptCode(iClient, sScript);
}

void Timer_StartAoEAttack(Handle hTimer, int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!iClient || !g_bIsMerasmus[iClient] || !g_bInAoEAttack[iClient])
		return;
	
	g_hAbilityTimer[iClient] = INVALID_HANDLE;
	SetEntityMoveType(iClient, MOVETYPE_WALK);
	TF2_AddCondition(iClient, TFCond_SwimmingNoEffects);

	if (EntRefToEntIndex(g_iAnimProp[iClient]) != -1)
	{
		int iParticle = CreateEntityByName("info_particle_system");
		DispatchKeyValue(iParticle, "effect_name", "merasmus_book_attack");

		SetVariantString("!activator");
		AcceptEntityInput(iParticle, "SetParent", g_iAnimProp[iClient]);

		SetVariantString("effect_hand_R");
		AcceptEntityInput(iParticle, "SetParentAttachment", g_iAnimProp[iClient]);

		DispatchSpawn(iParticle);
		ActivateEntity(iParticle);
		AcceptEntityInput(iParticle, "Start");
		g_iAoEParticle[iClient] = EntIndexToEntRef(iParticle);
	}

	g_flNextBombAttack[iClient] = GetGameTime() + 1.0;
}

void QueueBombRingsForLaunch(int iClient)
{
	float flBombRingMinHorizontalVel = 100.0;
	float flBombRingMaxHorizontalVel = 2000.0;

	float vAng[3], vFwd[3], vVel[3];
	GetClientEyeAngles(iClient, vAng);
	vAng[0] = 0.0;
	vAng[2] = 0.0;

	float flDeltaVel = flBombRingMaxHorizontalVel - flBombRingMinHorizontalVel;
	int iRingCount = 2;
	for (int r; r < iRingCount; r++)
	{
		float u = float(r + 1)/float(iRingCount);
		float flHorizontalVel = flBombRingMinHorizontalVel + u * flDeltaVel;
		float flDeltaAngle = 20.0 + 30.0 * (1.0 - u);

		for (float flAngle; flAngle < 360.0; flAngle += flDeltaAngle)
		{
			GetAngleVectors(vAng, vFwd, NULL_VECTOR, NULL_VECTOR);
			vVel[0] = flHorizontalVel * vFwd[0];
			vVel[1] = flHorizontalVel * vFwd[1];
			vVel[2] = BOMB_VERT_VEL;
			g_hBombQueue[iClient].PushArray(vVel, sizeof(vVel));
			vAng[1] += flDeltaAngle;
		}
	}
}

void QueueBombSpokesForLaunch(int iClient)
{
	float flBombSpokeAngle = 45.0;
	int iBombSpokeCount = 4;
	float flBombSpokeMinHorizontalVel = 100.0;
	float flBombSpokeMaxHorizontalVel = 2000.0;

	float flDeltaVel = flBombSpokeMaxHorizontalVel - flBombSpokeMinHorizontalVel;
	float flDeltaAngle = flBombSpokeAngle;

	float vAng[3], vFwd[3], vVel[3];
	GetClientEyeAngles(iClient, vAng);
	vAng[0] = 0.0;
	vAng[2] = 0.0;

	for (float flAngle; flAngle < 360.0; flAngle += flDeltaAngle)
	{
		GetAngleVectors(vAng, vFwd, NULL_VECTOR, NULL_VECTOR);

		int iSpokeCount = iBombSpokeCount;

		for (int i; i < iSpokeCount; i++)
		{
			float u = float(i + 1)/float(iSpokeCount);
			float flHorizontalVel = flBombSpokeMinHorizontalVel + u * flDeltaVel;
			vVel[0] = flHorizontalVel * vFwd[0];
			vVel[1] = flHorizontalVel * vFwd[1];
			vVel[2] = BOMB_VERT_VEL;
			g_hBombQueue[iClient].PushArray(vVel, sizeof(vVel));
		}

		vAng[1] += flDeltaAngle;
	}
}

void ThrowGrenade(int iClient, float vPos[3])
{
	float vEyeAng[3], vFwd[3], vRight[3], vUp[3], vVel[3];
	GetClientEyeAngles(iClient, vEyeAng);
	GetAngleVectors(vEyeAng, vFwd, NULL_VECTOR, NULL_VECTOR);
	float flLaunchSpeed = GetRandomFloat(1500.0, 2000.0);
	ScaleVector(vFwd, flLaunchSpeed);
	ScaleVector(vRight, GetRandomFloat(-10.0, 10.0));
	ScaleVector(vUp, 200.0);
	ScaleVector(vUp, GetRandomFloat(-10.0, 10.0));
	AddVectors(vFwd, vRight, vVel);
	AddVectors(vVel, vUp, vVel);
	CreateMerasmusGrenade(vPos, vVel, iClient, cvGrenadeDamage.IntValue, cvGrenadeRadius.FloatValue, TF2_IsCritBoosted(iClient));

	// Source code says 1/7 but that's too rare for my liking. Make it 1/3 like the staff
	if (GetRandomInt(0, 2) == 0)
		EmitGameSoundToAll(GetRandomInt(1, 10) == 1 ? SND_GRENADE_THROW_RARE : SND_GRENADE_THROW);
}

void PlayAnimation(int iClient, char[] sAnim)
{
	float vOrigin[3], vAngles[3];
	GetClientAbsOrigin(iClient, vOrigin);
	GetClientAbsAngles(iClient, vAngles);
	vAngles[0] = 0.0;

	int iAnimEntity = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValueVector(iAnimEntity, "origin", vOrigin);
	DispatchKeyValueVector(iAnimEntity, "angles", vAngles);
	DispatchKeyValue(iAnimEntity, "model", MERASMUS_NPC_MODEL);
	DispatchKeyValue(iAnimEntity, "defaultanim", sAnim);
	DispatchSpawn(iAnimEntity);
	SetEntPropEnt(iAnimEntity, Prop_Send, "m_hOwnerEntity", iClient);

	if (EntRefToEntIndex(g_iStaffWorldModel[iClient]) != -1)
		AddEffectFlags(g_iStaffWorldModel[iClient], EF_NODRAW);

	if (strcmp(sAnim, "death") == 0)
	{
		SetVariantString("OnAnimationDone !self:KillHierarchy::0.0:1");
		AcceptEntityInput(iAnimEntity, "AddOutput", _, iAnimEntity);
		HookSingleEntityOutput(iAnimEntity, "OnAnimationDone", OnDeathDone, true);
		
		// End it a bit early just like the merasmus npc
		// FireEntityOutput ignores the delay and fires instantly so sp timer it is
		CreateTimer(5.0, Timer_OnAnimationDone, EntIndexToEntRef(iAnimEntity), TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		SetVariantString("OnAnimationDone !self:KillHierarchy::0.0:1");
		AcceptEntityInput(iAnimEntity, "AddOutput", _, iAnimEntity);
		HookSingleEntityOutput(iAnimEntity, "OnAnimationDone", OnAnimationDone, true);

		TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, { 0.0, 0.0, 0.0 });
		SetEntityMoveType(iClient, MOVETYPE_NONE);
		SetEntityRenderMode(iClient, RENDER_TRANSCOLOR);
		SetEntityRenderColor(iClient, 255, 255, 255, 0);

		g_iAnimProp[iClient] = EntIndexToEntRef(iAnimEntity);
		g_bInAnimation[iClient] = true;
	}
}

void Timer_OnAnimationDone(Handle hTimer, int iRef)
{
	int iAnimEntity = EntRefToEntIndex(iRef);
	if (iAnimEntity != -1)
		FireEntityOutput(iAnimEntity, "OnAnimationDone");
}

void OnAnimationDone(const char[] sOutput, int iCaller, int iActivator, float flDelay)
{	
	int iClient = GetEntPropEnt(iCaller, Prop_Send, "m_hOwnerEntity");
	if (!IsEntityClient(iClient) || !g_bIsMerasmus[iClient] || !IsPlayerAlive(iClient))
		return;
	
	EndAbility(iClient);
}

void OnDeathDone(const char[] sOutput, int iCaller, int iActivator, float flDelay)
{
	float vOrigin[3];
	GetEntPropVector(iCaller, Prop_Send, "m_vecOrigin", vOrigin);
	TE_SetupTFParticleEffect(g_iSpawnParticle, vOrigin);
	TE_SendToAll();
}

void EndAbility(int iClient)
{
	SetEntityMoveType(iClient, MOVETYPE_WALK);
	SetEntityRenderMode(iClient, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iClient, 255, 255, 255, 255);

	int iMelee = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
	if (iMelee != -1)
		SetEntPropFloat(iMelee, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.5);

	if (EntRefToEntIndex(g_iStaffWorldModel[iClient]) != -1)
		RemoveEffectFlags(g_iStaffWorldModel[iClient], EF_NODRAW);
	
	if (EntRefToEntIndex(g_iAnimProp[iClient]) != -1)
	{
		RemoveEntity(g_iAnimProp[iClient]);
		g_iAnimProp[iClient] = -1;
	}
	
	if (EntRefToEntIndex(g_iSceneFile[iClient]) != -1)
	{
		RemoveEntity(g_iSceneFile[iClient]);
		g_iSceneFile[iClient] = -1;
	}

	if (g_bInHellfireAttack[iClient])
		g_flNextHellfireTime[iClient] = GetGameTime() + cvHellfireCooldown.FloatValue;
	
	if (g_bInAoEAttack[iClient])
	{
		if (EntRefToEntIndex(g_iAoEParticle[iClient]) != -1)
		{
			RemoveEntity(g_iAoEParticle[iClient]);
			g_iAoEParticle[iClient] = -1;
		}

		TF2_RemoveCondition(iClient, TFCond_SwimmingNoEffects);
		g_flNextAoETime[iClient] = GetGameTime() + cvAoECooldown.FloatValue;
	}

	g_bInAnimation[iClient] = false;
	g_bInAoEAttack[iClient] = false;
	g_bInHellfireAttack[iClient] = false;
	delete g_hAbilityTimer[iClient];
}

Action Timer_Hud(Handle hTimer, int iSerial)
{
	int iClient = GetClientFromSerial(iSerial);
	if (!iClient)
		return Plugin_Stop;
	
	if (GetClientButtons(iClient) & IN_SCORE || IsOnLosingTeam(iClient))
		return Plugin_Continue;

	SetHudTextParams(-1.0, 0.75, 0.35, 0, 255, 0, 255, 0, 0.0, 0.0, 0.1);

	char sMsg[64];
	float flCooldown = g_flNextHellfireTime[iClient] - GetGameTime();
	if (g_bInHellfireAttack[iClient])
		Format(sMsg, sizeof(sMsg), "%t: %t", "Hellfire", "Active");
	else if (flCooldown > 0.0)
		Format(sMsg, sizeof(sMsg), "%t: %.1fs", "Hellfire", flCooldown);
	else
		Format(sMsg, sizeof(sMsg), "%t: %t (MOUSE2)", "Hellfire", "Ready!");

	flCooldown = g_flNextAoETime[iClient] - GetGameTime();
	if (g_bInAoEAttack[iClient])
		Format(sMsg, sizeof(sMsg), "%s\n%t: %t", sMsg, "Bombinomicon", "Active");
	else if (flCooldown > 0.0)
		Format(sMsg, sizeof(sMsg), "%s\n%t: %.1fs", sMsg, "Bombinomicon", flCooldown);
	else
		Format(sMsg, sizeof(sMsg), "%s\n%t: %t (RELOAD)", sMsg, "Bombinomicon", "Ready!");
	
	ShowSyncHudText(iClient, g_hHudSyncronizer, sMsg);
	return Plugin_Continue;
}

/*
*	Utility
*/

int GetMaxHealth(int iClient)
{
	return SDKCall(g_hSDKCall_GetMaxHealth, iClient);
}

bool IsOnLosingTeam(int iClient)
{
	return g_iLastWinningTeam != -1 && g_iLastWinningTeam != GetClientTeam(iClient);
}

// This determines which taunts should hide the tf_wearable world model. Covers every taunt up until Halloween 2026.
int GetTauntWeaponState(int iTauntIndex)
{
	switch (iTauntIndex)
	{
		case 167, 438, 463, 1106, 1107, 1110, 1111, 1116, 1118, 1157, 1162, 1183, 31162, 31288, 31413, 31441, 31467, 31577: return Taunt_None;
		case 1015, 1172, 1182, 30609, 30614, 30621, 30672, 30816, 30839, 31237, 31348, 31412, 31440, 31492, 31518, 31521: return Taunt_Repurpose;
		case -1: return Taunt_UsesWeapon;
		default: return Taunt_None;
	}
}

void CreateMerasmusGrenade(float vPos[3], float vVel[3], int iOwner, int iDamage, float flRadius, bool bCritBoosted)
{
	float vAng[3];
	vAng[0] = GetRandomFloat(0.0, 360.0);
	vAng[1] = GetRandomFloat(0.0, 360.0);
	vAng[2] = GetRandomFloat(0.0, 360.0);

	int iGrenade = CreateEntityByName("tf_weaponbase_merasmus_grenade");
	SetEntPropEnt(iGrenade, Prop_Send, "m_hOwnerEntity", iOwner);
	SetEntityModel(iGrenade, BOMB_MODEL);
	DispatchSpawn(iGrenade);
	
	float vAngVel[3];
	vAngVel[0] = 600.0;
	vAngVel[1] = GetRandomFloat(-1200.0, 1200.0);
	SDKCall(g_hSDKCall_InitGrenade, iGrenade, vVel, vAngVel, iOwner, iDamage, flRadius);

	// Thanks to Pelipoika for finding the offset
	SetEntDataFloat(iGrenade, g_iOffset_m_flDetonateTime, GetGameTime() + 2.0); 

	// There's a scale parameter in the source code that modifies damage, radius, and model scale,
	// but setting the model scale of the grenade doesn't change it. I'm leaving that out
	char sScript[128];
	FormatEx(sScript, sizeof(sScript), "self.SetCollisionGroup(24)");
	RunScriptCode(iGrenade, sScript);

	TeleportEntity(iGrenade, vPos, vAng, NULL_VECTOR);

	g_hBombs.Set(iGrenade, EntIndexToEntRef(iGrenade));
	if (bCritBoosted)
		g_hCritBoostedGrenades.Set(iGrenade, EntIndexToEntRef(iGrenade));
}

/*
*	Natives
*/

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iSize)
{
	RegPluginLibrary("beholdmerasmus");

	CreateNative("BeholdMerasmus_Create", Native_BeholdMerasmus_CreateMerasmus);
	CreateNative("BeholdMerasmus_Remove", Native_BeholdMerasmus_RemoveMerasmus);
	CreateNative("BeholdMerasmus_IsBoss", Native_BeholdMerasmus_IsMerasmus);
	CreateNative("BeholdMerasmus_IsPerformingHellfire", Native_BeholdMerasmus_IsPerformingHellfire);
	CreateNative("BeholdMerasmus_IsPerformingAoE", Native_BeholdMerasmus_IsPerformingAoE);

	return APLRes_Success;
}

any Native_BeholdMerasmus_CreateMerasmus(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (g_bIsMerasmus[iClient])
		return false;
	
	int iHealth = GetNativeCell(2);
	if (iHealth < 1)
		iHealth = cvMaxHealth.IntValue;

	CreateMerasmus(GetNativeCell(1), iHealth);
	return true;
}

any Native_BeholdMerasmus_RemoveMerasmus(Handle hPlugin, int iNumParams)
{
	int iClient = GetNativeCell(1);
	if (g_bIsMerasmus[iClient])
	{
		RemoveMerasmus(iClient);
		return true;
	}

	return false;
}

any Native_BeholdMerasmus_IsMerasmus(Handle hPlugin, int iNumParams)
{
	return g_bIsMerasmus[GetNativeCell(1)];
}

any Native_BeholdMerasmus_IsPerformingHellfire(Handle hPlugin, int iNumParams)
{
	return g_bInHellfireAttack[GetNativeCell(1)];
}

any Native_BeholdMerasmus_IsPerformingAoE(Handle hPlugin, int iNumParams)
{
	return g_bInAoEAttack[GetNativeCell(1)];
}

/*
*	Stocks
*/

stock float RemapValClamped(float val, float A, float B, float C, float D)
{
    if (A == B)
        return val >= B ? D : C;
    float cVal = (val - A) / (B - A);
    cVal = Clamp(cVal, 0.0, 1.0);

    return C + (D - C) * cVal;
}

stock float Clamp(float val, float min, float max)
{
    if (val < min)
        return min;
    if (val > max)
        return max;
    
    return val;
}

stock int IntMin(int A, int B)
{
	return A < B ? A : B;
}

stock bool IsEntityClient(int iEntity)
{
	return 0 < iEntity <= MaxClients;
}

stock bool IsControlStunned(int iClient)
{
	return GetEntProp(iClient, Prop_Send, "m_iStunFlags") & (TF_STUNFLAG_THIRDPERSON | TF_STUNFLAG_BONKSTUCK);
}

stock void GetClientCenter(int iClient, float vCenter[3])
{
    float vOrigin[3], vMaxs[3];
    GetClientMaxs(iClient, vMaxs);
    GetClientAbsOrigin(iClient, vOrigin);
    vCenter[0] = vOrigin[0];
    vCenter[1] = vOrigin[1];
    vCenter[2] = vMaxs[2] * 0.5 + vOrigin[2];
}

stock void GetEntityCenter(int iEntity, float vCenter[3])
{
    float vOrigin[3], vMaxs[3];
    GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", vOrigin);
    GetEntPropVector(iEntity, Prop_Data, "m_vecMaxs", vMaxs);
    vCenter[0] = vOrigin[0];
    vCenter[1] = vOrigin[1];
    vCenter[2] = vMaxs[2] * 0.5 + vOrigin[2];
}

stock void TF2_RemoveAllItems(int iClient)
{
    TF2_RemoveAllWeapons(iClient);
    TF2_RemoveAllWearables(iClient);
}

stock void TF2_RemoveAllWearables(int iClient)
{
	int iNextMovePeer = -1;
	int iMoveChild = GetEntPropEnt(iClient, Prop_Data, "m_hMoveChild");
    if (iMoveChild == -1)
		return;
	
	do
	{
		char sChildName[12];
		GetEntityClassname(iMoveChild, sChildName, sizeof(sChildName));
		iNextMovePeer = GetEntPropEnt(iMoveChild, Prop_Data, "m_hMovePeer");
		
		if (StrContains(sChildName, "tf_wearable") == 0 || StrContains(sChildName, "tf_powerup") == 0)
			TF2_RemoveWearable(iClient, iMoveChild);
	}
	while ((iMoveChild = iNextMovePeer) != -1);
}

stock bool TF2_IsCritBoosted(int iClient)
{
	return TF2_IsPlayerInCondition(iClient, TFCond_Kritzkrieged)
		|| TF2_IsPlayerInCondition(iClient, TFCond_HalloweenCritCandy)
		|| TF2_IsPlayerInCondition(iClient, TFCond_CritCanteen)
		|| TF2_IsPlayerInCondition(iClient, TFCond_CritOnFirstBlood)
		|| TF2_IsPlayerInCondition(iClient, TFCond_CritOnWin)
		|| TF2_IsPlayerInCondition(iClient, TFCond_CritOnFlagCapture)
		|| TF2_IsPlayerInCondition(iClient, TFCond_CritOnKill)
		|| TF2_IsPlayerInCondition(iClient, TFCond_CritOnDamage)
		|| TF2_IsPlayerInCondition(iClient, TFCond_CritRuneTemp);
}

stock int CreateClientWorldModel(int iClient, char[] sModelName)
{
    int iWorldModel = CreateEntityByName("tf_wearable");
    
    SetEntProp(iWorldModel, Prop_Send, "m_nModelIndex", PrecacheModel(sModelName));
    SetEntProp(iWorldModel, Prop_Data, "m_bForcePurgeFixedupStrings", true);
    SetEntProp(iWorldModel, Prop_Send, "m_bValidatedAttachedEntity", true);
    SetEntProp(iWorldModel, Prop_Send, "m_bInitialized", true);
    SetEntPropEnt(iWorldModel, Prop_Data, "m_hOwnerEntity", iClient);
    DispatchSpawn(iWorldModel);
    SetVariantString("!activator");
    AcceptEntityInput(iWorldModel, "SetParent", iClient);

    // Removes preserved entity status, won't persist through rounds
    SetEntPropString(iWorldModel, Prop_Data, "m_iClassname", "tf_custom_wearable"); 
    
    return iWorldModel;
}

stock void RunScriptCode(int iEntity, char[] sScript)
{
	SetVariantString(sScript);
    AcceptEntityInput(iEntity, "RunScriptCode");
}

stock void SetEntityInvis(int iEntity, bool bInvis)
{
	int iColor = GetEntProp(iEntity, Prop_Send, "m_clrRender");
	if (bInvis)
	{
		SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", 0.0);
		if ((iColor & 0xFF000000) != 0)
			SetEntProp(iEntity, Prop_Send, "m_clrRender", iColor & ~0xFF000000);
	}
	else
	{
		SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", 1.0);
		if ((iColor & 0xFF000000) != 0xFF000000)
			SetEntProp(iEntity, Prop_Send, "m_clrRender", iColor | 0xFF000000);
	}
}

stock void AddEffectFlags(int iEntity, int iFlags)
{
	int iEffects = GetEntProp(iEntity, Prop_Send, "m_fEffects");
	if ((iEffects & iFlags) != iFlags)
		SetEntProp(iEntity, Prop_Send, "m_fEffects", iEffects | iFlags);
}

stock void RemoveEffectFlags(int iEntity, int iFlags)
{
	int iEffects = GetEntProp(iEntity, Prop_Send, "m_fEffects");
	if ((iEffects & iFlags))
		SetEntProp(iEntity, Prop_Send, "m_fEffects", iEffects & ~iFlags);
}

enum ParticleAttachment_t
{
	PATTACH_ABSORIGIN = 0,
	PATTACH_ABSORIGIN_FOLLOW,
	PATTACH_CUSTOMORIGIN,
	PATTACH_POINT,
	PATTACH_POINT_FOLLOW,
	PATTACH_WORLDORIGIN,
	PATTACH_ROOTBONE_FOLLOW
};

stock void TE_SetupTFParticleEffect(
	int iParticleIndex, 
	const float vOrigin[3] = NULL_VECTOR, 
	const float vStart[3] = NULL_VECTOR,
	const float vAngles[3] = NULL_VECTOR, 
	int iEntity = -1, 
	ParticleAttachment_t iAttachType = view_as<ParticleAttachment_t>(-1), 
	int iAttachPoint = -1,
	int iControlPoint1 = -1,
	ParticleAttachment_t eParticleAttachment = view_as<ParticleAttachment_t>(-1),
	float vParticleOffset[3] = { 0.0, 0.0, 0.0 })
{
	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", vOrigin[0]);
	TE_WriteFloat("m_vecOrigin[1]", vOrigin[1]);
	TE_WriteFloat("m_vecOrigin[2]", vOrigin[2]);
	TE_WriteFloat("m_vecStart[0]", vStart[0]);
	TE_WriteFloat("m_vecStart[1]", vStart[1]);
	TE_WriteFloat("m_vecStart[2]", vStart[2]);
	TE_WriteVector("m_vecAngles", vAngles);
	TE_WriteNum("m_iParticleSystemIndex", iParticleIndex);
	TE_WriteNum("entindex", iEntity);
	TE_WriteNum("m_iAttachType", view_as<int>(iAttachType));
	TE_WriteNum("m_iAttachmentPointIndex", iAttachPoint);
	TE_WriteNum("m_bResetParticles", true);
	TE_WriteNum("m_bControlPoint1", iControlPoint1);
	TE_WriteNum("m_ControlPoint1.m_eParticleAttachment", eParticleAttachment);
	TE_WriteFloat("m_ControlPoint1.m_vecOffset[0]", vParticleOffset[0]);
	TE_WriteFloat("m_ControlPoint1.m_vecOffset[1]", vParticleOffset[1]);
	TE_WriteFloat("m_ControlPoint1.m_vecOffset[2]", vParticleOffset[2]);
}

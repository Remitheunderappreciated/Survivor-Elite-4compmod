#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

int g_iSavedPrimary[MAXPLAYERS + 1];
bool g_bAllowSMGDrop[MAXPLAYERS + 1];
bool g_bIsReloadingSMG[MAXPLAYERS + 1];

public Plugin myinfo = 
{
    name = "L4D2 Secondary SMG Patch",
    author = "Custom",
    description = "Allows weapon_smg and weapon_smg_silenced as clip-only secondary weapons with infinite reloads",
    version = "2.3",
    url = ""
};

public void OnPluginStart()
{
    for (int i = 1; i != MaxClients + 1; i++)
    {
        if (IsClientInGame(i))
        {
            OnClientPutInServer(i);
        }
    }
}

public void OnClientPutInServer(int client)
{
    g_iSavedPrimary[client] = INVALID_ENT_REFERENCE;
    g_bAllowSMGDrop[client] = false;
    g_bIsReloadingSMG[client] = false;

    SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
    SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
    SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
    SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (IsSecondarySMG(classname))
    {
        SDKHook(entity, SDKHook_SpawnPost, OnSMGSpawnPost);
    }
}

public void OnSMGSpawnPost(int entity)
{
    if (!IsValidEntity(entity))
        return;

    // Removes the 999 reserve ammo counter so only the 50 clip is displayed
    SetEntProp(entity, Prop_Send, "m_iPrimaryAmmoType", -1);
}

// Prevents L4D2 from auto-dropping the SMG when m_iClip1 hits 0
public Action OnWeaponDrop(int client, int weapon)
{
    if (!IsValidClient(client) || !IsValidEntity(weapon))
        return Plugin_Continue;

    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));

    if (IsSecondarySMG(classname) && !g_bAllowSMGDrop[client])
    {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action OnWeaponCanUse(int client, int weapon)
{
    if (!IsValidClient(client) || !IsValidEntity(weapon))
        return Plugin_Continue;

    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));

    if (!IsSecondarySMG(classname))
        return Plugin_Continue;

    // Save current Primary weapon (Slot 0) before L4D2 touches it
    int primary = GetPlayerWeaponSlot(client, 0);
    if (primary != -1 && primary != weapon && IsValidEntity(primary))
    {
        char primClass[64];
        GetEntityClassname(primary, primClass, sizeof(primClass));
        if (!IsSecondarySMG(primClass))
        {
            g_iSavedPrimary[client] = EntIndexToEntRef(primary);
        }
    }

    // Drop existing Secondary weapon (Slot 1) if present
    int secondary = GetPlayerWeaponSlot(client, 1);
    if (secondary != -1 && secondary != weapon && IsValidEntity(secondary))
    {
        g_bAllowSMGDrop[client] = true;
        SDKHooks_DropWeapon(client, secondary, NULL_VECTOR, NULL_VECTOR);
        g_bAllowSMGDrop[client] = false;
    }

    return Plugin_Continue;
}

public Action OnWeaponEquip(int client, int weapon)
{
    if (!IsValidClient(client) || !IsValidEntity(weapon))
        return Plugin_Continue;

    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));

    if (IsSecondarySMG(classname))
    {
        SetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", -1);
    }

    return Plugin_Continue;
}

public void OnWeaponEquipPost(int client, int weapon)
{
    if (!IsValidClient(client) || !IsValidEntity(weapon))
        return;

    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));

    if (!IsSecondarySMG(classname))
        return;

    SetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", -1);

    // Move the SMG into Slot 1 (Secondary) and restore your Primary shotgun/rifle to Slot 0
    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    pack.WriteCell(EntIndexToEntRef(weapon));
    RequestFrame(Frame_RestorePrimaryAndSlot, pack);
}

public void Frame_RestorePrimaryAndSlot(DataPack pack)
{
    pack.Reset();
    int client = GetClientOfUserId(pack.ReadCell());
    int smg = EntRefToEntIndex(pack.ReadCell());
    delete pack;

    if (!IsValidClient(client) || smg == -1 || !IsValidEntity(smg))
        return;

    int savedPrimary = EntRefToEntIndex(g_iSavedPrimary[client]);
    g_iSavedPrimary[client] = INVALID_ENT_REFERENCE;

    // Place the SMG in Slot 1
    SetEntPropEnt(client, Prop_Send, "m_hMyWeapons", smg, 1);

    // If L4D2 dropped or bumped your Primary shotgun, re-attach it cleanly to Slot 0
    if (savedPrimary != -1 && IsValidEntity(savedPrimary))
    {
        if (GetEntPropEnt(savedPrimary, Prop_Send, "m_hOwnerEntity") != client)
        {
            SDKUnhook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
            EquipPlayerWeapon(client, savedPrimary);
            SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
        }
        SetEntPropEnt(client, Prop_Send, "m_hMyWeapons", savedPrimary, 0);
        SetEntPropEnt(client, Prop_Send, "m_hMyWeapons", smg, 1);
    }
    else
    {
        SetEntPropEnt(client, Prop_Send, "m_hMyWeapons", -1, 0);
    }

    SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", smg);
}

// Handles manual (R) and auto-empty reloads while keeping the HUD clip-only
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (!IsValidClient(client) || g_bIsReloadingSMG[client])
        return Plugin_Continue;

    int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (activeWeapon == -1 || !IsValidEntity(activeWeapon))
        return Plugin_Continue;

    char classname[64];
    GetEntityClassname(activeWeapon, classname, sizeof(classname));

    if (!IsSecondarySMG(classname))
        return Plugin_Continue;

    int clip = GetEntProp(activeWeapon, Prop_Send, "m_iClip1");

    // Trigger reload if clip hits 0 OR player presses R with less than 50 rounds
    if (clip <= 0 || ((buttons & IN_RELOAD) && clip < 50))
    {
        g_bIsReloadingSMG[client] = true;

        // Temporarily enable pistol reserve ammo so the reload animation triggers normally
        SetEntProp(activeWeapon, Prop_Send, "m_iPrimaryAmmoType", 1);
        SetEntProp(client, Prop_Send, "m_iAmmo", 50, _, 1);
        buttons |= IN_RELOAD;

        DataPack pack = new DataPack();
        pack.WriteCell(GetClientUserId(client));
        pack.WriteCell(EntIndexToEntRef(activeWeapon));
        CreateTimer(2.25, Timer_CompleteSMGReload, pack, TIMER_FLAG_NO_MAPCHANGE);
    }

    return Plugin_Continue;
}

public Action Timer_CompleteSMGReload(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientOfUserId(pack.ReadCell());
    int smg = EntRefToEntIndex(pack.ReadCell());
    delete pack;

    if (client > 0 && client != MaxClients + 1)
    {
        g_bIsReloadingSMG[client] = false;
    }

    if (!IsValidClient(client) || smg == -1 || !IsValidEntity(smg))
        return Plugin_Stop;

    // Refill clip to 50 and hide the reserve counter again (-1)
    SetEntProp(smg, Prop_Send, "m_iClip1", 50);
    SetEntProp(smg, Prop_Send, "m_iPrimaryAmmoType", -1);

    return Plugin_Stop;
}

bool IsSecondarySMG(const char[] classname)
{
    return (StrEqual(classname, "weapon_smg", false) || StrEqual(classname, "weapon_smg_silenced", false));
}

bool IsValidClient(int client)
{
    return (client > 0 && client != MaxClients + 1 && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client));
}

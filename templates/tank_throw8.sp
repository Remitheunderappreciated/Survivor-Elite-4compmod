#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define PLUGIN_VERSION  "1.8.0"

#define TANK_CLASS      8
#define HUNTER_CLASS    3
#define BOOMER_CLASS    2
#define JOCKEY_CLASS    5
#define GRAB_RANGE      150.0
#define THROW_SPEED     900.0
#define BLAST_RADIUS    150.0
#define BLAST_DAMAGE    20
#define LAND_TIMEOUT    5.0
#define POUNCE_TIME     3.0     // how long a thrown Hunter can look for a survivor
#define POUNCE_RANGE    90.0    // distance that counts as landing on a survivor
#define POUNCE_DAMAGE   25.0
#define GLOW_RANGE      600.0
#define GLOW_COLOR      255     // red: R + G*256 + B*65536

ConVar g_cvEnable;

int   g_iHeld[MAXPLAYERS + 1];          // tank -> infected it holds
int   g_iHeldBy[MAXPLAYERS + 1];        // infected -> tank holding it
int   g_iLastButtons[MAXPLAYERS + 1];
int   g_iThrowerUserId[MAXPLAYERS + 1];
float g_fThrowTime[MAXPLAYERS + 1];
bool  g_bPounce[MAXPLAYERS + 1];        // thrown Hunter is looking for a survivor to pin
bool  g_bHunterCharge[MAXPLAYERS + 1];  // carried Hunter is holding its pounce charge
int   g_iGlowRef[MAXPLAYERS + 1];       // entity ref of the Tank-only glow model

public Plugin myinfo =
{
    name        = "L4D2 Tank Infected Throw",
    author      = "Generated",
    description = "Tanks grab Boomers, Jockeys and Hunters, show a glow only to Tanks, and throw them with the rock attack",
    version     = PLUGIN_VERSION,
    url         = ""
};

public void OnPluginStart()
{
    g_cvEnable = CreateConVar("sm_tankthrow_enable", "1", "Enable tank infected throwing", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    HookEvent("player_death", Event_PlayerDeath);

    for (int i = 1; i <= MaxClients; i++)
        g_iGlowRef[i] = INVALID_ENT_REFERENCE;

    // Hook clients already in the server (for late loads).
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
            SDKHook(i, SDKHook_SetTransmit, Hook_InfectedTransmit);
    }

    // Keeps the grabbed infected pinned in front of the Tank.
    CreateTimer(0.01, Timer_HoldUpdate, _, TIMER_REPEAT);

    // Creates, syncs and removes the Tank-only glow.
    CreateTimer(0.05, Timer_GlowUpdate, _, TIMER_REPEAT);

    // Checks whether a thrown Hunter has reached a survivor.
    CreateTimer(0.05, Timer_PounceCheck, _, TIMER_REPEAT);
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_SetTransmit, Hook_InfectedTransmit);
}

public void OnClientDisconnect(int client)
{
    if (g_iHeld[client] > 0)
        ReleaseHeld(client);

    if (g_iHeldBy[client] > 0)
    {
        g_iHeld[g_iHeldBy[client]] = 0;
        g_iHeldBy[client] = 0;
    }

    RemoveGlow(client);

    g_iLastButtons[client] = 0;
    g_iThrowerUserId[client] = 0;
    g_bPounce[client] = false;
    g_bHunterCharge[client] = false;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    if (victim > 0 && g_iHeld[victim] > 0)
        ReleaseHeld(victim);
}

// Cancels rock throws while the Tank is holding an infected.
// Rock throws use sequences above 48 (same check used in Attano's Tank control plugin).
public Action L4D2_OnSelectTankAttack(int client, int &sequence)
{
    if (g_iHeld[client] > 0 && sequence > 48)
        return Plugin_Handled;

    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (!g_cvEnable.BoolValue || client <= 0 || client > MaxClients || !IsClientInGame(client))
        return Plugin_Continue;

    // A carried Hunter holds crouch + attack to keep its pounce charged.
    // This applies only while carried, so the Hunter has full control after a throw.
    if (g_bHunterCharge[client])
    {
        buttons |= IN_DUCK | IN_ATTACK;
        return Plugin_Changed;
    }

    if (!IsTank(client))
        return Plugin_Continue;

    int pressed = buttons & ~g_iLastButtons[client];
    g_iLastButtons[client] = buttons;

    if (g_iHeld[client] > 0)
    {
        // Block the rock spawn while holding someone; right-click throws the held infected instead.
        buttons &= ~IN_ATTACK2;
        if (pressed & IN_ATTACK2)
            ThrowHeld(client);
    }
    else if (pressed & IN_USE)
    {
        TryGrab(client);
    }

    return Plugin_Continue;
}

public Action Timer_HoldUpdate(Handle timer)
{
    if (!g_cvEnable.BoolValue)
        return Plugin_Continue;

    for (int tank = 1; tank <= MaxClients; tank++)
    {
        int target = g_iHeld[tank];
        if (target <= 0)
            continue;

        if (!IsTank(tank) || !IsValidInfected(target, true))
        {
            ReleaseHeld(tank);
            continue;
        }

        float tankPos[3], eyeAng[3], fwd[3], pos[3];
        GetClientAbsOrigin(tank, tankPos);
        GetClientEyeAngles(tank, eyeAng);
        eyeAng[0] = 0.0;
        GetAngleVectors(eyeAng, fwd, NULL_VECTOR, NULL_VECTOR);

        pos[0] = tankPos[0] + fwd[0] * 40.0;
        pos[1] = tankPos[1] + fwd[1] * 40.0;
        pos[2] = tankPos[2] + 60.0;

        TeleportEntity(target, pos, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
    }
    return Plugin_Continue;
}

// Creates or removes the glow model near Tanks, and keeps it matched to the infected's pose.
public Action Timer_GlowUpdate(Handle timer)
{
    if (!g_cvEnable.BoolValue)
        return Plugin_Continue;

    for (int i = 1; i <= MaxClients; i++)
    {
        bool grabbable = IsValidInfected(i, true) && IsGrabbableClass(i);

        if (!grabbable)
        {
            RemoveGlow(i);
            continue;
        }

        bool nearTank = false;
        float iPos[3];
        GetClientAbsOrigin(i, iPos);

        for (int t = 1; t <= MaxClients; t++)
        {
            if (!IsTank(t))
                continue;

            float tPos[3];
            GetClientAbsOrigin(t, tPos);
            if (GetVectorDistance(iPos, tPos) <= GLOW_RANGE)
            {
                nearTank = true;
                break;
            }
        }

        int glow = EntRefToEntIndex(g_iGlowRef[i]);

        if (!nearTank)
        {
            if (glow != INVALID_ENT_REFERENCE)
                RemoveGlow(i);
            continue;
        }

        if (glow == INVALID_ENT_REFERENCE)
        {
            CreateGlow(i);
            continue;
        }

        SyncGlow(i, glow);
    }
    return Plugin_Continue;
}

// Creates a copy of the infected's model that only Tanks can see.
// The real infected is hidden from Tanks while the copy exists (see Hook_InfectedTransmit).
void CreateGlow(int infected)
{
    char model[PLATFORM_MAX_PATH];
    GetClientModel(infected, model, sizeof(model));

    int ent = CreateEntityByName("prop_dynamic_override");
    if (ent == -1)
        return;

    DispatchKeyValue(ent, "model", model);
    DispatchKeyValue(ent, "solid", "0");
    DispatchKeyValue(ent, "disableshadows", "1");
    DispatchSpawn(ent);

    SetEntProp(ent, Prop_Send, "m_iGlowType", 3);
    SetEntProp(ent, Prop_Send, "m_nGlowRange", RoundToNearest(GLOW_RANGE));
    SetEntProp(ent, Prop_Send, "m_glowColorOverride", GLOW_COLOR);

    SDKHook(ent, SDKHook_SetTransmit, Hook_GlowTransmit);

    g_iGlowRef[infected] = EntIndexToEntRef(ent);
    SyncGlow(infected, ent);
}

// Copies position, angles and animation state from the infected to the glow model.
void SyncGlow(int infected, int glow)
{
    float pos[3], ang[3];
    GetClientAbsOrigin(infected, pos);
    GetClientAbsAngles(infected, ang);
    TeleportEntity(glow, pos, ang, NULL_VECTOR);

    SetEntProp(glow, Prop_Send, "m_nSequence", GetEntProp(infected, Prop_Send, "m_nSequence"));
    SetEntPropFloat(glow, Prop_Send, "m_flCycle", GetEntPropFloat(infected, Prop_Send, "m_flCycle"));
    SetEntPropFloat(glow, Prop_Send, "m_flPlaybackRate", GetEntPropFloat(infected, Prop_Send, "m_flPlaybackRate"));
}

void RemoveGlow(int infected)
{
    int ent = EntRefToEntIndex(g_iGlowRef[infected]);
    if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent))
        AcceptEntityInput(ent, "Kill");

    g_iGlowRef[infected] = INVALID_ENT_REFERENCE;
}

// The glow copy is shown only to Tanks.
public Action Hook_GlowTransmit(int entity, int client)
{
    if (IsTank(client))
        return Plugin_Continue;

    return Plugin_Handled;
}

// While the glow copy exists, the real infected is hidden from Tanks so they see only one model.
// Survivors still see the real infected.
public Action Hook_InfectedTransmit(int entity, int client)
{
    if (entity <= 0 || entity > MaxClients)
        return Plugin_Continue;

    if (IsTank(client) && EntRefToEntIndex(g_iGlowRef[entity]) != INVALID_ENT_REFERENCE)
        return Plugin_Handled;

    return Plugin_Continue;
}

// Sets or clears the Hunter's pounce-attempt flag on its lunge ability.
// Experimental: m_customAbility and m_isAttemptingToPounce come from the Left4DHooks and
// SirPlease sources. Not verified to start a lunge or wall jump in every build.
void SetHunterLungeState(int hunter, bool on)
{
    int ability = GetEntPropEnt(hunter, Prop_Send, "m_customAbility");
    if (ability <= 0 || !IsValidEntity(ability))
        return;

    SetEntProp(ability, Prop_Send, "m_isAttemptingToPounce", on ? 1 : 0);
}

// Checks each thrown Hunter for a survivor in range, then pins the survivor and deals pounce damage.
public Action Timer_PounceCheck(Handle timer)
{
    if (!g_cvEnable.BoolValue)
        return Plugin_Continue;

    for (int h = 1; h <= MaxClients; h++)
    {
        if (!g_bPounce[h])
            continue;

        if (!IsClientInGame(h) || !IsPlayerAlive(h) || GetGameTime() - g_fThrowTime[h] > POUNCE_TIME)
        {
            g_bPounce[h] = false;
            if (IsClientInGame(h))
                SetHunterLungeState(h, false);
            continue;
        }

        // Give the throw a moment to leave the Tank before checking for contact.
        if (GetGameTime() - g_fThrowTime[h] < 0.15)
            continue;

        float hPos[3];
        GetClientAbsOrigin(h, hPos);

        for (int s = 1; s <= MaxClients; s++)
        {
            if (!IsClientInGame(s) || !IsPlayerAlive(s) || GetClientTeam(s) != 2)
                continue;

            // Skip survivors that are already pinned.
            if (GetEntPropEnt(s, Prop_Send, "m_pounceAttacker") > 0)
                continue;

            float sPos[3];
            GetClientAbsOrigin(s, sPos);
            if (GetVectorDistance(hPos, sPos) <= POUNCE_RANGE)
            {
                // Record the pounce so the survivor is pinned, the same way the game does it.
                SetEntPropEnt(h, Prop_Send, "m_pounceVictim", s);
                SetEntPropEnt(s, Prop_Send, "m_pounceAttacker", h);

                SDKHooks_TakeDamage(s, h, h, POUNCE_DAMAGE, DMG_SLASH);
                g_bPounce[h] = false;
                SetHunterLungeState(h, false);
                break;
            }
        }
    }
    return Plugin_Continue;
}

bool IsGrabbableClass(int client)
{
    int zc = GetEntProp(client, Prop_Send, "m_zombieClass");
    return zc == HUNTER_CLASS || zc == BOOMER_CLASS || zc == JOCKEY_CLASS;
}

void TryGrab(int tank)
{
    float tankPos[3];
    GetClientAbsOrigin(tank, tankPos);

    int best = 0;
    float bestDist = GRAB_RANGE;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidInfected(i, false))
            continue;
        if (!IsGrabbableClass(i))
            continue;

        float pos[3];
        GetClientAbsOrigin(i, pos);
        float dist = GetVectorDistance(tankPos, pos);

        if (dist <= bestDist)
        {
            bestDist = dist;
            best = i;
        }
    }

    if (best == 0)
        return;

    g_iHeld[tank] = best;
    g_iHeldBy[best] = tank;
    SetEntityMoveType(best, MOVETYPE_NONE);

    // A carried Hunter starts charging its pounce right away.
    g_bHunterCharge[best] = (GetEntProp(best, Prop_Send, "m_zombieClass") == HUNTER_CLASS);
}

void ThrowHeld(int tank)
{
    int target = g_iHeld[tank];
    if (target <= 0)
        return;

    // Full aim direction, including pitch, so the throw follows the crosshair.
    float eyeAng[3], aimDir[3], vel[3];
    GetClientEyeAngles(tank, eyeAng);
    GetAngleVectors(eyeAng, aimDir, NULL_VECTOR, NULL_VECTOR);
    NormalizeVector(aimDir, aimDir);

    vel[0] = aimDir[0] * THROW_SPEED;
    vel[1] = aimDir[1] * THROW_SPEED;
    vel[2] = aimDir[2] * THROW_SPEED;

    SetEntityMoveType(target, MOVETYPE_WALK);
    g_iHeldBy[target] = 0;
    g_iHeld[tank] = 0;

    TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, vel);

    // Stop forcing buttons so the Hunter has normal control after the throw.
    g_bHunterCharge[target] = false;
    bool isHunter = (GetEntProp(target, Prop_Send, "m_zombieClass") == HUNTER_CLASS);
    g_bPounce[target] = isHunter;

    // Start the lunge state on the thrown Hunter (experimental, see SetHunterLungeState).
    if (isHunter)
        SetHunterLungeState(target, true);

    g_iThrowerUserId[target] = GetClientUserId(tank);
    g_fThrowTime[target] = GetGameTime();
    CreateTimer(0.1, Timer_CheckLanding, GetClientUserId(target), TIMER_REPEAT);
}

void ReleaseHeld(int tank)
{
    int target = g_iHeld[tank];
    g_iHeld[tank] = 0;

    if (target > 0 && IsClientInGame(target))
    {
        SetEntityMoveType(target, MOVETYPE_WALK);
        g_iHeldBy[target] = 0;
        g_bHunterCharge[target] = false;
    }
}

public Action Timer_CheckLanding(Handle timer, int userid)
{
    int victim = GetClientOfUserId(userid);
    if (victim <= 0 || !IsClientInGame(victim) || !IsPlayerAlive(victim))
        return Plugin_Stop;

    float airTime = GetGameTime() - g_fThrowTime[victim];
    if (airTime < 0.3)
        return Plugin_Continue;

    bool grounded = (GetEntityFlags(victim) & FL_ONGROUND) != 0;
    if (!grounded && airTime < LAND_TIMEOUT)
        return Plugin_Continue;

    // Landed: damage survivors in the blast radius.
    int thrower = GetClientOfUserId(g_iThrowerUserId[victim]);
    float origin[3];
    GetClientAbsOrigin(victim, origin);

    for (int s = 1; s <= MaxClients; s++)
    {
        if (!IsClientInGame(s) || !IsPlayerAlive(s) || GetClientTeam(s) != 2)
            continue;

        float sPos[3];
        GetClientAbsOrigin(s, sPos);
        if (GetVectorDistance(origin, sPos) <= BLAST_RADIUS)
            SDKHooks_TakeDamage(s, thrower, thrower, float(BLAST_DAMAGE), DMG_CLUB);
    }

    g_iThrowerUserId[victim] = 0;
    return Plugin_Stop;
}

bool IsTank(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client)
        && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == TANK_CLASS;
}

bool IsValidInfected(int client, bool allowHeld)
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
        return false;
    if (GetClientTeam(client) != 3)
        return false;
    if (GetEntProp(client, Prop_Send, "m_zombieClass") == TANK_CLASS)
        return false;
    if (GetEntProp(client, Prop_Send, "m_isGhost") == 1)
        return false;
    if (!allowHeld && g_iHeldBy[client] > 0)
        return false;
    return true;
}

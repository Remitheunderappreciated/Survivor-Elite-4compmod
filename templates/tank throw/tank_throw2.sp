#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define PLUGIN_VERSION "1.1.0"

#define TANK_CLASS      8
#define HUNTER_CLASS    3
#define GRAB_RANGE      150.0
#define THROW_FWD       900.0
#define THROW_UP        350.0
#define BLAST_RADIUS    150.0
#define BLAST_DAMAGE    20
#define LAND_TIMEOUT    5.0
#define LUNGE_SPEED     400.0
#define LUNGE_UP        250.0

ConVar g_cvEnable;

int   g_iHeld[MAXPLAYERS + 1];        // tank -> infected it holds
int   g_iHeldBy[MAXPLAYERS + 1];      // infected -> tank holding it
int   g_iLastButtons[MAXPLAYERS + 1];
int   g_iThrowerUserId[MAXPLAYERS + 1];
float g_fThrowTime[MAXPLAYERS + 1];
bool  g_bPounce[MAXPLAYERS + 1];      // thrown infected that should lunge

public Plugin myinfo =
{
    name        = "L4D2 Tank Infected Throw",
    author      = "Generated",
    description = "Tanks grab special infected and throw them with the rock attack",
    version     = PLUGIN_VERSION,
    url         = ""
};

public void OnPluginStart()
{
    g_cvEnable = CreateConVar("sm_tankthrow_enable", "1", "Enable tank infected throwing", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    HookEvent("player_death", Event_PlayerDeath);

    // Keeps the grabbed infected pinned in front of the Tank.
    CreateTimer(0.01, Timer_HoldUpdate, _, TIMER_REPEAT);
}

public void OnClientDisconnect(int client)
{
    if (g_iHeld[client] > 0)
        ReleaseHeld(client, false);

    if (g_iHeldBy[client] > 0)
    {
        g_iHeld[g_iHeldBy[client]] = 0;
        g_iHeldBy[client] = 0;
    }

    g_iLastButtons[client] = 0;
    g_iThrowerUserId[client] = 0;
    g_bPounce[client] = false;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    if (victim > 0 && g_iHeld[victim] > 0)
        ReleaseHeld(victim, false);
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
    if (!g_cvEnable.BoolValue || !IsTank(client))
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
            ReleaseHeld(tank, false);
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
}

void ThrowHeld(int tank)
{
    int target = g_iHeld[tank];
    if (target <= 0)
        return;

    float eyeAng[3], fwd[3], vel[3];
    GetClientEyeAngles(tank, eyeAng);
    GetAngleVectors(eyeAng, fwd, NULL_VECTOR, NULL_VECTOR);

    vel[0] = fwd[0] * THROW_FWD;
    vel[1] = fwd[1] * THROW_FWD;
    vel[2] = THROW_UP;

    SetEntityMoveType(target, MOVETYPE_WALK);
    g_iHeldBy[target] = 0;
    g_iHeld[tank] = 0;

    TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, vel);

    // Hunters lunge at a survivor shortly after landing the throw.
    g_bPounce[target] = (GetEntProp(target, Prop_Send, "m_zombieClass") == HUNTER_CLASS);

    g_iThrowerUserId[target] = GetClientUserId(tank);
    g_fThrowTime[target] = GetGameTime();
    CreateTimer(0.1, Timer_CheckLanding, GetClientUserId(target), TIMER_REPEAT);
}

void ReleaseHeld(int tank, bool thrown)
{
    int target = g_iHeld[tank];
    g_iHeld[tank] = 0;

    if (target > 0 && IsClientInGame(target))
    {
        SetEntityMoveType(target, MOVETYPE_WALK);
        g_iHeldBy[target] = 0;
    }
}

void LungeAtNearestSurvivor(int hunter)
{
    float hPos[3];
    GetClientAbsOrigin(hunter, hPos);

    int best = 0;
    float bestDist = 99999.0;
    for (int s = 1; s <= MaxClients; s++)
    {
        if (!IsClientInGame(s) || !IsPlayerAlive(s) || GetClientTeam(s) != 2)
            continue;

        float sPos[3];
        GetClientAbsOrigin(s, sPos);
        float d = GetVectorDistance(hPos, sPos);
        if (d < bestDist)
        {
            bestDist = d;
            best = s;
        }
    }

    if (best == 0)
        return;

    float tPos[3], dir[3], vel[3];
    GetClientAbsOrigin(best, tPos);
    SubtractVectors(tPos, hPos, dir);
    dir[2] = 0.0;
    NormalizeVector(dir, dir);

    vel[0] = dir[0] * LUNGE_SPEED;
    vel[1] = dir[1] * LUNGE_SPEED;
    vel[2] = LUNGE_UP;

    TeleportEntity(hunter, NULL_VECTOR, NULL_VECTOR, vel);
}

public Action Timer_CheckLanding(Handle timer, int userid)
{
    int victim = GetClientOfUserId(userid);
    if (victim <= 0 || !IsClientInGame(victim) || !IsPlayerAlive(victim))
        return Plugin_Stop;

    if (g_bPounce[victim] && (GetGameTime() - g_fThrowTime[victim]) >= 0.15)
    {
        g_bPounce[victim] = false;
        LungeAtNearestSurvivor(victim);
    }

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

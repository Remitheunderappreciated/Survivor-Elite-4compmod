/**
 * L4D2 Bucket 0 Zoom
 *
 * Zoom (IN_ZOOM) and burst behaviour for primary-slot weapons:
 *  - Rifles and SMGs in g_sZoomWeapons zoom only while that weapon is in
 *    your hands. Switching to another weapon cancels the zoom.
 *  - While zoomed, those weapons fire bursts. Holding attack keeps firing
 *    bursts; releasing attack stops them.
 *  - weapon_rifle_sg552 keeps its native zoom. The plugin bursts it only
 *    while it is zoomed.
 *  - weapon_rifle_desert fires full auto when not zoomed, and bursts when zoomed.
 *
 * Excluded on purpose: all shotguns and all sniper rifles.
 *
 * NOTE: Zoom uses the player's field of view (m_iFOV). This is an assumption,
 * not verified against the SG552's own zoom code. Test in-game.
 *
 * NOTE: Bursts and full auto are driven by the clip count and the weapon's
 * m_flNextPrimaryAttack. Both are tuned by guesswork. Test in-game.
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.3.0"

#define ZOOM_FOV            55
#define BURST_SHOTS         3       // shots per burst while zoomed
#define BURST_INTERVAL      0.08    // gap between shots inside a burst (all zoomed weapons, SG552 included)
#define BURST_COOLDOWN      0.40    // pause after each burst while attack is held

// Bucket 0 weapons that get the zoom and burst. Shotguns and snipers are not listed.
static const char g_sZoomWeapons[][] =
{
    "weapon_rifle",
    "weapon_rifle_ak47",
    "weapon_rifle_desert",
    "weapon_smg_mp5"
};

bool g_bZoomed[MAXPLAYERS + 1];
bool g_bZoomKeyDown[MAXPLAYERS + 1];

// Burst state.
int g_iBurstLeft[MAXPLAYERS + 1];    // shots left in the current burst
int g_iLastClip[MAXPLAYERS + 1];     // clip count from the last tick
int g_iLastWeapon[MAXPLAYERS + 1];   // active weapon from the last tick

// Desert rifle auto-fire emulation: alternates the attack bit each tick.
bool g_bAutoPulse[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name        = "L4D2 Bucket 0 Zoom",
    author      = "Workik, RemiTheUnderappreciated",
    description = "Adds zoom and burst fire to bucket 0 rifles and SMGs, with desert rifle full auto",
    version     = PLUGIN_VERSION,
    url         = ""
};

public void OnPluginStart()
{
    HookEvent("weapon_drop", Event_PlayerReset, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerReset, EventHookMode_Post);
    HookEvent("player_spawn", Event_PlayerReset, EventHookMode_Post);
}

public void OnClientDisconnect(int client)
{
    ResetZoom(client);
}

public void OnMapEnd()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        g_bZoomed[i] = false;
        g_bZoomKeyDown[i] = false;
        g_iBurstLeft[i] = 0;
        g_iLastClip[i] = 0;
        g_iLastWeapon[i] = -1;
        g_bAutoPulse[i] = false;
    }
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client))
    {
        return Plugin_Continue;
    }

    int active = GetActiveWeaponEnt(client);

    // Switched weapon: restart shot counting so the new weapon's clip is not read as a shot.
    if (active != g_iLastWeapon[client])
    {
        g_iLastWeapon[client] = active;
        g_iBurstLeft[client] = 0;
        g_iLastClip[client] = (active != -1) ? GetEntProp(active, Prop_Send, "m_iClip1") : 0;
        g_bAutoPulse[client] = false;
    }

    bool keyDown = (buttons & IN_ZOOM) != 0;

    // React only on the key press, not while it is held.
    if (keyDown && !g_bZoomKeyDown[client])
    {
        if (g_bZoomed[client])
        {
            ResetZoom(client);
        }
        else if (IsZoomableWeapon(client))
        {
            ApplyZoom(client, ZOOM_FOV);
        }
    }

    g_bZoomKeyDown[client] = keyDown;

    // Leave zoom when the zoomable weapon is no longer in hand.
    if (g_bZoomed[client] && !IsZoomableWeapon(client))
    {
        ResetZoom(client);
    }

    if (active == -1)
    {
        return Plugin_Continue;
    }

    if (g_bZoomed[client])
    {
        ProcessBurst(client, active, BURST_INTERVAL);
    }
    else if (IsSG552(active))
    {
        // The SG552 keeps its own zoom. Burst only while it is zoomed.
        if (IsSG552Zoomed(client))
        {
            ProcessBurst(client, active, BURST_INTERVAL);
        }
        else
        {
            g_iBurstLeft[client] = 0;
            g_iLastClip[client] = GetEntProp(active, Prop_Send, "m_iClip1");
        }
    }
    else if (IsDesertRifle(active))
    {
        // Not zoomed: full auto.
        EmulateFullAuto(client, active, buttons);
        g_iLastClip[client] = GetEntProp(active, Prop_Send, "m_iClip1");
    }

    return Plugin_Continue;
}

public void Event_PlayerReset(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0)
    {
        ResetZoom(client);
    }
}

// The weapon the player is holding, or -1.
int GetActiveWeaponEnt(int client)
{
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (weapon <= MaxClients || !IsValidEntity(weapon))
    {
        return -1;
    }
    return weapon;
}

// True if the weapon in hand is in the zoom list and is the primary-slot weapon.
bool IsZoomableWeapon(int client)
{
    int weapon = GetActiveWeaponEnt(client);
    if (weapon == -1 || GetPlayerWeaponSlot(client, 0) != weapon)
    {
        return false;
    }

    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));

    for (int i = 0; i < sizeof(g_sZoomWeapons); i++)
    {
        if (StrEqual(classname, g_sZoomWeapons[i]))
        {
            return true;
        }
    }

    return false;
}

bool IsSG552(int weapon)
{
    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));
    return StrEqual(classname, "weapon_rifle_sg552");
}

bool IsDesertRifle(int weapon)
{
    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));
    return StrEqual(classname, "weapon_rifle_desert");
}

// True if the SG552's native zoom is active. Assumes m_iFOV drops below
// m_iDefaultFOV while zoomed. Unverified: test in-game.
bool IsSG552Zoomed(int client)
{
    int fov = GetEntProp(client, Prop_Send, "m_iFOV");
    int defFov = GetEntProp(client, Prop_Send, "m_iDefaultFOV");

    if (fov <= 0 || defFov <= 0)
    {
        return false;
    }

    return fov < defFov;
}

void ApplyZoom(int client, int fov)
{
    SetEntProp(client, Prop_Send, "m_iFOV", fov);
    SetEntProp(client, Prop_Send, "m_iDefaultFOV", fov);
    g_bZoomed[client] = true;

    // Start counting shots from the current clip so no false shot is seen.
    int active = GetActiveWeaponEnt(client);
    g_iBurstLeft[client] = 0;
    g_iLastClip[client] = (active != -1) ? GetEntProp(active, Prop_Send, "m_iClip1") : 0;
}

void ResetZoom(int client)
{
    if (client <= 0 || client > MaxClients)
    {
        return;
    }

    if (!IsClientInGame(client))
    {
        g_bZoomed[client] = false;
        g_iBurstLeft[client] = 0;
        return;
    }

    if (g_bZoomed[client])
    {
        // 0 returns the player to the default FOV.
        SetEntProp(client, Prop_Send, "m_iFOV", 0);
        SetEntProp(client, Prop_Send, "m_iDefaultFOV", 90);
    }

    g_bZoomed[client] = false;
    g_iBurstLeft[client] = 0;
}

// Fire BURST_SHOTS per burst while attack is held. After each burst, pause
// for BURST_COOLDOWN, then start the next burst if attack is still held.
void ProcessBurst(int client, int weapon, float interval)
{
    int clip = GetEntProp(weapon, Prop_Send, "m_iClip1");

    // Trigger released: stop any burst in progress.
    if ((GetClientButtons(client) & IN_ATTACK) == 0)
    {
        g_iBurstLeft[client] = 0;
        g_iLastClip[client] = clip;
        return;
    }

    // A shot was fired since the last tick.
    if (clip < g_iLastClip[client])
    {
        if (g_iBurstLeft[client] <= 0)
        {
            g_iBurstLeft[client] = BURST_SHOTS;
        }

        g_iBurstLeft[client]--;

        if (g_iBurstLeft[client] > 0)
        {
            // Space out the shots inside the burst.
            SetNextPrimaryAttack(weapon, interval);
        }
        else
        {
            // Burst done: pause, then the next burst starts while attack is held.
            SetNextPrimaryAttack(weapon, BURST_COOLDOWN);
        }
    }

    g_iLastClip[client] = clip;

    // Attack held and no burst in progress: arm a new burst.
    if (g_iBurstLeft[client] <= 0)
    {
        g_iBurstLeft[client] = BURST_SHOTS;
    }
}

// Full auto for the desert rifle when not zoomed. While attack is held and the
// weapon is ready, the attack bit is pressed on every other tick, so the game
// sees a new press each time and fires again.
void EmulateFullAuto(int client, int weapon, int &buttons)
{
    if ((GetClientButtons(client) & IN_ATTACK) == 0)
    {
        g_bAutoPulse[client] = false;
        return;
    }

    float nextAttack = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");
    if (nextAttack > GetGameTime())
    {
        // Still cooling down: hold the bit off so the next press registers.
        buttons &= ~IN_ATTACK;
        g_bAutoPulse[client] = false;
        return;
    }

    g_bAutoPulse[client] = !g_bAutoPulse[client];
    if (g_bAutoPulse[client])
    {
        buttons |= IN_ATTACK;
    }
    else
    {
        buttons &= ~IN_ATTACK;
    }
}

void SetNextPrimaryAttack(int weapon, float delay)
{
    SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + delay);
}

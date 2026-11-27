/**
 * L4D2 Ghost Climb
 *
 * Ghost-state Infected climb walls and props like a ladder while holding JUMP.
 * The ghost rises straight up while the wall is against it. When the wall face
 * ends, the ghost mantles: it keeps rising and moves over the top until it finds
 * a floor, then normal movement takes over. Releasing JUMP ends the climb.
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.7.4"

#define TEAM_INFECTED 3

// Entity flag for standing on the ground (FL_ONGROUND).
#define GHOST_FL_ONGROUND (1 << 0)

// Probe heights above the ghost's feet.
#define CHEST_HEIGHT 40.0
#define HEAD_HEIGHT  72.0

// A solid surface this close above the head means the ghost is indoors.
#define CEILING_CHECK 140.0

// Minimum distance from the wall face when a climb starts. Keeps the ghost's
// collision box clear of the wall so it never starts inside it.
#define WALL_MIN_GAP 14.0

// Extra reach past the stored wall distance, used while climbing.
#define WALL_HOLD_PAD 8.0

// The hint only shows when a climbable wall or prop is this close.
#define HINT_REACH 55.0

// Seconds before the hint can show again for the same player.
#define HINT_COOLDOWN 20.0

// Mantle: how far the ghost moves over the top per tick, and how many ticks it
// may spend looking for a floor before it gives up and falls.
#define MANTLE_FORWARD   4.0
#define MANTLE_MAX_TICKS 24

// Player-sized collision box used for sweeps. Slightly narrower than the real
// player box so the ghost does not catch on edges.
#define HULL_HALF 12.0
#define HULL_TOP  72.0

ConVar g_cvEnabled;
ConVar g_cvDistance;
ConVar g_cvSpeed;
ConVar g_cvMaxHeight;

bool  g_bClimbing[MAXPLAYERS + 1];
bool  g_bMantle[MAXPLAYERS + 1];
bool  g_bWallInView[MAXPLAYERS + 1];
float g_fHintReadyTime[MAXPLAYERS + 1];
int   g_iMantleTicks[MAXPLAYERS + 1];
float g_fGroundZ[MAXPLAYERS + 1];
float g_fWallDist[MAXPLAYERS + 1];
float g_fWallNormal[MAXPLAYERS + 1][3];

public Plugin myinfo =
{
	name        = "ghost_climber",
	author      = "Workik, RemiTheUnderAppreciated",
	description = "Ghost Infected climb walls and props like a ladder while holding jump",
	version     = PLUGIN_VERSION,
	url         = ""
};

public void OnPluginStart()
{
	g_cvEnabled   = CreateConVar("sm_ghostclimb_enable", "1", "Enable ghost wall climbing (1 = on, 0 = off).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvDistance  = CreateConVar("sm_ghostclimb_distance", "45.0", "How far ahead the ghost looks for a wall to climb.", FCVAR_NOTIFY, true, 10.0, true, 200.0);
	g_cvSpeed     = CreateConVar("sm_ghostclimb_speed", "300.0", "Climb speed in units per second.", FCVAR_NOTIFY, true, 50.0, true, 800.0);
	g_cvMaxHeight = CreateConVar("sm_ghostclimb_maxheight", "1000.0", "Most units a single climb can gain above the last ground height.", FCVAR_NOTIFY, true, 50.0, true, 2000.0);

	AutoExecConfig(true, "l4d2_ghost_climb");
}

public void OnMapStart()
{
	// Game time restarts with each map, so clear the cooldowns.
	for (int client = 1; client <= MaxClients; client++)
	{
		g_fHintReadyTime[client] = 0.0;
	}
}

public void OnClientDisconnect(int client)
{
	g_bClimbing[client] = false;
	g_bMantle[client] = false;
	g_bWallInView[client] = false;
	g_fHintReadyTime[client] = 0.0;
}

public void OnGameFrame()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsGhostInfected(client))
		{
			StopClimb(client);
			continue;
		}

		// Remember the last height the ghost stood on the ground at. The climb cap is
		// measured from here.
		if (!g_bClimbing[client] && (GetEntityFlags(client) & GHOST_FL_ONGROUND))
		{
			float groundPos[3];
			GetClientAbsOrigin(client, groundPos);
			g_fGroundZ[client] = groundPos[2];
		}

		// Show the hint each time a wall comes into view from outside. This runs
		// before the jump check, so the hint appears before the player presses jump.
		if (!g_bClimbing[client])
		{
			UpdateHint(client);
		}

		// Climbing needs JUMP held. Releasing it drops the ghost back to normal movement.
		if (!(GetClientButtons(client) & IN_JUMP))
		{
			StopClimb(client);
			continue;
		}

		if (g_bClimbing[client])
		{
			UpdateClimb(client);
		}
		else
		{
			TryStartClimb(client);
		}
	}
}

bool IsGhostInfected(int client)
{
	return g_cvEnabled.BoolValue
		&& client > 0
		&& client <= MaxClients
		&& IsClientInGame(client)
		&& !IsFakeClient(client)
		&& IsPlayerAlive(client)
		&& GetClientTeam(client) == TEAM_INFECTED
		&& GetEntProp(client, Prop_Send, "m_isGhost") == 1;
}

/**
 * Shows the climb hint whenever a climbable wall or prop comes into view from
 * outside. It fires on the transition from "no wall in view" to "wall in view",
 * so it does not repeat every frame while the ghost stays beside the wall.
 */
void UpdateHint(int client)
{
	bool nearWall = false;

	if (!IsIndoors(client))
	{
		float eyeAng[3], normal[3], dist;
		GetClientEyeAngles(client, eyeAng);
		nearWall = FindWall(client, eyeAng[1], HINT_REACH, normal, dist);
	}

	// Only fire when a wall newly comes within range, and never more often than the cooldown.
	// The state is updated either way, so staying beside a wall does not trigger it later.
	if (nearWall && !g_bWallInView[client] && GetGameTime() >= g_fHintReadyTime[client])
	{
		PrintHintText(client, "Hold jump to climb a wall or a prop when outside");
		g_fHintReadyTime[client] = GetGameTime() + HINT_COOLDOWN;
	}

	g_bWallInView[client] = nearWall;
}

/**
 * Starts a climb if a wall is in front of the ghost, the ghost is outside, and
 * there is room to hold position against the wall.
 */
void TryStartClimb(int client)
{
	if (IsIndoors(client))
	{
		return;
	}

	float eyeAng[3], normal[3], dist;
	GetClientEyeAngles(client, eyeAng);

	if (!FindWall(client, eyeAng[1], g_cvDistance.FloatValue, normal, dist))
	{
		return;
	}

	if (dist < WALL_MIN_GAP)
	{
		return;
	}

	g_fWallDist[client] = dist;
	for (int i = 0; i < 3; i++)
	{
		g_fWallNormal[client][i] = normal[i];
	}

	g_bClimbing[client] = true;
	g_bMantle[client] = false;
	g_iMantleTicks[client] = 0;
	SetEntityMoveType(client, MOVETYPE_FLY);

	RiseOneStep(client);
}

/**
 * One frame of an active climb. While the wall is against the ghost it rises.
 * When the wall face ends, it switches to mantling over the top.
 */
void UpdateClimb(int client)
{
	float origin[3];
	GetClientAbsOrigin(client, origin);

	if (origin[2] - g_fGroundZ[client] >= g_cvMaxHeight.FloatValue)
	{
		StopClimb(client);
		return;
	}

	if (!g_bMantle[client])
	{
		// Wall still against the ghost at chest height: keep rising.
		float dir[3], normal[3], dist;
		dir[0] = -g_fWallNormal[client][0];
		dir[1] = -g_fWallNormal[client][1];
		dir[2] = 0.0;
		NormalizeVector(dir, dir);

		if (ProbeFace(client, dir, CHEST_HEIGHT, g_fWallDist[client] + WALL_HOLD_PAD, normal, dist))
		{
			RiseOneStep(client);
			return;
		}

		// The wall face ended. Start mantling over the top.
		g_bMantle[client] = true;
		g_iMantleTicks[client] = 0;
	}

	MantleStep(client);
}

/**
 * One mantle tick: stop if the ghost is standing on a floor, otherwise rise and
 * move toward the top. Gives up after MANTLE_MAX_TICKS.
 */
void MantleStep(int client)
{
	float origin[3];
	GetClientAbsOrigin(client, origin);

	if (FloorBelow(origin))
	{
		// On top of the wall or prop: hand control back to normal movement.
		StopClimb(client);
		return;
	}

	g_iMantleTicks[client]++;
	if (g_iMantleTicks[client] > MANTLE_MAX_TICKS)
	{
		StopClimb(client);
		return;
	}

	float step = g_cvSpeed.FloatValue * GetTickInterval();

	// Rise first, then nudge over the top. The top is on the far side of the
	// face, which is the direction opposite the wall normal.
	float up[3], upDest[3];
	up[0] = origin[0];
	up[1] = origin[1];
	up[2] = origin[2] + step;

	if (!HullMoveTo(origin, up, upDest))
	{
		// Blocked overhead: nothing more can be done.
		StopClimb(client);
		return;
	}

	float over[3], overDest[3], zero[3];
	over[0] = upDest[0] - g_fWallNormal[client][0] * MANTLE_FORWARD;
	over[1] = upDest[1] - g_fWallNormal[client][1] * MANTLE_FORWARD;
	over[2] = upDest[2];

	if (HullMoveTo(upDest, over, overDest))
	{
		TeleportEntity(client, overDest, NULL_VECTOR, zero);
	}
	else
	{
		// Still beside the face: rise only, and try the forward move next tick.
		TeleportEntity(client, upDest, NULL_VECTOR, zero);
	}
}

/**
 * Moves the ghost straight up by one climb step. It stops early if something
 * overhead blocks it. It never moves horizontally.
 */
void RiseOneStep(int client)
{
	float origin[3], target[3], dest[3], zero[3];
	GetClientAbsOrigin(client, origin);

	float step = g_cvSpeed.FloatValue * GetTickInterval();

	target[0] = origin[0];
	target[1] = origin[1];
	target[2] = origin[2] + step;

	if (!HullMoveTo(origin, target, dest))
	{
		// Blocked overhead, or starting inside geometry. Hold position.
		return;
	}

	TeleportEntity(client, dest, NULL_VECTOR, zero);
}

/**
 * True if there is a walkable floor directly under the ghost's feet.
 */
bool FloorBelow(const float origin[3])
{
	float start[3], end[3];
	start[0] = origin[0];
	start[1] = origin[1];
	start[2] = origin[2] + 2.0;
	end[0] = origin[0];
	end[1] = origin[1];
	end[2] = origin[2] - 6.0;

	Handle trace = TR_TraceRayFilterEx(start, end, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilterIgnorePlayers);
	bool floor = false;

	if (TR_DidHit(trace) && !TR_StartSolid(trace))
	{
		float n[3];
		TR_GetPlaneNormal(trace, n);
		floor = n[2] >= 0.7;
	}

	delete trace;
	return floor;
}

/**
 * True if a solid surface is directly above the ghost.
 */
bool IsIndoors(int client)
{
	float origin[3], start[3], end[3];
	GetClientAbsOrigin(client, origin);

	start[0] = origin[0];
	start[1] = origin[1];
	start[2] = origin[2] + HEAD_HEIGHT;
	end[0] = start[0];
	end[1] = start[1];
	end[2] = start[2] + CEILING_CHECK;

	Handle trace = TR_TraceRayFilterEx(start, end, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilterIgnorePlayers);
	bool blocked = TR_DidHit(trace) && !TR_StartSolid(trace);
	delete trace;

	return blocked;
}

/**
 * Looks for a wall straight ahead or 30 degrees either side of the view. The
 * wall must be solid at chest and head height.
 */
bool FindWall(int client, float yaw, float reach, float normal[3], float &dist)
{
	static const float offsets[] = { 0.0, 30.0, -30.0 };

	for (int i = 0; i < sizeof(offsets); i++)
	{
		float dir[3], right[3];
		YawVectors(yaw + offsets[i], dir, right);

		if (ProbeFace(client, dir, CHEST_HEIGHT, reach, normal, dist)
			&& ProbeFace(client, dir, HEAD_HEIGHT, reach, normal, dist))
		{
			return true;
		}
	}

	return false;
}

/**
 * Traces horizontally at the given height in direction dir. Returns true when
 * it hits a near-vertical surface. Writes the horizontal normal (pointing back
 * toward the ghost) and the horizontal distance to the hit.
 */
bool ProbeFace(int client, const float dir[3], float height, float reach, float normal[3], float &dist)
{
	float origin[3];
	GetClientAbsOrigin(client, origin);

	float start[3], end[3];
	start[0] = origin[0];
	start[1] = origin[1];
	start[2] = origin[2] + height;
	end[0] = start[0] + dir[0] * reach;
	end[1] = start[1] + dir[1] * reach;
	end[2] = start[2];

	Handle trace = TR_TraceRayFilterEx(start, end, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilterIgnorePlayers);
	bool found = false;

	if (TR_DidHit(trace) && !TR_StartSolid(trace))
	{
		float n[3], p[3];
		TR_GetPlaneNormal(trace, n);
		TR_GetEndPosition(p, trace);

		if (FloatAbs(n[2]) < 0.5)
		{
			n[2] = 0.0;
			NormalizeVector(n, n);
			normal[0] = n[0];
			normal[1] = n[1];
			normal[2] = 0.0;

			float dx = p[0] - origin[0];
			float dy = p[1] - origin[1];
			dist = SquareRoot(dx * dx + dy * dy);
			found = true;
		}
	}

	delete trace;
	return found;
}

/**
 * Horizontal unit vectors for a yaw.
 */
void YawVectors(float yaw, float fwd[3], float right[3])
{
	float ang[3];
	ang[0] = 0.0;
	ang[1] = yaw;
	ang[2] = 0.0;
	GetAngleVectors(ang, fwd, right, NULL_VECTOR);
	fwd[2] = 0.0;
	right[2] = 0.0;
	NormalizeVector(fwd, fwd);
	NormalizeVector(right, right);
}

/**
 * Sweeps the ghost's box from 'from' to 'to'. Writes the end position to 'dest'.
 * Returns false if the ghost starts inside solid geometry or the path is blocked.
 */
bool HullMoveTo(const float from[3], const float to[3], float dest[3])
{
	float mins[3], maxs[3];
	mins[0] = -HULL_HALF;
	mins[1] = -HULL_HALF;
	mins[2] = 0.0;
	maxs[0] = HULL_HALF;
	maxs[1] = HULL_HALF;
	maxs[2] = HULL_TOP;

	Handle trace = TR_TraceHullFilterEx(from, to, mins, maxs, MASK_PLAYERSOLID, TraceFilterIgnorePlayers);
	bool ok = false;

	if (TR_StartSolid(trace))
	{
		ok = false;
	}
	else if (TR_DidHit(trace))
	{
		// Blocked partway: report failure and leave dest at the obstacle.
		TR_GetEndPosition(dest, trace);
		ok = false;
	}
	else
	{
		dest[0] = to[0];
		dest[1] = to[1];
		dest[2] = to[2];
		ok = true;
	}

	delete trace;
	return ok;
}

void StopClimb(int client)
{
	g_bMantle[client] = false;
	g_iMantleTicks[client] = 0;

	if (g_bClimbing[client])
	{
		g_bClimbing[client] = false;

		if (client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client))
		{
			SetEntityMoveType(client, MOVETYPE_WALK);
		}
	}
}

/**
 * Hit world geometry (entity 0) and props, but not players.
 * Returning true means "this entity counts as a hit".
 */
public bool TraceFilterIgnorePlayers(int entity, int contentsMask)
{
	return entity == 0 || entity > MaxClients;
}

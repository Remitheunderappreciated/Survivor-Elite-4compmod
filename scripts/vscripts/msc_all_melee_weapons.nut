printl("Survivor Elite Melee weapon controller active")

// Add a global reference to the controller.
if(!("g_WeaponController" in getroottable()))
{
	::g_WeaponController <- this 
}

function SetMeleeWeapons()
{
	local tempEnt = null

	local weaponList = []

	while (tempEnt=Entities.Next(tempEnt))
	{
		if (tempEnt!=null && tempEnt.IsValid())
		{
			local entClassname = tempEnt.GetClassname()
			if (entClassname=="weapon_melee_spawn")
			{
				local pos = tempEnt.GetOrigin()
				local rot = tempEnt.GetAngles()
				DoEntFire("!self", "kill", "", 0.0, tempEnt, tempEnt)
				weaponList.push(tempEnt)
			}
		}
	}

	local index = 0
	local maxIndex = weaponList.len()
	while (index<maxIndex)
	{
		tempEnt = weaponList[index]
		local pos = tempEnt.GetOrigin()
		local rot = tempEnt.GetAngles()
		DoEntFire("!self", "kill", "", 0.0, tempEnt, tempEnt)
		MeleeSpawn(tempEnt, pos, rot)
		index+=1
	}
}

function MeleeSpawn(ent, Position, Rotation)
{
	local spawnFlags = NetProps.GetPropInt(ent, "m_spawnflags")

	local flags = 2

	if (spawnFlags & 1)
	{
		flags=flags|1
	}

	local entTable =
	{
		classname = "weapon_melee_spawn"
		count = 1
		angles = Rotation
		origin = Position
		solid = 6
		melee_weapon = "fireaxe,frying_pan,machete,baseball_bat,crowbar,cricket_bat,tonfa,katana,electric_guitar,knife,golfclub,riotshield,shovel,pitchfork"
//		melee_weapon = "fireaxe,frying_pan,machete,baseball_bat,crowbar,cricket_bat,tonfa,katana,electric_guitar,knife,golfclub,riotshield,shovel,pitchfork,flamethrower,barnacle,m72law,syringe_gun,bow,custom_shotgun,sentry,laser_pistol"
//		melee_weapon = "knife" // For debug.
		spawnflags = flags
	}
	
	local newEnt = g_ModeScript.CreateSingleSimpleEntityFromTable(entTable)

	if (newEnt.GetModelName()=="models/weapons/melee/w_crowbar.mdl")
	{
		local randNum = (rand() % 5)
		
		if (randNum == 0)
		{
			DoEntFire("!self", "addoutput", "weaponskin 1", 0.1, newEnt, newEnt)
			DoEntFire("!self", "skin", "1", 0.1, newEnt, newEnt)
		}
	}

	newEnt.SetOrigin(Position)
	newEnt.SetAngles(Rotation)
}

function OnGameEvent_round_start( params )
{
	SetMeleeWeapons()
	ReplaceAmmo()
	ReplaceLaser()
	ReplaceMeleeSpawns()
}

__CollectEventCallbacks(this, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener)
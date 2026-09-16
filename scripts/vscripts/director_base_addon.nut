printl("Survivor Elite Overhaul for Versus is now running. Author: Ɽǝϻɨ");

::nes_spit_fix <- {
	bugged_ents = {
	    prop_physics = 0,
	    prop_dynamic = 0
	}

	function OnGameEvent_spit_burst(p) {
	    local projectile = null;
	    local spitter = GetPlayerFromUserID(p.userid);
	    while(projectile = Entities.FindByClassname(projectile, "spitter_projectile")) {
	        if(NetProps.GetPropEntity(projectile, "m_hThrower") == spitter) {
	            break;
	        }
	    }
	    if(projectile == null) {
	        return;
	    }

	    local swarm = EntIndexToHScript(p.subject);
	    local projectile_pos = projectile.GetOrigin();

	    local trace = {
	        start = swarm.GetOrigin(),
	        end = projectile_pos,
	        mask = DirectorScript.TRACE_MASK_SHOT,
	        ignore = projectile
	    }

	    TraceLine(trace);
	    if("enthit" in trace && trace.enthit.GetClassname() in bugged_ents) {
	        swarm.SetOrigin(projectile_pos);
	    }
	}
}

__CollectGameEventCallbacks(nes_spit_fix);

ChCh_GasPourTrap <-
{
    Settings = {
        FireDuration = Convars.GetFloat("inferno_flame_lifetime"),
        TotalGasUses = 3,
        FlameDamage = 150,
    }

    function OnGameEvent_round_start( params )
    {
        local puddlethinker = SpawnEntityFromTable("info_target", {targetname = "ChCh_GasPourThinker"} )
        if( puddlethinker.ValidateScriptScope() )
        {
        	puddlethinker.GetScriptScope()["Think"] <- function()
        	{
        		DirectorScript.ChCh_GasPourTrap.Thinkorz()
                return 0.2
        	}
        	AddThinkToEnt(puddlethinker, "Think")
        }
    }

    function OnGameEvent_bullet_impact( params )
    {
    	if("userid" in params)
        {
            if(params.userid)
            {
                local player = GetPlayerFromUserID(params.userid)
                local spothit = Vector(params.x, params.y, params.z)

                FindPuddlesToAlight(spothit, 192)
            }
        }
    }

    function Thinkorz()
    {
        for (local foire; foire = Entities.FindByClassname(foire, "env_fire"); )
        {
            FindPuddlesToAlight(foire.GetOrigin(), 192)
        }

        for (local de_inferno; de_inferno = Entities.FindByClassname(de_inferno, "inferno"); )
        {
            FindPuddlesToAlight(de_inferno.GetOrigin(), 300)
        }

        for (local puddles; puddles = Entities.FindByName(puddles, "ChCh_GasPuddle"); )
        {
            local flame = GetVariableFrom(puddles, "ChCh_GasPour_Flame")
            if(flame != null)
            {
                if(Time() - GetVariableFrom(puddles, "ChCh_GasPour_AlightTime") >= Settings.FireDuration)
                {
                    flame.Kill()
                    puddles.Kill()
                    GetVariableFrom(puddles, "ChCh_GasPour_FlameTrigger").Kill()
                    GetVariableFrom(puddles, "ChCh_GasPour_FlameSound").Kill()
                }
            }
        }

        for (local player; player = Entities.FindByClassname(player, "player"); )
        {
            if(player.IsSurvivor() && NetProps.GetPropInt(player, "m_lifeState") == 0 && !IsPlayerABot(player))
            {
                local wep = player.GetActiveWeapon()
                if(wep)
                {
                    if(wep.GetClassname() == "weapon_gascan")
                    {
                        //printl(player.GetButtonMask())
                        if(!player.IsIncapacitated() && !player.IsDominatedBySpecialInfected() && (player.GetButtonMask() == (player.GetButtonMask() | 8192)) && GetVariableFrom(player, "ChCh_GasPouring") != 1)
                        {
                            EnactPourStart(player)
                        }
                    }
                }
            }
        }
    }

    function EnactPourStart(player)
    {
		NetProps.SetPropIntArray(player, "m_NetGestureSequence", player.LookupSequence("ACT_TERROR_USE_GAS_CAN"), 6);
	    NetProps.SetPropIntArray(player, "m_NetGestureActivity", player.LookupActivity("ACT_TERROR_USE_GAS_CAN"), 6);
	    NetProps.SetPropFloatArray(player, "m_NetGestureStartTime", Time(), 6);

        SetVariableOn(player, "ChCh_GasPouring", 1)

        local timetoworkit = player.IsAdrenalineActive() == 0 ? Convars.GetFloat("gas_can_use_duration") : Convars.GetFloat("gas_can_use_duration") * Convars.GetFloat("adrenaline_backpack_speedup")

        NetProps.SetPropFloat(player, "m_TimeForceExternalView", Time() + timetoworkit)
        NetProps.SetPropInt(player, "m_fFlags", NetProps.GetPropInt(player, "m_fFlags") | (1 << 5))
        EmitSoundOn("Player.UsingGasCan", player)

        EntFire("worldspawn", "runscriptcode", "DirectorScript.ChCh_GasPourTrap.FinishUpPour(GetPlayerFromUserID(" + player.GetPlayerUserId() + "))", timetoworkit, null)
    }

    function FinishUpPour(player)
    {
        local gas = player.GetActiveWeapon()
        SetVariableOn(gas, "ChCh_GasUses", GetVariableFromGas(gas, "ChCh_GasUses") + 1)

        if(GetVariableFromGas(gas, "ChCh_GasUses") >= Settings.TotalGasUses)
        {
            local gaspour = Entities.FindByClassname(null, "point_prop_use_target")
            if(NetProps.GetPropInt(gaspour, "m_spawnflags") != 1)
            {
                gas.Kill()
            }
        }

        StopSoundOn("Player.UsingGasCan", player)
        EmitSoundOn("Player.UsingGasCanStop", player)

        SpawnPuddle(player)
        NetProps.SetPropInt(player, "m_fFlags", NetProps.GetPropInt(player, "m_fFlags") & ~(1 << 5))
        SetVariableOn(player, "ChCh_GasPouring", 0)
    }

    function SpawnPuddle(player)
    {
        SpawnEntityFromTable("prop_dynamic", { origin = player.GetOrigin(), angles = "0 " + RandomInt(0,360) + " 0", model = "models/effects/urban_puddle_model03a.mdl", fademindist = -1, fademaxdist = 0, solid = 0, disableshadows = 1, rendercolor = "0 0 0", targetname = "ChCh_GasPuddle" })
    }

    function FindPuddlesToAlight(spot, range)
    {
        for (local puddle; puddle = Entities.FindByClassnameWithin(puddle, "prop_dynamic", spot, range); )
        {
            if(puddle.GetName() == "ChCh_GasPuddle")
            {
                if(GetVariableFrom(puddle, "ChCh_GasPour_Flame") == null)
                {
                    AlightPuddle(puddle)
                }
            }
        }
    }

    function AlightPuddle(puddle)
    {
        //local fireahhh = SpawnEntityFromTable("env_fire", { origin = puddle.GetOrigin(), angles = "0 " + RandomInt(0,360) + " 0", damagescale = 1, fireattack = 2, firesize = 192, health = 30, ignitionpoint = 32, spawnflags = 133 })
        local fireparticle = SpawnEntityFromTable("info_particle_system", { origin = puddle.GetOrigin(), angles = "0 " + RandomInt(0,360) + " 0", effect_name = "fire_large_01", start_active = 1 })
        local firetrigger = SpawnEntityFromTable("script_trigger_hurt", { origin = puddle.GetOrigin() + Vector(0, 48, 0), angles = "0 0 0", extent = "82 82 48", damage = Settings.FlameDamage, damagetype = 8, spawnflags = 75 })
        local firesound = SpawnEntityFromTable("ambient_generic", { origin = puddle.GetOrigin(), spawnflags = 1, message = "c1m1.Fireloop0" + RandomInt(1,3).tostring(), radius = 10000, pitch = "100", pitchstart = "100", health = 10  } )
        SetVariableOn(puddle, "ChCh_GasPour_AlightTime", Time())
        SetVariableOn(puddle, "ChCh_GasPour_Flame", fireparticle)
        SetVariableOn(puddle, "ChCh_GasPour_FlameTrigger", firetrigger)
        SetVariableOn(puddle, "ChCh_GasPour_FlameSound", firesound)

        EmitSoundOn("Inferno.Fire.Ignite", puddle)
        //c1m1.Fireloop01 - 3
    }

    function SetVariableOn(whom, var, val)
    {
        if(whom.ValidateScriptScope())
        {
            if(var in whom.GetScriptScope())
            {
                if(whom.GetScriptScope()[var] != val)
                {
                    whom.GetScriptScope()[var] = val
                }
            }
            else
            {
                whom.GetScriptScope()[var] <- val
            }
        }
    }

    function GetVariableFrom(whom, var)
    {
        if(whom.ValidateScriptScope())
        {
            if(var in whom.GetScriptScope())
            {
                return whom.GetScriptScope()[var]
            }
            else
            {
                return null
            }
        }
    }

    function GetVariableFromGas(whom, var)
    {
        if(whom.ValidateScriptScope())
        {
            if(var in whom.GetScriptScope())
            {
                return whom.GetScriptScope()[var]
            }
            else
            {
                return 0
            }
        }
    }

    function ParseSettings()
    {
        local SettingsFileName = "pour_gas_traps/Settings.cfg"
        local file = FileToString(SettingsFileName)
    
        local tData;
        local function SerializeSettings() {
            local sData = "{"
            foreach (key, val in Settings) {
                if (type(val) == "string") {
                    val = "\"" + val + "\""
                } else if (type(val) == "array") {
                    local newValue = "["
                    for (local i = 0; i < val.len(); i++) {
                        if (type(val[i]) == "string") {
                            newValue += "\"" + val[i] + "\""
                        } else {
                            newValue += val[i].tostring()
                        }
                        if (i < val.len() - 1) {
                            newValue += ", "
                        }
                    }
                    newValue += "]"
                    val = newValue
                }
                sData += "\n\t" + key + " = " + val
            }
            sData += "\n}"
            StringToFile(SettingsFileName, sData)
        }
        if (tData = file){
            try {
                tData = compilestring("return " + tData)()
                local hasMissingKey = false
                foreach (key, val in Settings){
                    if (key in tData){
                        Settings[key] = tData[key]
                    }
                    else if (!hasMissingKey){
                        hasMissingKey = true 
                    }
                }
                if (hasMissingKey)
                { SerializeSettings() }
            }
            catch (error) {
                SerializeSettings()
            }
        }
        else{
            SerializeSettings();
        }
    }
}

__CollectGameEventCallbacks(ChCh_GasPourTrap);
ChCh_GasPourTrap.ParseSettings()

if ( "__vslu_init_scmp_hooks" in getroottable() )
    ::__vslu_init_scmp_hooks();

if ( !("VSLU" in getroottable()) )
{
    if ( Entities.FindByName(null, "__missing_vslu_think_ent") == null )
    {
        local hThinkEntity = SpawnEntityFromTable("info_target", { targetname = "__missing_vslu_think_ent" });

        if ( hThinkEntity && hThinkEntity.ValidateScriptScope() )
        {
            hThinkEntity.GetScriptScope()["last_think"] <- 0.0;
            hThinkEntity.GetScriptScope()["think_interval"] <- RandomFloat(5.0, 25.0);

            hThinkEntity.GetScriptScope()["Think"] <- function()
            {
                if ( self.GetScriptScope()["last_think"] <= Time() )
                {
                    ClientPrint(null, 3, "\x04" + "[Bridge Destruction] " + "\x03" + "vslu");
                    ClientPrint(null, 3, "\x03" + "vslu");

                    self.GetScriptScope()["last_think"] = Time() + self.GetScriptScope()["think_interval"];
                }
            }

            AddThinkToEnt( hThinkEntity, "Think" );
        }
    }

    return;
}

if ( !("VSLU" in getroottable()) )
{
    if ( Entities.FindByName(null, "__missing_vslu_think_ent") == null )
    {
        local hThinkEntity = SpawnEntityFromTable("info_target", { targetname = "__missing_vslu_think_ent" });

        if ( hThinkEntity && hThinkEntity.ValidateScriptScope() )
        {
            hThinkEntity.GetScriptScope()["last_think"] <- 0.0;
            hThinkEntity.GetScriptScope()["think_interval"] <- RandomFloat(5.0, 25.0);

            hThinkEntity.GetScriptScope()["Think"] <- function()
            {
                if ( self.GetScriptScope()["last_think"] <= Time() )
                {
                    ClientPrint(null, 3, "\x04" + "[Gas Station Explosion] " + "\x03" + "vslu");
                    ClientPrint(null, 3, "\x03" + "vslu");

                    self.GetScriptScope()["last_think"] = Time() + self.GetScriptScope()["think_interval"];
                }
            }

            AddThinkToEnt( hThinkEntity, "Think" );
        }
    }

    return;
}

if ( !("VSLU" in getroottable()) )
{
    if ( Entities.FindByName(null, "__missing_vslu_think_ent") == null )
    {
        local hThinkEntity = SpawnEntityFromTable("info_target", { targetname = "__missing_vslu_think_ent" });

        if ( hThinkEntity && hThinkEntity.ValidateScriptScope() )
        {
            hThinkEntity.GetScriptScope()["last_think"] <- 0.0;
            hThinkEntity.GetScriptScope()["think_interval"] <- RandomFloat(5.0, 25.0);

            hThinkEntity.GetScriptScope()["Think"] <- function()
            {
                if ( self.GetScriptScope()["last_think"] <= Time() )
                {
                    ClientPrint(null, 3, "\x04" + "[Plane Crash] " + "\x03" + "vslu");
                    ClientPrint(null, 3, "\x03" + "vslu");

                    self.GetScriptScope()["last_think"] = Time() + self.GetScriptScope()["think_interval"];
                }
            }

            AddThinkToEnt( hThinkEntity, "Think" );
        }
    }

    return;
}
::WhitakerCoverFire <- {}
function WhitakerCoverFire::OnGameEvent_player_death( params )
{
	if ( Director.GetMapName() != "c1m2_streets" )
		return;
	if( params.weapon == "env_weaponfire" )
	{
		local orator; orator = Entities.FindByName( orator, "orator" ); 
		QueueSpeak( orator, "DefendChatter", 0.5, "" );
	}
}

function WhitakerCoverFire::OnGameEvent_round_start_post_nav( params )
{
   if ( Director.GetMapName() != "c1m2_streets" )
		return;

	SpawnEntityFromTable("env_weaponfire", {
		targetname = "whit_cover"
		TargetArc = "90"
		TargetRange = "1500"
		DamageMod = "1.5"
		WeaponType = "2"
		TargetTeam = "3"
		IgnorePlayers = "1"
		origin = Vector(-5424, -1763, 830)
		angles = Vector(24, 179, 0)
		StartDisabled = "1"
	})
			
	EntFire("store_alarm_relay", "AddOutput", "OnTrigger whitaker_door:open::3.7:-1" );
	EntFire("store_alarm_relay", "AddOutput", "OnTrigger whit_cover:enable::3.7:-1" );
	//EntFire("store_alarm_relay", "AddOutput", "OnTrigger whitaker:enable::3.7:-1" );
	EntFire("store_alarm_relay", "AddOutput", "OnTrigger orator:SpeakResponseConcept:C1M2AlarmDoorCover:3.7:-1" );
	//EntFire("store_alarm_relay", "AddOutput", "OnTrigger !activator:SpeakResponseConcept:C1M2AlarmDoor2 WhoDidIt:!Activator:0:-1" );
	//EntFire("store_alarm_relay", "RemoveOutput", "OnTrigger !activator:SpeakResponseConcept:C1M2AlarmDoor WhoDidIt:!Activator:0:-1" );
	
	EntFire("gunshop_button_relay", "AddOutput", "OnTrigger whitaker_door:close::0,1:-1" );
	EntFire("gunshop_button_relay", "AddOutput", "OnTrigger whit_cover:disable::0,1:-1" );
	
	
	local worldspawn = Entities.First();
	local soundScripts =
	[
		"Whitaker_ComeUpstairsLongerB04",    "Whitaker_ComeUpstairsLongerD04",
		"Whitaker_ComeUpstairsLongerD07",      "Whitaker_DefendChatter03",
		"Whitaker_DefendChatter04",   "Whitaker_DefendChatter05",   "Whitaker_DefendChatter06",
		"Whitaker_DefendChatter07",   "Whitaker_DefendChatter18"
	];
	foreach( soundscript in soundScripts ) {
		worldspawn.PrecacheScriptSound( soundscript );
	}

}

__CollectGameEventCallbacks(WhitakerCoverFire);

local function IsNotSaidCommentProtect(query)
{
    local newquery = {}
    foreach(key, val in query){
        newquery.rawset(key.tolower(), val)}

    if("worldsaidcommentprotect" in newquery){
        if(newquery.worldsaidcommentprotect.tointeger() != 1)
            return true
        else
            return false
    }
    else
        return true
}

local function IsTalk(query)
{
    local newquery = {}
    foreach(key, val in query){
        newquery.rawset(key.tolower(), val)}

    if("worldtalk" in newquery){
        if(newquery.worldtalk.tointeger() != 1)
            return true
        else
            return false
    }
    else
        return true
}

IncludeScript("response_testbed", this)
local newrules =
[

	//The Following are stubs to mute certain lines
	{ name = "ConceptC1M2StoreAlarmStub",
		criteria =
		[
			[ "concept", "C1M2StoreAlarm" ],
			[ "name", "orator" ],
		],
		responses =
		[
            {   scenename = "scenes/npcs/orator_blank.vcd"	} // Stub
		],
		group_params = g_rr.RGroupParams({})
	},
	
	{ name = "ConceptC1M2WhitakerErrandInProgressStub",
		criteria =
		[
			[ "concept", "C1M2WhitakerErrandInProgress" ],
			[ "name", "orator" ],
		],
		responses =
		[
            {   scenename = "scenes/npcs/orator_blank.vcd"	} // Stub
		],
		group_params = g_rr.RGroupParams({})
	},
	
	{ name = "NPCC1M2WhitakerPutColaStub",
		criteria =
		[
			[ "concept", "whitakerputcola" ],
			[ "name", "orator" ],
			[ IsTalk ],
		],
		responses =
		[
            {   scenename = "scenes/npcs/Whitaker_MissionCompleted01.vcd", applycontexttoworld = true, applycontext = {context = "Talk", value = 1, duration = 5}  }  //Put the cola in the slot.
            {   scenename = "scenes/npcs/Whitaker_MissionCompleted02.vcd", applycontexttoworld = true, applycontext = {context = "Talk", value = 1, duration = 5}  }  //Put the cola in the slot.
            {   scenename = "scenes/npcs/Whitaker_MissionCompleted03.vcd", applycontexttoworld = true, applycontext = {context = "Talk", value = 1, duration = 5}  }  //You got the cola. Put it in the slot.
            {   scenename = "scenes/npcs/Whitaker_MissionCompleted04.vcd", applycontexttoworld = true, applycontext = {context = "Talk", value = 1, duration = 5}  }  //There's my cola. Quick, put it in the slot.
            {   scenename = "scenes/npcs/Whitaker_MissionCompleted05.vcd", applycontexttoworld = true, applycontext = {context = "Talk", value = 1, duration = 5}  }  //Yeah, put it in the damn slot.
            {   scenename = "scenes/npcs/Whitaker_MissionCompleted13.vcd", applycontexttoworld = true, applycontext = {context = "Talk", value = 1, duration = 5}  }  //Hey, put the cola in the slot.
            {   scenename = "scenes/npcs/Whitaker_MissionCompleted14.vcd", applycontexttoworld = true, applycontext = {context = "Talk", value = 1, duration = 5}  }  //Put the cola in the slot, will ya?
            {   scenename = "scenes/npcs/Whitaker_MissionCompleted15.vcd", applycontexttoworld = true, applycontext = {context = "Talk", value = 1, duration = 5}  }  //Okay, that's my cola. Yes, yes. Put it in the slot!
		],
		group_params = g_rr.RGroupParams({})
	},
	
	{ name = "PlayerC1M2AlarmDoor2Whitaker",
		criteria =
		[
			[ "concept", "C1M2AlarmDoorCover" ],
			[ "name", "orator" ],
		],
		responses =
		[
            {   scenename = "scenes/npcs/whitaker_defendchatter03.vcd", applycontexttoworld = true, applycontext = {context1 = {context = "SaidCommentProtect", value = "1", duration = 5},context2 = {context = "Talk", value = "1", duration = 5}} }
            {   scenename = "scenes/npcs/whitaker_defendchatter04.vcd", applycontexttoworld = true, applycontext = {context1 = {context = "SaidCommentProtect", value = "1", duration = 5},context2 = {context = "Talk", value = "1", duration = 5}} }
            {   scenename = "scenes/npcs/whitaker_defendchatter05.vcd", applycontexttoworld = true, applycontext = {context1 = {context = "SaidCommentProtect", value = "1", duration = 5},context2 = {context = "Talk", value = "1", duration = 5}} }
            {   scenename = "scenes/npcs/whitaker_defendchatter07.vcd", applycontexttoworld = true, applycontext = {context1 = {context = "SaidCommentProtect", value = "1", duration = 5},context2 = {context = "Talk", value = "1", duration = 5}} }
            //{   scenename = "scenes/npcs/whitaker_defendchatter03.vcd", applycontexttoworld = true, applycontext = {context = "SaidCommentProtect", value = 1, duration = 5}  }
            //{   scenename = "scenes/npcs/whitaker_defendchatter04.vcd", applycontexttoworld = true, applycontext = {context = "SaidCommentProtect", value = 1, duration = 5}  }
            //{   scenename = "scenes/npcs/whitaker_defendchatter05.vcd", applycontexttoworld = true, applycontext = {context = "SaidCommentProtect", value = 1, duration = 5}  }
            //{   scenename = "scenes/npcs/whitaker_defendchatter07.vcd", applycontexttoworld = true, applycontext = {context = "SaidCommentProtect", value = 1, duration = 5}  }
		],
		group_params = g_rr.RGroupParams({})
	},
	
	{ name = "WhitakerDefendChatterShort",
		criteria =
		[
			[ "concept", "DefendChatter" ],
			[ "name", "orator" ],
			[ "randomnum", 0,75 ],
			[ IsNotSaidCommentProtect ],
			[ IsTalk ],
		],
		responses =
		[
            {   scenename = "scenes/npcs/whitaker_defendchatter06.vcd", applycontexttoworld = true, applycontext = {context1 = {context = "SaidCommentProtect", value = "1", duration = 5},context2 = {context = "Talk", value = "1", duration = 8}} }
            {   scenename = "scenes/npcs/whitaker_defendchatter06.vcd", applycontexttoworld = true, applycontext = {context1 = {context = "SaidCommentProtect", value = "1", duration = 5},context2 = {context = "Talk", value = "1", duration = 8}} }
            {   scenename = "scenes/npcs/whitaker_defendchatter18.vcd", applycontexttoworld = true, applycontext = {context1 = {context = "SaidCommentProtect", value = "1", duration = 5},context2 = {context = "Talk", value = "1", duration = 8}} }
            {   scenename = "scenes/npcs/whitaker_defendchatter18.vcd", applycontexttoworld = true, applycontext = {context1 = {context = "SaidCommentProtect", value = "1", duration = 5},context2 = {context = "Talk", value = "1", duration = 8}} }
		],
		group_params = g_rr.RGroupParams({})
	},
	
	{ name = "WhitakerDefendChatterNag",
		criteria =
		[
			[ "concept", "DefendChatter" ],
			[ "name", "orator" ],
			[ "randomnum", 0,25 ],
			[ IsNotSaidCommentProtect ],
			[ IsTalk ],
		],
		responses =
		[
            {   scenename = "scenes/npcs/whitaker_defendchatter05.vcd", applycontexttoworld = true, applycontext = {context1 = {context = "SaidCommentProtect", value = "1", duration = 5},context2 = {context = "Talk", value = "1", duration = 10}} }
            {   scenename = "scenes/npcs/whitaker_defendchatter07.vcd", applycontexttoworld = true, applycontext = {context1 = {context = "SaidCommentProtect", value = "1", duration = 5},context2 = {context = "Talk", value = "1", duration = 10}} }
		],
		group_params = g_rr.RGroupParams({})
	},
	
	{ name = "WhitakerDefendChatterRare",
		criteria =
		[
			[ "concept", "DefendChatter" ],
			[ "name", "orator" ],
			[ "randomnum", 0,15 ],
			[ IsNotSaidCommentProtect ],
			[ IsTalk ],
		],
		responses =
		[
            {   scenename = "scenes/npcs/whitaker_comeupstairslongerb04.vcd", applycontexttoworld = true, applycontext = {context1 = {context = "SaidCommentProtect", value = "1", duration = 5},context2 = {context = "Talk", value = "1", duration = 10}} }
            {   scenename = "scenes/npcs/whitaker_comeupstairslongerd04.vcd", applycontexttoworld = true, applycontext = {context1 = {context = "SaidCommentProtect", value = "1", duration = 5},context2 = {context = "Talk", value = "1", duration = 10}} }
            {   scenename = "scenes/npcs/whitaker_comeupstairslongerd07.vcd", applycontexttoworld = true, applycontext = {context1 = {context = "SaidCommentProtect", value = "1", duration = 5},context2 = {context = "Talk", value = "1", duration = 10}} }
		],
		group_params = g_rr.RGroupParams({})
	},
]

g_rr.rr_ProcessRules( newrules );

IncludeScript( "plane_crash", getroottable() );

IncludeScript( "gas_station_explosion", getroottable() );

IncludeScript( "bridge_destruction", getroottable() );

IncludeScript("grenade_shove", getroottable());

IncludeScript("meleedrop")

IncludeScript("itemExFunc")

IncludeScript("custom_tank_health");

IncludeScript("survivorshoving")

IncludeScript("fire_spreads_geeb");
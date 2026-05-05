printl("Survivor Elite Overhaul for Versus is now running. Author: Ɽǝϻɨ");

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

IncludeScript( "plane_crash", getroottable() );

IncludeScript( "gas_station_explosion", getroottable() );

IncludeScript( "bridge_destruction", getroottable() );

IncludeScript("bile_survivors", getroottable());

IncludeScript("grenade_shove", getroottable());

IncludeScript("meleedrop")

IncludeScript("itemExFunc")

IncludeScript("seohorde");

IncludeScript("custom_tank_health");

IncludeScript("stats_printer")

IncludeScript("survivorshoving")

IncludeScript("player_connection_notifier", getroottable());


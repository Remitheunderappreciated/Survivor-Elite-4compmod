printl("Survivor Elite Overhaul for Versus is now running. Author: Ɽǝϻɨ");

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

IncludeScript("grenade_shove", getroottable());

IncludeScript("meleedrop")

IncludeScript("itemExFunc")

IncludeScript("seohorde");

IncludeScript("custom_tank_health");

IncludeScript("survivorshoving")

IncludeScript("player_connection_notifier", getroottable());


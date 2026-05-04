Msg("SEO tank health\n");

Convars.SetValue("sv_consistency", 0);
Convars.SetValue("sv_pure_kick_clients", 0);

::DirectorOptions <-
{
	ZombieTankHealth = 7500
}

CustomTankHealth <-
{
	function OnGameEvent_tank_spawn( params )
	{
		Ent(params.tankid).SetHealth(7500)
	}
}

__CollectEventCallbacks(CustomTankHealth, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);
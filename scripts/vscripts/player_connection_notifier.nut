// Squirrel
// Player Connection Notifier

tConnectionNotification <-
{
	OnGameEvent_player_connect = function(tParams)
	{
		if (tParams["networkid"] != "BOT")
		{
			printl(format("[%s] SteamID - %s UserID - %d", tParams["name"], tParams["networkid"], tParams["userid"]));
			ClientPrint(null, 3, format("Player %s has joined the game", tParams["name"]))
		}
	}
};

__CollectEventCallbacks(tConnectionNotification, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);

printl("SEO player connection note");
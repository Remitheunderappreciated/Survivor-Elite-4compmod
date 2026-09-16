fire_spreads_geeb <-
{
	function OnGameEvent_infected_hurt(event)
	{
		local hot_single = EntIndexToHScript(event.entityid);
		if(hot_single.GetModelName() == "models/infected/witch.mdl" || hot_single.GetModelName() == "models/infected/witch_bride.mdl")
		{
			if(("type" in event))
			{
				local type = (event.type)
				if(type == 268435456 || type == 268435464)
				{
					local origin = hot_single.GetOrigin()
					local ent = null
					while( ent = Entities.FindByClassnameWithin(ent, "infected", origin, 50))
					{
						if(ent != hot_single)
						{
							ent.TakeDamage(1, 8, hot_single)
						}
					}
					local ent = null
					while( ent = Entities.FindByClassnameWithin(ent, "witch", origin, 50))
					{
						if(ent != hot_single)
						{
							ent.TakeDamage(1, 8, hot_single)
						}
					}
					local ent = null
					while( ent = Entities.FindByClassnameWithin(ent, "player", origin, 50))
					{
						if(!ent.IsOnFire())
						{
							ent.TakeDamage(3, 8, hot_single)
						}
					}
				}
			}
		}
	}

	function OnGameEvent_player_hurt(event)
	{
		local hot_single = GetPlayerFromUserID(event.userid);
		if(("type" in event))
		{
			local type = (event.type)
			if(type == 268435456 || type == 268435464)
			{
				local origin = hot_single.GetOrigin()
				local ent = null
				while( ent = Entities.FindByClassnameWithin(ent, "infected", origin, 30))
				{
					ent.TakeDamage(1, 8, hot_single)
				}
				local ent = null
				while( ent = Entities.FindByClassnameWithin(ent, "witch", origin, 50))
				{
					if(ent != hot_single)
					{
						ent.TakeDamage(1, 8, hot_single)
					}
				}
				local ent = null
				while( ent = Entities.FindByClassnameWithin(ent, "player", origin, 50))
				{
					if(!ent.IsOnFire())
					{
						if(ent != hot_single)
						{
							ent.TakeDamage(3, 8, hot_single)
						}
					}
				}
			}
		}
	}
}

__CollectEventCallbacks(fire_spreads_geeb, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);
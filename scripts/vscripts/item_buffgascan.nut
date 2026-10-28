MedicPickupLimit <- 0
ItemBuffMode <- 0

function IsAvailableEntity(kent)
{
	if(kent)
	{
		return true;
	}
	return false;
}

function OnGameEvent_item_pickup(event)
{
	local pickeditem = null;
	if(("item" in event))
	{
		pickeditem = event["item"];
		
	}
	local kent = null;
	if(("userid" in event))
	{
		kent = GetPlayerFromUserID(event.userid);
		
	}
	if(kent.IsSurvivor())
	{
		if(pickeditem == "gascan")
		{
			for(local owneditem; owneditem = Entities.FindByClassname(owneditem, "weapon_" + pickeditem); )
			{
				if(owneditem.GetOwnerEntity() == kent)
				{
					if(owneditem.ValidateScriptScope())
					{
						local entity_entityscript = owneditem.GetScriptScope();
						entity_entityscript["GascanThink"] <- function()
						{
							function IsOwnedWeapon(kent, weaponclass)
							{
								for(local ownedweapon; ownedweapon = Entities.FindByClassname(ownedweapon, weaponclass); )
								{
									if(ownedweapon.GetOwnerEntity() == kent)
									{
										return true;
									}
								}
								return false;
							}
							
							if(self.GetOwnerEntity() != null)
							{
								local owner = self.GetOwnerEntity();
								if(!owner.IsDead())
								{
									if(IsOwnedWeapon(owner, "weapon_chainsaw"))
									{
										for(local weapon; weapon = Entities.FindByClassname(weapon, "weapon_chainsaw"); )
										{
											if(weapon.GetOwnerEntity() == owner)
											{
												if(NetProps.GetPropInt(weapon, "m_iClip1") < 200)
												{
													NetProps.SetPropInt(weapon, "m_iClip1", (NetProps.GetPropInt(weapon, "m_iClip1") + 10));
												}
											}
										}
									}
									
								}
								
							}
							return 1.0;
						}
					}
					AddThinkToEnt(owneditem, "GascanThink");
					printl("Added 'THINKER' to " + owneditem);
				}
			}
		}
		
	}
}

function OnGameEvent_round_start_post_nav(event)
{
	printl("The 'ITEM BUFFS' mode is started...");
	
}
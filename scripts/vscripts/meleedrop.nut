printl( "Survivor Elite Overhaul Dead Weapon Manager Loaded");
Convars.SetValue("sv_consistency", 0);
Convars.SetValue("sv_pure_kick_clients", 0);

if (!("MANACAT" in getroottable()))
{
	::MANACAT <-
	{
	}
}

IncludeScript("manacat_drop/manacatTimer");
if (!("manacatTimers" in getroottable())){
	IncludeScript("manacat/manacatTimer");
}

::meleeDropVars<-{
	survList = [null,null,null,null,null,null,null,null]
	survIncap = [false,false,false,false,false,false,false,false]
	wea1List = [null,null,null,null,null,null,null,null]
	wea2List = [null,null,null,null,null,null,null,null]
	weascript = {}
	weascript_len = 0
}

::meleeDropFunc<-{
	function OnGameEvent_player_first_spawn(params){
		local _player = GetPlayerFromUserID(params.userid);
		if(_player.IsSurvivor()){
			for(local i=0;i<8;i++){
				if(::meleeDropVars.survList[i] == _player.GetModelName())break;
				if(::meleeDropVars.survList[i] == null){
					::meleeDropVars.survList[i] = _player.GetModelName();
					saveInvSet(_player);
					break;
				}
			}
		}
	}

	function OnGameEvent_player_transitioned(params){
		::manacatAddTimer(0.1, false, ::meleeDropFunc.melee_restore, { });
		local _player = GetPlayerFromUserID(params.userid);
		if(_player.IsSurvivor()){
			for(local i=0;i<8;i++){
				if(::meleeDropVars.survList[i] == _player.GetModelName())break;
				if(::meleeDropVars.survList[i] == null){
					::meleeDropVars.survList[i] = _player.GetModelName();
					saveInvSet(_player);
					break;
				}
			}
		}
	}

	function OnGameEvent_round_start_post_nav(params){
		RestoreTable("weapon_script", ::meleeDropVars.weascript);
		if(::meleeDropVars.weascript.len() == 0 || (Director.IsSessionStartMap() && Time() < 10)){
			::meleeDropVars.weascript.clear();
		}
		SaveTable("weapon_script", ::meleeDropVars.weascript);
		local len = ::meleeDropVars.weascript.len();
		if(len != 0){	len /= 2;	::meleeDropVars.weascript_len = len;	}
	/*	for(local i = 0; i < len; i++){
			printl(::meleeDropVars.weascript["model"+i]+"  "+::meleeDropVars.weascript["script"+i]);
		}//*/

		local ent;
		while (ent = Entities.FindByClassname(ent, "player")){
			if(ent.IsValid()){
				if(ent.GetZombieType() == 9){
					for(local i=0;i<8;i++){
						if(::meleeDropVars.survList[i] == ent.GetModelName())break;
						if(::meleeDropVars.survList[i] == null){
							::meleeDropVars.survList[i] = ent.GetModelName();
							saveInvSet(ent);
							break;
						}
					}
				}
			}
		}
	}

	function OnGameEvent_survivor_rescued(params){
		local player = GetPlayerFromUserID(params.victim);
		local invTable = {};
		GetInvTable(player, invTable);
		if(!("slot0" in invTable)){
			for(local i = 0; i < 8; i++){
				if(::meleeDropVars.survList[i] == player.GetModelName() && ::meleeDropVars.wea1List[i] != null){
					switch(::meleeDropVars.wea1List[i].slice(16)){
						case "v_smg.mdl":
							player.GiveItem("smg");	break;
						case "v_silenced_smg.mdl":
							player.GiveItem("smg_silenced");	break;
						case "v_smg_mp5.mdl":
							player.GiveItem("smg_mp5");	break;
						case "v_rifle.mdl":case "v_rif_sg552.mdl":
							player.GiveItem("smg");	break;
						case "v_rifle_AK47.mdl":case "v_desert_rifle.mdl":
							player.GiveItem("smg_silenced");	break;
						case "v_m60.mdl":
							player.GiveItem("smg_mp5");	break;
						case "v_huntingrifle.mdl":
							player.GiveItem("smg");	break;
						case "v_sniper_military.mdl":
							player.GiveItem("smg_silenced");	break;
						case "v_snip_scout.mdl":case "v_snip_awp.mdl":
							player.GiveItem("smg_mp5");	break;
						case "v_pumpshotgun.mdl":case "v_autoshotgun.mdl":
							player.GiveItem("pumpshotgun");	break;
						case "v_shotgun_chrome.mdl":case "v_shotgun_spas.mdl":case "v_grenade_launcher.mdl":
							player.GiveItem("shotgun_chrome");	break;
					}
				}
			}
		}
	}

	function OnGameEvent_defibrillator_used(params){
		local player = GetPlayerFromUserID(params.subject);
		local invTable = {};
		GetInvTable(player, invTable);
		if(!("slot1" in invTable))return null;
		local weapon = invTable.slot1;
		if(weapon.GetClassname() != "weapon_pistol"){
			weapon.Kill();
			player.GiveItem("weapon_pistol");
		}
	}

	function OnGameEvent_player_team(params){
		local player = GetPlayerFromUserID(params.userid);
		if(player.IsIncapacitated())return;
		saveInvSet(player);
	}

	function OnGameEvent_revive_success(params){
		local player = GetPlayerFromUserID(params.subject);
		saveInvSet(player);
	}

	function OnGameEvent_bot_player_replace(params){
		saveInvSet(GetPlayerFromUserID(params.player));
		saveInvSet(GetPlayerFromUserID(params.bot));
	}
	function OnGameEvent_player_bot_replace(params){
		saveInvSet(GetPlayerFromUserID(params.player));
		saveInvSet(GetPlayerFromUserID(params.bot));
	}

	function OnGameEvent_item_pickup(params){
		local player = GetPlayerFromUserID(params.userid);
		if(player.IsIncapacitated())return;
		saveInvSet(player);
	}

	function OnGameEvent_player_use(params){
		local player = GetPlayerFromUserID(params.userid);
		if(player.IsIncapacitated())return;
		saveInvSet(player);
	}

	function OnGameEvent_player_incapacitated_start(params){
		local player = GetPlayerFromUserID(params.userid);
		saveInvSet(player);
	}

	function saveInvSet(player){
		if(player == null || !player.IsValid() || !player.IsSurvivor() || player.IsDead() || player.IsDying())return;
		local model = player.GetModelName();
		local invTable = {};
		GetInvTable(player, invTable);
		for(local i = 0; i < 8; i++){
			if(::meleeDropVars.survList[i] == model){
				if ( "slot0" in invTable )
					::meleeDropVars.wea1List[i] = invTable["slot0"].GetModelName();
				if ( "slot1" in invTable ){
					if(NetProps.GetPropString( invTable["slot1"], "m_strMapSetScriptName" ) != ""){
						::meleeDropVars.wea2List[i] = ["mel_"+NetProps.GetPropString( invTable["slot1"], "m_strMapSetScriptName" ), invTable["slot1"]];
					}else{
						if(invTable["slot1"].GetModelName() == "models/v_models/v_pistolA.mdl")
								::meleeDropVars.wea2List[i] = ["skip_single_pistol", null]
						else	::meleeDropVars.wea2List[i] = ["gun_"+NetProps.GetPropStringArray( invTable["slot1"], "m_iClassname", 0 ), invTable["slot1"]];
					}
				}
			}
		}
	}
	function melee_trace(){
		::meleeDropVars.weascript.clear();
		local ent = null;	local n = 0;
		while (ent = Entities.FindByClassname(ent, "weapon_melee")){
			if(ent.IsValid()){
				local melee_script = NetProps.GetPropString(ent, "m_strMapSetScriptName");
				if(melee_script == "" || NetProps.GetPropEntity(ent, "m_hOwner") != null)continue;
				local model = ent.GetModelName();
				local find = false;
				for(local i = 0; i < n; i++){
					if("model"+i in ::meleeDropVars.weascript && ::meleeDropVars.weascript["model"+i] == model){
						::meleeDropVars.weascript["script"+i] <- melee_script;
						find = true;	break;
					}
				}
				if(!find){
					::meleeDropVars.weascript["model"+n] <- model;
					::meleeDropVars.weascript["script"+n] <- melee_script;
					n++;
				}
			}
		}

		/*local len = ::meleeDropVars.weascript.len();
		if(len != 0){
			len /= 2;
			for(local i = 0; i < len; i++){
				printl(::meleeDropVars.weascript["model"+i]+"  "+::meleeDropVars.weascript["script"+i]);
			}
		}//*/
	}

	function melee_restore(params){
		local ent = null;
		while (ent = Entities.FindByClassname(ent, "weapon_melee")){
			if(ent.IsValid()){
				local melee_script = NetProps.GetPropString(ent, "m_strMapSetScriptName");
				if(melee_script == "" && NetProps.GetPropEntity(ent, "m_hOwner") == null){
					local model = ent.GetModelName();
					for(local i = 0; i < ::meleeDropVars.weascript_len; i++){
						if("model"+i in ::meleeDropVars.weascript && ::meleeDropVars.weascript["model"+i] == model){
							NetProps.SetPropString(ent, "m_strMapSetScriptName", ::meleeDropVars.weascript["script"+i]);
							break;
						}
					}
				}
			}
		}
	}

	function OnGameEvent_map_transition(params){
		::meleeDropFunc.melee_trace();
		SaveTable("weapon_script", ::meleeDropVars.weascript);
	}

	function OnGameEvent_player_death(params){
		if(params.victimname == "Infected" || params.victimname == "Witch")return;
		local victim = GetPlayerFromUserID(params.userid);
		if(!GetPlayerFromUserID(params.userid).IsSurvivor())return;
		local vicV = victim.GetOrigin();
		local vecV = vicV+victim.EyePosition();
		vecV = Vector(vecV.x/2, vecV.y/2, vecV.z/2);
	//	if(vecV.z < vicV.z+45)vecV.z = vicV.z+45;
		//local angV = Vector((RandomInt(0,1)*180)+60+(RandomInt(0,1)*60), RandomInt(0,359), (RandomInt(0,1)*180)+70+(RandomInt(0,1)*40));
		local angV = Vector(30-(RandomInt(0,1)*60), RandomInt(0,359), 30-(RandomInt(0,1)*60));
		local mdl;	local modelName;	local melee = false;	local original = null;
		for(local i = 0; i < 8; i++){
			if(::meleeDropVars.survList[i] == victim.GetModelName()){
				mdl = ::meleeDropVars.wea2List[i][0];
				modelName = ::meleeDropVars.wea2List[i][0];
				original = ::meleeDropVars.wea2List[i][1];
				::meleeDropVars.wea2List[i][0] = "pistol";
			}
		}
		local wtype = modelName.slice(0,4);
		modelName = modelName.slice(4);
		if(wtype == "mel_")			melee = true;
		else if(wtype == "skip")	return;

		switch(modelName){
			case "models/v_models/v_pistolA.mdl" :
				return; modelName = "pistol";	melee = false;	break;
			case "models/v_models/v_dual_pistolA.mdl" :
				modelName = "pistol";	melee = false;	break;
			case "models/v_models/v_desert_eagle.mdl" :
				modelName = "pistol_magnum";	melee = false;	break;
		}

		local item = null;
		if(!melee){
			item = SpawnEntityFromTable(modelName,
			{
				origin = vecV
				angles = angV
				solid = "6"
				spawnflags = "1073741824"
				count = "1"
			});
		}else{
			item = SpawnEntityFromTable("weapon_melee",
			{
				melee_script_name = modelName
				origin = vecV
				angles = angV
				solid = "6"
				spawnflags = "1073741824"
			});
		}
		if(original != null){
			NetProps.SetPropIntArray( item, "m_nSkin", NetProps.GetPropIntArray( original, "m_nSkin", 0 ), 0 );
			NetProps.SetPropIntArray( item, "m_iClip1", NetProps.GetPropIntArray( original, "m_iClip1", 0 ), 0 );
			NetProps.SetPropIntArray( item, "m_iClip2", NetProps.GetPropIntArray( original, "m_iClip2", 0 ), 0 );
		}
		original.Kill();
		local impulseVec = victim.GetVelocity().Scale(0.9);
		impulseVec.z = 180;

		item.ApplyAbsVelocityImpulse(impulseVec);
		item.ApplyLocalAngularVelocityImpulse(Vector(250,0,0));
	}
}

__CollectEventCallbacks(::meleeDropFunc, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);
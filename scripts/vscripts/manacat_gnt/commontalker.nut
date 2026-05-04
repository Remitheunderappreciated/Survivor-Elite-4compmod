//v04/15/2022

::VocalCommonVars<-{
	playerList = [] //현재 존재하는 플레이어 리스트
	playerCount = 0 //현재 존재하는 플레이어 수
}

::VocalCommonFunc<-{
	function findPlayer(model){
		if(model == "models/infected/hunter.mdl" || model == "models/infected/hunter_l4d1.mdl")return null;
		for(local i = 0; i < ::VocalCommonVars.playerCount; i++){
			if(::VocalCommonVars.playerList[i][0] == model && ::VocalCommonVars.playerList[i][1].IsValid()){
				return ::VocalCommonVars.playerList[i][1];
			}
		}
	}

	function chkplayer(){
		::VocalCommonVars.playerList = [];
		::VocalCommonVars.playerCount = 0;
		local player = null;
		while (player = Entities.FindByClassname(player, "player")){
			local model = player.GetModelName();
			if(player.IsValid() && NetProps.GetPropIntArray( player, "m_iTeamNum", 0) == 2 && model != "models/infected/hunter.mdl" && model != "models/infected/hunter_l4d1.mdl"){
				::VocalCommonVars.playerList.append([model, player]);
				::VocalCommonVars.playerCount++;
			}
		}
	}

	function speakable(player){//chkSpeakable
		if(player != null && player.IsValid() && NetProps.GetPropIntArray( player, "m_iTeamNum", 0) == 2
		&& player.IsSurvivor() && !player.IsDead() && !player.IsDying()
		&& !player.IsIncapacitated() && !player.IsDominatedBySpecialInfected())return true;
		return false;
	}

	function OnGameEvent_player_connect(params){
		::VocalCommonFunc.chkplayer();
	}
	function OnGameEvent_player_connect_full(params){
		::VocalCommonFunc.chkplayer();
	}
	function OnGameEvent_player_disconnect(params){
		::VocalCommonFunc.chkplayer();
	}
	function OnGameEvent_player_team(params){
		::VocalCommonFunc.chkplayer();
	}
	function OnGameEvent_bot_player_replace(params){
		::VocalCommonFunc.chkplayer();
	}
	function OnGameEvent_player_bot_replace(params){
		::VocalCommonFunc.chkplayer();
	}
	function OnGameEvent_round_start_post_nav(params){
		::VocalCommonFunc.chkplayer();
	}
	function OnGameEvent_player_first_spawn(params){
		::VocalCommonFunc.chkplayer();
	}
}

__CollectEventCallbacks(::VocalCommonFunc, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);

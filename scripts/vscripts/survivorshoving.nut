///////////////////////////////////////////////////////////////////////////////
Msg("=====Survivor Shoving Script ACTIVATED!=====\n");
///////////////////////////////////////////////////////////////////////////////
//Patch 1.1, directional shoving using the attacker's location. Yay!
//Patch 1.2, removed the bot's ability to shove other players. TLS Compatibility update (mapspawn changed to mapspawn_addon.nut and new loading method)

//When a survivor is shoved, knock them forward and play a friendly fire sound
function OnGameEvent_player_shoved( params )
{
if( !("userid" in params) )
return;

if( !("attacker" in params) )
return;

local victim = GetPlayerFromUserID( params["userid"] );
local attacker = GetPlayerFromUserID( params["attacker"] );

if ( ( !victim ) || ( !victim.IsSurvivor() ) || ( IsPlayerABot(attacker) ) )
return;

local loc = attacker.GetOrigin();

victim.Stagger( loc );
EntFire( "!activator", "SpeakResponseConcept", "PlayerFriendlyFire", 0, victim );
}
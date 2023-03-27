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
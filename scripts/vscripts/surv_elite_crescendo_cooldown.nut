Msg("Initiating Crescendo Cooldown\n");

DirectorOptions <-
{
	AlwaysAllowWanderers = true
	MobSpawnMinTime = 25
	MobSpawnMaxTime = 60
	MobMinSize = 10
	MobMaxSize = 25
	MobMaxPending = 5
	SustainPeakMinTime = 5
	SustainPeakMaxTime = 8
	IntensityRelaxThreshold = 0.9
	RelaxMinInterval = 20
	RelaxMaxInterval = 35
	RelaxMaxFlowTravel = 2000
	SmokerLimit = 1
	HunterLimit = 2
	ChargerLimit = 1
	SpecialRespawnInterval = 20.0
	ZombieSpawnRange = 850
	NumReservedWanderers = 15
}

Director.ResetMobTimer()
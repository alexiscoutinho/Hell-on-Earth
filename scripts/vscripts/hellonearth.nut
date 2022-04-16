printl("Activating Hell on Earth")

MutationOptions <- {
	ActiveChallenge = 1

	cm_SpecialRespawnInterval = 15
	cm_MaxSpecials = 12
	cm_BaseSpecialLimit = 3
	cm_DominatorLimit = 12

	cm_ShouldHurry = true
	cm_AllowPillConversion = false
	cm_AllowSurvivorRescue = false
	SurvivorMaxIncapacitatedCount = 0
	TempHealthDecayRate = 0.0

	cm_TempHealthOnly = true
	cm_ProhibitBosses = false
	ZombieTankHealth = 8000

	function AllowFallenSurvivorItem( classname ) {
		if (classname == "weapon_first_aid_kit")
			return false
		
		return true
	}

	weaponsToConvert = {
		weapon_first_aid_kit = "weapon_pain_pills_spawn"
	}

	function ConvertWeaponSpawn( classname ) {
		if (classname in weaponsToConvert)
			return weaponsToConvert[ classname ]
		return 0
	}

	DefaultItems = [
		"weapon_pistol",
		"weapon_pistol",
	]

	function GetDefaultItem( idx ) {
		if (idx < DefaultItems.len())
			return DefaultItems[ idx ]
		return 0
	}
}

if (GetDifficulty() == 3)
	MutationOptions.cm_BaseCommonAttackDamage <- 1.5

function OnGameEvent_difficulty_changed( params ) {
	if (params.newDifficulty == 3)
		DirectorOptions.cm_BaseCommonAttackDamage <- 1.5
	else if ("cm_BaseCommonAttackDamage" in DirectorOptions)
		DirectorOptions.cm_BaseCommonAttackDamage = 1.0
}

function OnGameEvent_round_start( params ) {
	Convars.SetValue( "pain_pills_decay_rate", 0.0 )

	DecideNextBoss()
}

function OnGameEvent_player_left_safe_area( params ) {
	DirectorOptions.TempHealthDecayRate = 0.0667
}

function OnGameEvent_bot_player_replace( params ) {
	local player = GetPlayerFromUserID( params.player )

	StopSoundOn( "Player.Heartbeat", player )
}

function OnGameEvent_pills_used( params ) {
	local player = GetPlayerFromUserID( params.userid )

	NetProps.SetPropInt( player, "m_bIsOnThirdStrike", 0 )
	StopSoundOn( "Player.Heartbeat", player )
}

if (!Director.IsSessionStartMap()) {
	function PlayerSpawnDeadAfterTransition( userid ) {
		local player = GetPlayerFromUserID( userid )
		if (!player)
			return

		player.SetHealthBuffer( 49 )
	}

	function PlayerSpawnAliveAfterTransition( userid ) {
		local player = GetPlayerFromUserID( userid )
		if (!player)
			return

		local maxHealth = player.GetMaxHealth()
		local healthIncrease = 50
		local bufferHealth = player.GetHealthBuffer()
		local totalHealth = player.GetHealth() + bufferHealth
		local missingHealth = maxHealth - totalHealth

		if (missingHealth > 0) {
			if (totalHealth + healthIncrease > maxHealth)
				player.SetHealthBuffer( bufferHealth + missingHealth )
			else
				player.SetHealthBuffer( bufferHealth + healthIncrease )
		}
	}

	function OnGameEvent_player_transitioned( params ) {
		local player = GetPlayerFromUserID( params.userid )

		if (!player || !player.IsSurvivor())
			return

		if (NetProps.GetPropInt( player, "m_lifeState" ) == 2)
			EntFire( "worldspawn", "RunScriptCode", "g_ModeScript.PlayerSpawnDeadAfterTransition(" + params.userid + ")", 0.1 )
		else
			EntFire( "worldspawn", "RunScriptCode", "g_ModeScript.PlayerSpawnAliveAfterTransition(" + params.userid + ")", 0.1 )
	}
}

witchesLeft <- 4
tanksLeft <- 2

function DecideNextBoss() {
	if (witchesLeft > 0 && RandomInt( 1, 100 ) > 35 || tanksLeft == 0) {
		Convars.SetValue("director_force_tank", 0)
		Convars.SetValue("director_force_witch", 1)
	}
	else {
		Convars.SetValue("director_force_witch", 0)
		Convars.SetValue("director_force_tank", 1)
	}
}

function OnGameEvent_witch_spawn( params ) {
	local witch = EntIndexToHScript( params.witchid )
	local witchPos = witch.GetOrigin()

	if (Entities.FindByClassnameWithin(null, "info_zombie_spawn", witchPos, 3) != null)
		return

	witchesLeft--
	DecideNextBoss()
}

function OnGameEvent_tank_spawn( params ) {
	local tank = EntIndexToHScript( params.tankid )
	local tankPos = tank.GetOrigin()

	if (Entities.FindByClassnameWithin(null, "info_zombie_spawn", tankPos, 3) != null)
		return

	tanksLeft--
	DecideNextBoss()
}

function Update() {
	for (local first_aid; first_aid = Entities.FindByClassname( first_aid, "weapon_first_aid_kit" );)
		first_aid.Kill()
}
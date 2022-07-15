printl("Activating Hell on Earth")

if (!IsModelPrecached("models/infected/smoker.mdl"))
	PrecacheModel("models/infected/smoker.mdl")
if (!IsModelPrecached("models/infected/smoker_l4d1.mdl"))
	PrecacheModel("models/infected/smoker_l4d1.mdl")
if (!IsModelPrecached("models/infected/boomer.mdl"))
	PrecacheModel("models/infected/boomer.mdl")
if (!IsModelPrecached("models/infected/boomer_l4d1.mdl"))
	PrecacheModel("models/infected/boomer_l4d1.mdl")
if (!IsModelPrecached("models/infected/boomette.mdl"))
	PrecacheModel("models/infected/boomette.mdl")
if (!IsModelPrecached("models/infected/hunter.mdl"))
	PrecacheModel("models/infected/hunter.mdl")
if (!IsModelPrecached("models/infected/hunter_l4d1.mdl"))
	PrecacheModel("models/infected/hunter_l4d1.mdl")
if (!IsModelPrecached("models/infected/limbs/exploded_boomette.mdl")) {
	PrecacheModel("models/infected/limbs/exploded_boomette.mdl")
	::hellonearth_no_female_boomers <- true
}
if (!IsModelPrecached("models/infected/spitter.mdl"))
	PrecacheModel("models/infected/spitter.mdl")
if (!IsModelPrecached("models/infected/jockey.mdl"))
	PrecacheModel("models/infected/jockey.mdl")
if (!IsModelPrecached("models/infected/charger.mdl"))
	PrecacheModel("models/infected/charger.mdl")
if (!IsModelPrecached("models/infected/witch.mdl"))
	PrecacheModel("models/infected/witch.mdl")
if (!IsModelPrecached("models/infected/hulk.mdl"))
	PrecacheModel("models/infected/hulk.mdl")
if (!IsModelPrecached("models/infected/hulk_l4d1.mdl"))
	PrecacheModel("models/infected/hulk_l4d1.mdl")

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
		if (classname != "weapon_first_aid_kit")
			return true

		if (RandomInt( 1, 100 ) > 25) {
			local fallen

			while (fallen = Entities.FindByClassname( fallen, "infected" )) {
				if (NetProps.GetPropInt( fallen, "m_Gender" ) == GENDER_FALLEN)
					break
			}

			local defib = SpawnEntityFromTable( "prop_dynamic", {
				model = "models/w_models/weapons/w_eq_defibrillator.mdl"
				solid = 4
			} )

			DoEntFire( "!caller", "SetParent", "!activator", 0.0, fallen, defib )
			DoEntFire( "!self", "SetParentAttachment", "medkit", 0.0, null, defib )
			local code = "self.SetLocalAngles( QAngle( -90, 0, 0 ) ); self.SetLocalOrigin( Vector( 1.5, 1, 4 ) )"
			DoEntFire( "!self", "RunScriptCode", code, 0.0, null, defib )

			fallen.ValidateScriptScope()
			fallen.GetScriptScope().defib <- defib
		}
		return false
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

const GENDER_FALLEN = 14

function OnGameEvent_zombie_death( params ) {
	if (params.gender != GENDER_FALLEN)
		return

	local fallen = EntIndexToHScript( params.victim )
	local scope = fallen.GetScriptScope()

	if (scope && ("defib" in scope) && scope.defib.IsValid()) {
		scope.defib.Kill()

		local w_defib = SpawnEntityFromTable( "weapon_defibrillator", {
			angles = scope.defib.GetAngles().ToKVString()
			origin = scope.defib.GetOrigin()
		} )

		w_defib.ApplyAbsVelocityImpulse( GetPhysVelocity( scope.defib ) )
		w_defib.ApplyLocalAngularVelocityImpulse( GetPhysAngularVelocity( scope.defib ) )
	}
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

function OnGameEvent_player_complete_sacrifice( params ) {
	local player = GetPlayerFromUserID( params.userid )
	if (!player)
		return

	NetProps.SetPropInt( player, "m_takedamage", 0 )
	NetProps.SetPropInt( player, "m_isIncapacitated", 1 )
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

function GetDecayRate() {
	return -0.06 * log( self.GetHealthBuffer() ) + 0.4
}

function TempHealthDecayThink() {
	if (Director.HasAnySurvivorLeftSafeArea() && self.GetHealthBuffer() > 0 && !self.IsHangingFromLedge()) {
		local decayRate = GetDecayRate()
		self.SetHealthBuffer( self.GetHealthBuffer() - decayRate * ThinkInterval )
	}
	return ThinkInterval
}

function OnSurvivorSpawn( survivor ) {
	survivor.ValidateScriptScope()
	local scope = survivor.GetScriptScope()
	scope["GetDecayRate"] <- GetDecayRate
	scope["TempHealthDecayThink"] <- TempHealthDecayThink
	scope["ThinkInterval"] <- 0.5
	AddThinkToEnt( survivor, "TempHealthDecayThink" )
}

function OnGameEvent_finale_start( params ) {
	if (g_MapName == "c6m3_port") {
		for (local player; player = Entities.FindByClassname( player, "player" );) {
			if (NetProps.GetPropInt( player, "m_iTeamNum" ) == 4) {
				player.SetHealth( 1 )
				player.SetHealthBuffer( 99 )
				player.ValidateScriptScope()
				local scope = player.GetScriptScope()
				scope["GetDecayRate"] <- GetDecayRate
				scope["TempHealthDecayThink"] <- TempHealthDecayThink
				scope["ThinkInterval"] <- 1
				AddThinkToEnt( player, "TempHealthDecayThink" )
			}
		}
	}
}

//TODO: fix https://github.com/Tsuey/L4D2-Community-Update/issues/24 bugs?

MutationState <- {
	WitchesLeft = 4
	TanksLeft = 2
	SIModelsBase = [
		["models/infected/smoker.mdl", "models/infected/smoker_l4d1.mdl"],
		["models/infected/boomer.mdl", "models/infected/boomer_l4d1.mdl", "models/infected/boomette.mdl"],
		["models/infected/hunter.mdl", "models/infected/hunter_l4d1.mdl"],
		["models/infected/spitter.mdl"],
		["models/infected/jockey.mdl"],
		["models/infected/charger.mdl"],
		["models/infected/witch.mdl"],
		["models/infected/hulk.mdl", "models/infected/hulk_l4d1.mdl"],
	]
	SIModels = [
		["models/infected/smoker.mdl", "models/infected/smoker_l4d1.mdl"],
		["models/infected/boomer.mdl", "models/infected/boomer_l4d1.mdl", "models/infected/boomette.mdl"],
		["models/infected/hunter.mdl", "models/infected/hunter_l4d1.mdl"],
		["models/infected/spitter.mdl"],
		["models/infected/jockey.mdl"],
		["models/infected/charger.mdl"],
		["models/infected/witch.mdl"],
		["models/infected/hulk.mdl", "models/infected/hulk_l4d1.mdl"],
	]
	ModelCheck = [false, false, false, false, false, false, false, false]
	LastBoomerModel = ""
	BoomersChecked = 0
	TankChance = 35
}

function DecideNextBoss() {
	if (SessionState.WitchesLeft > 0 && RandomInt( 1, 100 ) > SessionState.TankChance || SessionState.TanksLeft <= 0) {
		Convars.SetValue("director_force_tank", 0)
		Convars.SetValue("director_force_witch", 1)
	}
	else {
		Convars.SetValue("director_force_witch", 0)
		Convars.SetValue("director_force_tank", 1)
	}
}

function OnGameEvent_round_start( params ) {
	DecideNextBoss()
}

function OnGameEvent_witch_spawn( params ) {
	local witch = EntIndexToHScript( params.witchid )
	local witchPos = witch.GetOrigin()

	if (Entities.FindByClassnameWithin(null, "info_zombie_spawn", witchPos, 3) != null)
		return
	//TODO: filter out console spawned witches

	if (g_MapName == "c6m1_riverbank" && witch.GetModelName() == "models/infected/witch_bride.mdl") {
		local sequence = witch.GetSequence()
		witch.SetModel("models/infected/witch.mdl")
		witch.SetSequence( sequence )
		//TODO: fix witch sound
	}

	SessionState.WitchesLeft--
	DecideNextBoss()
}

function OnGameEvent_tank_spawn( params ) {
	local tank = EntIndexToHScript( params.tankid )
	local tankPos = tank.GetOrigin()

	if (Entities.FindByClassnameWithin(null, "info_zombie_spawn", tankPos, 3) != null)
		return

	SessionState.TanksLeft--	//TODO: filter out console spawned tanks
	DecideNextBoss()
}

function OnSpecialSpawn( special ) {
	local zombieType = special.GetZombieType()
	local modelName = special.GetModelName()

	if (!SessionState.ModelCheck[ zombieType - 1 ]) {
		if (zombieType == 2 && !("hellonearth_no_female_boomers" in getroottable())) {
			if (SessionState.LastBoomerModel != modelName) {
				SessionState.LastBoomerModel = modelName
				SessionState.BoomersChecked++
			}
			if (SessionState.BoomersChecked > 1)
				SessionState.ModelCheck[ zombieType - 1 ] = true
		}
		else
			SessionState.ModelCheck[ zombieType - 1 ] = true

		if (modelName == "models/infected/hulk_dlc3.mdl") {
			if (SessionState.SIModelsBase[ 7 ].find("models/infected/hulk.mdl") == null) {
				SessionState.SIModelsBase[ 7 ].append("models/infected/hulk.mdl")
				SessionState.SIModels[ 7 ].append("models/infected/hulk.mdl")
			}
		}
		else {
			if (SessionState.SIModelsBase[ zombieType - 1 ].find( modelName ) == null) {
				SessionState.SIModelsBase[ zombieType - 1 ].append( modelName )
				SessionState.SIModels[ zombieType - 1 ].append( modelName )
			}
		}
	}

	if (SessionState.SIModelsBase[ zombieType - 1 ].len() == 1)
		return

	local zombieModels = SessionState.SIModels[ zombieType - 1 ]
	if (zombieModels.len() == 0)
		SessionState.SIModels[ zombieType - 1 ].extend( SessionState.SIModelsBase[ zombieType - 1 ] )

	local randomElement = RandomInt( 0, zombieModels.len() - 1 )
	local randomModel = zombieModels[ randomElement ]
	zombieModels.remove( randomElement )

	local sequence = special.GetSequence()
	special.SetModel( randomModel )
	special.SetSequence( sequence )
}

function OnGameEvent_player_spawn( params ) {
	local player = GetPlayerFromUserID( params.userid )
	local teamNum = NetProps.GetPropInt( player, "m_iTeamNum" )

	if (teamNum == 2)
		OnSurvivorSpawn( player )
	else if (teamNum == 3)
		OnSpecialSpawn( player )
}

function Update() {
	for (local first_aid; first_aid = Entities.FindByClassname( first_aid, "weapon_first_aid_kit" );)
		first_aid.Kill()
}
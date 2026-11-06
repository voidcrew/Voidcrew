/// ckeys whose arrival background_site_arrival() is announcing right now. The join handler leaves them alone.
GLOBAL_LIST_EMPTY(background_site_arrivals)

/// Begins the background of everyone who spawns aboard a background hull
GLOBAL_DATUM_INIT(background_arrivals, /datum/background_arrivals, new)

/// The background a lobby player picked, read from their character. BACKGROUND_SPACEFARER when unknown.
/proc/background_choice(mob/dead/new_player/player)
	var/datum/client_interface/player_client = GET_CLIENT(player)
	var/choice = player_client?.prefs?.read_preference(/datum/preference/choiced/background)
	if(!choice || !background_by_key(choice))
		return BACKGROUND_SPACEFARER
	return choice

/**
 * How many of `ready_count` ready players may start as `key` at roundstart.
 * The pirate and hunter shares floor at one, so one player can always try either start.
 */
/proc/background_roundstart_cap(key, ready_count)
	switch(key)
		if(BACKGROUND_PIRATE)
			return max(1, FLOOR(ready_count * BACKGROUND_SHARE_PIRATE, 1))
		if(BACKGROUND_BOUNTY_HUNTER)
			return max(1, FLOOR(ready_count * BACKGROUND_SHARE_HUNTER, 1))
		if(BACKGROUND_CONVICT)
			return BACKGROUND_PEN_ESCAPE_CELLS
		if(BACKGROUND_HOMESTEADER)
			return BACKGROUND_MAX_HOMESTEADERS
	return ready_count

/// Spawns every ready player who picked a start other than Spacefarer. Returns the players left to ship out with a crew.
/datum/controller/subsystem/ticker/proc/start_background_players(list/ready_players)
	// Every choice is read before anything sleeps
	var/list/choices = list()
	for(var/mob/dead/new_player/player as anything in ready_players)
		choices[player] = background_choice(player)
	return run_background_starts(ready_players, choices)

/**
 * The body of start_background_players(), with the choices already read: `choices` maps each
 * player to a background key. Split out so a test can hand it players with no client.
 */
/datum/controller/subsystem/ticker/proc/run_background_starts(list/ready_players, list/choices)
	var/ready_count = length(ready_players)
	var/list/mob/dead/new_player/spacefarers = list()
	var/list/buckets = list()
	for(var/mob/dead/new_player/player as anything in ready_players)
		var/key = choices[player]
		if(!key || key == BACKGROUND_SPACEFARER || !background_by_key(key))
			spacefarers += player
			continue
		if(!buckets[key])
			buckets[key] = list()
		var/list/bucket = buckets[key]
		bucket += player
	if(!length(buckets))
		return spacefarers

	// Over a start's share: chosen at random, they ship out with a crew
	var/list/mob/dead/new_player/turned_back = list()
	for(var/key in buckets)
		var/list/bucket = buckets[key]
		var/cap = background_roundstart_cap(key, ready_count)
		if(length(bucket) <= cap)
			continue
		shuffle_inplace(bucket)
		var/list/overflow = bucket.Copy(cap + 1)
		bucket.Cut(cap + 1)
		for(var/mob/dead/new_player/player as anything in overflow)
			to_chat(player, span_warning("There was no room for that start. You ship out with a crew."))
			background_metric("background_overflow", player.mind, background_key = key)
			turned_back += player

	// In the preference's order, so the sites load before the hulls
	for(var/key in BACKGROUND_ALL_KEYS | buckets)
		var/list/bucket = buckets[key]
		if(!length(bucket))
			continue
		// Earlier starts slept on their loads: drop anyone who left meanwhile
		for(var/mob/dead/new_player/player as anything in bucket.Copy())
			if(QDELETED(player) || !GET_CLIENT(player))
				bucket -= player
		if(!length(bucket))
			continue
		var/datum/background/background = background_by_key(key)
		var/list/failed = background.roundstart(bucket.Copy())
		for(var/mob/dead/new_player/player as anything in failed)
			if(QDELETED(player))
				continue
			to_chat(player, span_warning("Your start fell through. You ship out with a crew."))
			background_metric("background_start_failed", player.mind, list("reason" = "roundstart"), background_key = key)
			turned_back += player
		CHECK_TICK

	var/list/mob/dead/new_player/left = list()
	for(var/mob/dead/new_player/player as anything in spacefarers + turned_back)
		if(!QDELETED(player))
			left += player
	return left

/**
 * Puts this lobby player into the world at a background's site (the Penitentiary, the homestead,
 * an escape pod's cryopod). Returns the living character, or null.
 *
 * The tail of AttemptSpawnOnShip() without the ship parts: no slot, no ship manifest, no headset
 * binding, no Ship Management. Works while the round is setting up, unlike join_outpost().
 * The caller begins the background itself once this returns.
 */
/mob/dead/new_player/proc/background_site_arrival(datum/job/job, atom/destination)
	if(!job || !destination || !mind || !client || spawning)
		return null
	if(SSlag_switch.measures[DISABLE_NON_OBSJOBS])
		to_chat(src, span_warning("An administrator has disabled late join spawning."))
		return null

	var/datum/job/previous_role = mind.assigned_role
	if(SSticker.IsRoundInProgress())
		SSticker.queued_players -= src
		SSticker.queue_delay = 4

	if(!SSjob.assign_role(src, job, TRUE))
		return null
	// Eligibility can sleep on the ban database
	if(QDELETED(src) || !client)
		job.current_positions = max(0, job.current_positions - 1)
		mind?.set_assigned_role(previous_role)
		return null

	var/player_ckey = ckey
	var/mob/living/character = create_character(destination)
	if(!character)
		if(QDELETED(src))
			return null
		job.current_positions = max(0, job.current_positions - 1)
		mind?.set_assigned_role(previous_role)
		spawning = FALSE
		return null
	transfer_character()

	SSjob.equip_rank(character, job, character.client)
	job.after_latejoin_spawn(character)
	SSticker.minds |= character.mind
	character.client?.init_verbs()

	var/mob/living/carbon/human/humanc
	if(ishuman(character))
		humanc = character
		GLOB.manifest.inject(humanc)
		humanc.increment_scar_slot()
		humanc.load_persistent_scars()
		if(GLOB.curse_of_madness_triggered)
			give_madness(humanc, GLOB.curse_of_madness_triggered)

	GLOB.joined_player_list |= player_ckey
	clear_crew_applications_for_ckey(player_ckey)
	if(humanc && (job.job_flags & JOB_ASSIGN_QUIRKS) && CONFIG_GET(flag/roundstart_traits))
		SSquirks.AssignQuirks(humanc, humanc.client)
	log_manifest(character.mind.key, character.mind, character, latejoin = TRUE)
	log_game("[key_name(character)] arrived at a background site as [job.title] at [AREACOORD(character)].")

	if(player_ckey)
		GLOB.background_site_arrivals[player_ckey] = TRUE
	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_CREWMEMBER_JOINED, character, job.title)
	if(player_ckey)
		GLOB.background_site_arrivals -= player_ckey

	// The wallet and pocket loadout wait for this (code/modules/loadout/categories/pocket.dm)
	if(humanc)
		SEND_SIGNAL(humanc, COMSIG_HUMAN_CHARACTER_SETUP_FINISHED)
	try_show_orientation_briefing(character)
	return character

/// Watches crew joins and begins the background of anyone who spawns aboard a background hull
/datum/background_arrivals

/datum/background_arrivals/New()
	. = ..()
	RegisterSignal(SSdcs, COMSIG_GLOB_CREWMEMBER_JOINED, PROC_REF(on_crewmember_joined))

/datum/background_arrivals/proc/on_crewmember_joined(datum/source, mob/living/character, rank)
	SIGNAL_HANDLER
	var/datum/mind/mind = character?.mind
	if(!mind)
		return
	// A site arrival is begun by the background that placed it, once
	var/player_ckey = character.ckey || (mind.key ? ckey(mind.key) : null)
	if(player_ckey && GLOB.background_site_arrivals[player_ckey])
		return
	var/obj/structure/overmap/ship/ship = background_arrival_ship(character)
	var/key = ship?.background_key()
	if(!key)
		return
	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(background_begin), mind, key)

/// The hull a fresh character joined: the ship their job belongs to, else the hull they stand in
/proc/background_arrival_ship(mob/living/character)
	var/obj/structure/overmap/ship/ship = character.mind?.assigned_role?.crew_ship_ref?.resolve()
	if(istype(ship))
		return ship
	var/obj/docking_port/mobile/voidcrew/port = SSshuttle.get_containing_shuttle(character)
	if(istype(port))
		return port.current_ship
	return null

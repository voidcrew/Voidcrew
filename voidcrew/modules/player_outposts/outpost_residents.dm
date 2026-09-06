/obj/structure/overmap/dynamic/player_outpost
	var/list/datum/mind/residents = list()
	var/list/obj/machinery/cryopod/resident_pods = list()
	var/resident_mode = "approved"
	var/resident_password = ""
	var/resident_access_revision = 1
	var/list/resident_clearance = list()
	var/list/invited_residents = list()
	var/list/blocked_residents = list()
	var/resident_limit = 6
	var/list/arrival_reservations = list()

/obj/structure/overmap/dynamic/player_outpost/proc/is_resident(mob/user)
	return is_owner(user) || (user?.mind && user.mind in residents)

/obj/structure/overmap/dynamic/player_outpost/proc/has_resident_clearance(player_key)
	return player_key && !(player_key in blocked_residents) && (player_key == founder_ckey || invited_residents[player_key] || resident_clearance[player_key] == resident_access_revision)

/obj/structure/overmap/dynamic/player_outpost/proc/active_resident_count()
	var/count = 0
	for(var/datum/mind/member as anything in residents.Copy())
		if(QDELETED(member))
			residents -= member
		else if(member.current?.client && member.current.stat != DEAD)
			count++
	return count

/obj/structure/overmap/dynamic/player_outpost/proc/available_resident_pod()
	for(var/obj/machinery/cryopod/pod as anything in resident_pods.Copy())
		if(QDELETED(pod))
			resident_pods -= pod
			continue
		pod.relink_to_ship()
		if(pod.linked_outpost == src && pod.anchored && !pod.occupant && !pod.arrival_reserved && !(pod.machine_stat & BROKEN))
			return pod
	return null

/obj/structure/overmap/dynamic/player_outpost/proc/resident_admission_error(player_key, password_attempt, reservation = FALSE)
	if(!loaded || !founder_ckey || resident_mode == "closed")
		return "Resident arrivals are closed"
	if(player_key in blocked_residents)
		return "Resident return access has been revoked"
	var/cleared = has_resident_clearance(player_key)
	if(dock_mode == OUTPOST_DOCK_MODE_LOCKDOWN && !cleared)
		return "Lockdown: only residents with saved clearance may return"
	if(resident_mode == "approved" && !cleared)
		return "Management must invite your player account"
	if(resident_mode == "password" && !cleared && (!length(resident_password) || password_attempt != resident_password))
		return "A current resident password is required"
	var/wait = cryo_rejoin_wait(player_key, src)
	if(wait)
		return "Cryo return cooldown: [DisplayTimeText(wait)] remaining"
	if(active_resident_count() + length(arrival_reservations) - (reservation ? 1 : 0) >= resident_limit)
		return "All active resident positions are occupied"
	if(!reservation && !available_resident_pod())
		return "No available arrival point; install, anchor or empty a resident cryopod"
	return null

/obj/machinery/cryopod
	var/obj/structure/overmap/dynamic/player_outpost/linked_outpost
	var/arrival_reserved = FALSE

/// Through the existing lobby only: respawn's delay/configuration still controls
/// reaching this mob, and character reuse/job/population gates are checked again.
/mob/dead/new_player/proc/join_outpost(obj/structure/overmap/dynamic/player_outpost/home)
	if(spawning || spawning_ship || !client || QDELETED(home))
		return FALSE
	var/attempt
	var/revision = home.resident_access_revision
	if(home.resident_mode == "password" && !home.has_resident_clearance(ckey))
		attempt = tgui_input_text(src, "Enter the resident password for [home.name].", "Resident Arrival", max_length = 64, encode = FALSE, timeout = 60 SECONDS)
	if(QDELETED(home) || !client || spawning || spawning_ship)
		return FALSE
	if(revision != home.resident_access_revision)
		to_chat(src, span_warning("Resident access changed. Select the outpost again."))
		return FALSE
	var/error = home.resident_admission_error(ckey, attempt)
	if(error)
		to_chat(src, span_warning(error))
		return FALSE
	if(!SSticker.IsRoundInProgress() || SSlag_switch.measures[DISABLE_NON_OBSJOBS])
		return FALSE
	if(CONFIG_GET(flag/allow_respawn) == RESPAWN_FLAG_NEW_CHARACTER && "[client.prefs.default_slot]" in persistent_client.joined_as_slots)
		to_chat(src, span_warning("You already played this character this round. Choose an eligible character."))
		return FALSE
	var/limit = CONFIG_GET(number/hard_popcap)
	var/extreme = CONFIG_GET(number/extreme_popcap)
	if(extreme)
		limit = limit ? min(limit, extreme) : extreme
	if(!check_rights_for(client, R_ADMIN) && ((limit && living_player_count() >= limit) || (length(SSticker.queued_players) && SSticker.queued_players[1] != src)))
		to_chat(src, span_warning("Wait for your place in the arrival queue."))
		return FALSE
	var/datum/job/job = SSjob.get_job_type(/datum/job/assistant)
	if(SSjob.check_job_eligibility(src, job, "Outpost resident arrival") != JOB_AVAILABLE || !job.special_check_latejoin(client))
		return FALSE
	var/obj/machinery/cryopod/pod = home.available_resident_pod()
	if(!pod)
		return FALSE
	// Reserve both capacity and a particular pod before character creation can yield.
	var/player_key = ckey
	var/character_slot = "[client.prefs.default_slot]"
	var/already_played_slot = (character_slot in persistent_client.joined_as_slots)
	home.arrival_reservations[player_key] = TRUE
	pod.arrival_reserved = TRUE
	spawning_ship = TRUE
	if(!SSjob.assign_role(src, job, TRUE))
		home.arrival_reservations -= player_key
		pod.arrival_reserved = FALSE
		spawning_ship = FALSE
		return FALSE
	var/datum/mind/arrival_mind = mind
	var/mob/living/character = create_character(pod, CALLBACK(src, PROC_REF(validate_outpost_arrival), home, pod, player_key, attempt, revision, job, character_slot))
	// The appearance prompt in get_spawn_mob can sleep. Never trust its earlier policy.
	if(QDELETED(home) || QDELETED(pod) || !character || !client || revision != home.resident_access_revision || home.resident_admission_error(player_key, attempt, TRUE) || get_outpost_from_atom(pod) != home || !pod.anchored || (pod.machine_stat & BROKEN) || (pod.occupant && pod.occupant != character))
		if(!QDELETED(home))
			home.arrival_reservations -= player_key
		if(!QDELETED(pod))
			pod.arrival_reserved = FALSE
		if(character)
			arrival_mind.transfer_to(src)
			qdel(character)
		new_character = null
		if(!already_played_slot)
			persistent_client.joined_as_slots -= character_slot
		job.current_positions = max(0, job.current_positions - 1)
		spawning = FALSE
		spawning_ship = FALSE
		to_chat(src, span_warning("Arrival cancelled because access or the cryopod changed. Your position was released."))
		return FALSE
	home.arrival_reservations -= player_key
	pod.arrival_reserved = FALSE
	home.residents |= character.mind
	home.resident_clearance[player_key] = home.resident_access_revision
	SSticker.queued_players -= src
	SSticker.queue_delay = 4
	transfer_character()
	SSjob.equip_rank(character, job, character.client)
	job.after_latejoin_spawn(character)
	SSticker.minds |= character.mind
	GLOB.joined_player_list |= character.ckey
	if(ishuman(character))
		var/mob/living/carbon/human/human = character
		GLOB.manifest.inject(human)
		human.increment_scar_slot()
		human.load_persistent_scars()
		var/obj/item/radio/headset = human.ears
		if(istype(headset))
			headset.bind_comms_to_outpost(home)
		if((job.job_flags & JOB_ASSIGN_QUIRKS) && CONFIG_GET(flag/roundstart_traits))
			SSquirks.AssignQuirks(human, human.client)
	log_manifest(character.mind.key, character.mind, character, latejoin = TRUE)
	log_shuttle("[character.ckey] arrived as a resident of [home.name]")
	to_chat(character, span_boldnotice("You are a resident of [home.name]. Your ID keeps its own account. Management can delegate treasury and construction authority separately."))
	try_show_orientation_briefing(character)
	return TRUE

/// Called before create_character transfers the lobby mind, after appearance prompts.
/mob/dead/new_player/proc/validate_outpost_arrival(obj/structure/overmap/dynamic/player_outpost/home, obj/machinery/cryopod/pod, player_key, attempt, revision, datum/job/job, character_slot, mob/living/character)
	if(!client || !mind || SSjob.check_job_eligibility(src, job, "Outpost final arrival") != JOB_AVAILABLE || !job.special_check_latejoin(client))
		return FALSE
	// Eligibility checks can sleep on the database. Recheck the physical destination
	// and its policy afterwards, before any membership or character slot is committed.
	if(!client || QDELETED(home) || QDELETED(pod) || QDELETED(character) || revision != home.resident_access_revision || "[client.prefs.default_slot]" != character_slot)
		return FALSE
	if(!SSticker.IsRoundInProgress() || SSlag_switch.measures[DISABLE_NON_OBSJOBS] || home.resident_admission_error(player_key, attempt, TRUE))
		return FALSE
	if(get_outpost_from_atom(pod) != home || !pod.anchored || (pod.machine_stat & BROKEN) || (pod.occupant && pod.occupant != character))
		return FALSE
	var/limit = CONFIG_GET(number/hard_popcap)
	var/extreme = CONFIG_GET(number/extreme_popcap)
	if(extreme)
		limit = limit ? min(limit, extreme) : extreme
	if(!check_rights_for(client, R_ADMIN) && ((limit && living_player_count() >= limit) || (length(SSticker.queued_players) && SSticker.queued_players[1] != src)))
		return FALSE
	return CONFIG_GET(flag/allow_respawn) != RESPAWN_FLAG_NEW_CHARACTER || !("[client.prefs.default_slot]" in persistent_client.joined_as_slots)

/// Ordinary resident access; it neither grants visitors membership nor changes
/// physical locks, damage, theft or any ship's access behavior.
/obj/allowed(mob/user)
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	if(home?.is_resident(user))
		return TRUE
	return ..()

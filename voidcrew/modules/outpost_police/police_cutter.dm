/**
 * # Outpost police: the cutter
 *
 * Owner: P9. At four and five stars a police cutter chases the crew's ship when it undocks (spec 9). Its ship
 * subtype (/obj/structure/overmap/ship/npc/pirate/nt_patrol/police), director (/datum/nt_patrol_director/police)
 * and template (/datum/map_template/shuttle/voidcrew/police_cutter, voidcrew/mapping/shuttles/police_cutter.dm)
 * are P9's to declare: subtypes of those are enumerated by ship lists, admin spawners and tests, so P0 left
 * them out.
 *
 * No new ship-combat or boarding code. start_pursuit() hands the incident to dispatch_nt_patrol()
 * (npc_ships/code/faction_pirates/nt_patrol.dm) with the cutter's ship and director types: the hail, the holopad
 * negotiation for the exact fine, interdiction, boarding waves and the boss on refusal are that pipeline's. What
 * is new here is who the cutter is (a stripped hull, a crew that pays out nothing, its own voice), how long it is
 * patient, and what a payment does (pardon_crew()).
 */

// ===== THE PURSUIT: one record per ship per incident =====

/// Cutters sent: weakref(quarry ship) -> /datum/outpost_police_pursuit. The ship is the key, so a second undock
/// of the same ship in the same incident finds the first cutter's record and sends nobody (once per incident).
GLOBAL_LIST_EMPTY(outpost_police_pursuits)

/// One cutter's errand: who sent it, after which ship, for how much, and which crew its payment pardons.
/datum/outpost_police_pursuit
	/// The outpost police that sent it (the outpost the ship left)
	var/datum/weakref/police_ref
	/// The ship it chases
	var/datum/weakref/quarry_ref
	/// The crew whose record is pardoned when the cutter is paid
	var/datum/weakref/crew_ref
	/// The stars at the time: 4 or 5
	var/stars = 0
	/// Officers the crew had killed by then (logged; the embargo's length is the wanted code's)
	var/officers_killed = 0
	/// The fine the hail demands
	var/fine = 0
	/// The hunt that came of it, while there is one
	var/datum/nt_patrol_director/police/director
	/// TRUE from the order until dispatch_nt_patrol() has answered (it sleeps while the hull loads)
	var/dispatching = TRUE
	/// world.time the incident's embargo runs out, as it stood when the cutter was sent: the same incident
	/// until then, so a ship that outruns or beats the cutter does not meet a second one
	var/ends_at = 0

/datum/outpost_police_pursuit/New(datum/outpost_police/police, obj/structure/overmap/ship/quarry, new_stars, new_officers_killed)
	. = ..()
	police_ref = WEAKREF(police)
	quarry_ref = WEAKREF(quarry)
	crew_ref = WEAKREF(quarry.get_crew_record())
	stars = new_stars
	officers_killed = new_officers_killed
	// 4 stars: spec 9's 6 000; 5 stars: 15 000 (OUTPOST_POLICE_CUTTER_FINES)
	var/list/fines = OUTPOST_POLICE_CUTTER_FINES
	fine = fines[stars >= 5 ? 2 : 1]
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		var/embargo_ends = outpost.embargoed_ships[quarry]
		if(embargo_ends)
			ends_at = max(ends_at, embargo_ends)
	RegisterSignal(quarry, COMSIG_QDELETING, PROC_REF(on_quarry_gone))

/datum/outpost_police_pursuit/Destroy()
	var/obj/structure/overmap/ship/quarry = quarry_ref?.resolve()
	if(quarry)
		UnregisterSignal(quarry, COMSIG_QDELETING)
	if(quarry_ref && GLOB.outpost_police_pursuits[quarry_ref] == src)
		GLOB.outpost_police_pursuits -= quarry_ref
	director = null
	police_ref = null
	quarry_ref = null
	crew_ref = null
	return ..()

/// The ship is gone: the record goes with it. The cutter's director notices on its next tick and withdraws.
/datum/outpost_police_pursuit/proc/on_quarry_gone(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/// Whether a new cutter for this ship would be a second one in the same incident
/datum/outpost_police_pursuit/proc/is_current()
	if(dispatching)
		return TRUE
	if(director && !QDELETED(director) && !director.hunt_over)
		return TRUE
	return world.time < ends_at

/// The outpost the ship was wanted at
/datum/outpost_police_pursuit/proc/outpost()
	var/datum/outpost_police/police = police_ref?.resolve()
	return police?.outpost

/// What the cutter is called: the force that sent it, then "cutter"
/datum/outpost_police_pursuit/proc/cutter_name()
	var/datum/outpost_police/police = police_ref?.resolve()
	return capitalize("[police?.profile?.force_name || "port authority"] cutter")

/// The cutter was paid: the crew's warrants, priors and bars are cleared where it was wanted (everywhere at five
/// stars, where every outpost put it under embargo), and pardon_crew() lifts the embargo with them. Never sleeps.
/datum/outpost_police_pursuit/proc/pardon()
	SHOULD_NOT_SLEEP(TRUE)
	var/datum/voidcrew_crew_record/crew = crew_ref?.resolve()
	if(!crew)
		return
	if(stars >= 5)
		for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
			outpost.police?.pardon_crew(crew)
	else
		var/datum/outpost_police/police = police_ref?.resolve()
		police?.pardon_crew(crew)
	// A paid incident is over: the next one gets its own cutter
	ends_at = 0

/**
 * Sends the cutter after `ship` once per incident (spec 9). Called when an embargoed ship finishes undocking
 * from this outpost (police_wanted.dm). Returns TRUE when a cutter was ordered, FALSE when not: not a ship, under
 * four stars, or a cutter already sent for this ship's incident. Never sleeps: the hull loads on its own.
 */
/datum/outpost_police/proc/start_pursuit(obj/structure/overmap/ship/ship, stars, officers_killed)
	SHOULD_NOT_SLEEP(TRUE)
	if(!istype(ship) || QDELETED(ship) || QDELETED(src))
		return FALSE
	// The cutter is for four stars and up (spec 9)
	if(stars < 4)
		return FALSE
	var/datum/weakref/ship_ref = WEAKREF(ship)
	var/datum/outpost_police_pursuit/old = GLOB.outpost_police_pursuits[ship_ref]
	if(old)
		if(old.is_current())
			return FALSE
		qdel(old)
	var/datum/outpost_police_pursuit/pursuit = new(src, ship, stars, officers_killed)
	GLOB.outpost_police_pursuits[ship_ref] = pursuit
	INVOKE_ASYNC(src, PROC_REF(dispatch_cutter), pursuit)
	return TRUE

/// Sleeps while the cutter's hull loads. Nothing coming (no clear tile, a failed load) forgets the order, so the
/// ship's next undock tries again.
/datum/outpost_police/proc/dispatch_cutter(datum/outpost_police_pursuit/pursuit)
	var/obj/structure/overmap/ship/quarry = pursuit.quarry_ref?.resolve()
	if(!quarry || QDELETED(quarry))
		qdel(pursuit)
		return
	var/datum/nt_patrol_director/police/director = dispatch_nt_patrol(quarry, pursuit.fine, null, /obj/structure/overmap/ship/npc/pirate/nt_patrol/police, /datum/nt_patrol_director/police)
	if(QDELETED(pursuit))
		return
	pursuit.dispatching = FALSE
	if(!director)
		qdel(pursuit)
		return
	pursuit.director = director
	log_game("OUTPOST POLICE: cutter sent after [quarry.name] from [outpost?.name] ([pursuit.stars] stars, fine [pursuit.fine], [pursuit.officers_killed] officers killed).")

// ===== THE SHIP =====

/// The cutter: the customs corvette's hunt on a stripped copy of its hull, with nothing aboard worth boarding it for
/obj/structure/overmap/ship/npc/pirate/nt_patrol/police
	name = "port authority cutter"
	desc = "A port authority patrol cutter on a warrant run."
	shuttle_template = /datum/map_template/shuttle/voidcrew/police_cutter
	// Its holopad captain and voice are the cutter's own (the chained overrides at the end of this file)
	pirate_faction = "police_cutter"
	negotiation_dialog_type = /datum/pirate_faction_dialog/police_cutter

	// An empty hold: a cutter is nobody's payday (abuse M9)
	hold_credits_min = 0
	hold_credits_max = 0

	captain_type = /mob/living/carbon/human/npc/faction_pirate/nt_customs/sergeant/police
	crew_types = list(
		/mob/living/carbon/human/npc/faction_pirate/nt_customs/officer/police,
		/mob/living/carbon/human/npc/faction_pirate/nt_customs/inspector/police,
		/mob/living/carbon/human/npc/faction_pirate/nt_customs/inspector/police,
	)
	boarding_pod_mob_types = list(
		/mob/living/carbon/human/npc/faction_pirate/nt_customs/officer/police,
		/mob/living/carbon/human/npc/faction_pirate/nt_customs/inspector/police,
	)
	boss_type = /mob/living/carbon/human/npc/faction_pirate/nt_customs/director/police
	wave_taunts = list(
		list(  // Wave 1 -> 2 cooldown
			"Boarding teams away. Stay where you are.",
			"Officers are coming over. Don't make it worse for them.",
		),
		list(  // Wave 2 -> 3 cooldown
			"More officers are coming over. Hands where we can see them.",
			"Those were our people you hurt. Stand down.",
		),
		list(  // Boss spawn
			"The commander is coming over himself. Last warning.",
			"Lay down your weapons. The commander is on his way.",
		),
	)

// ===== THE HUNT =====

/// The cutter's hunt: its own voice, six minutes of patience, the wanted outpost's docking time not counted,
/// a payment that pardons the crew, and a stand-down when the embargo ends
/datum/nt_patrol_director/police
	/// How long the ship has sat docked at the wanted outpost without costing the cutter patience (deciseconds)
	var/lurk_time = 0
	/// TRUE once the cutter is leaving because the embargo has ended
	var/standing_down = FALSE

/datum/nt_patrol_director/police/New(obj/structure/overmap/ship/npc/pirate/nt_patrol/ship, obj/structure/overmap/ship/quarry)
	. = ..()
	var/datum/outpost_police_pursuit/pursuit = get_pursuit()
	if(!pursuit)
		return
	pursuit.director = src
	// Named for the force that sent it, before the hail goes out
	ship.name = pursuit.cutter_name()

/// The record of the incident this hunt serves, or null (an admin-built hunt has none)
/datum/nt_patrol_director/police/proc/get_pursuit()
	return quarry_ref ? GLOB.outpost_police_pursuits[quarry_ref] : null

/datum/nt_patrol_director/police/hail_line(obj/structure/overmap/ship/quarry)
	var/datum/outpost_police_pursuit/pursuit = get_pursuit()
	var/outpost_name = pursuit?.outpost()?.name
	if(outpost_name)
		return "[patrol_ship.name]: \"[quarry.name], heave to. You left [outpost_name] with trouble behind you.\""
	return "[patrol_ship.name]: \"[quarry.name], heave to. There is a warrant on your crew.\""

/datum/nt_patrol_director/police/reengage_line_patrol(obj/structure/overmap/ship/quarry)
	return "[quarry.name] is under way again. Closing."

/datum/nt_patrol_director/police/reengage_line_quarry(obj/structure/overmap/ship/quarry)
	return "[patrol_ship.name] has picked you up again."

/datum/nt_patrol_director/police/departure_line(obj/structure/overmap/ship/quarry)
	return "[patrol_ship.name] has logged your payment."

/datum/nt_patrol_director/police/break_off_line(obj/structure/overmap/ship/quarry)
	if(standing_down)
		return "[patrol_ship.name]: \"The embargo is lifted. Standing down.\""
	return "[patrol_ship.name]: \"Breaking off. Your file stays open.\""

/// Six minutes without a target (OUTPOST_POLICE_CUTTER_GIVEUP)
/datum/nt_patrol_director/police/giveup_time()
	return OUTPOST_POLICE_CUTTER_GIVEUP

/// Time the ship sits docked at the outpost it is wanted at is not counted against the cutter's patience, up to
/// twenty minutes of it in all (OUTPOST_POLICE_CUTTER_LURK_MAX); after that it counts like any other
/datum/nt_patrol_director/police/counts_as_targetless(obj/structure/overmap/ship/quarry, step)
	var/obj/structure/overmap/trader_outpost/origin = get_pursuit()?.outpost()
	if(origin && quarry.docked == origin && lurk_time < OUTPOST_POLICE_CUTTER_LURK_MAX)
		lurk_time += step
		return FALSE
	return TRUE

/// Whether no outpost still holds the ship under embargo
/datum/nt_patrol_director/police/proc/embargo_over()
	var/obj/structure/overmap/ship/quarry = quarry_ref?.resolve()
	if(!quarry || QDELETED(quarry))
		return FALSE
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		if(outpost.is_ship_embargoed(quarry))
			return FALSE
	return TRUE

/datum/nt_patrol_director/police/hunt_tick()
	// The embargo ran out (or was lifted): the incident is over and the cutter goes home. A paid cutter is
	// already leaving by its own line.
	if(!hunt_over && !fine_paid && patrol_ship && !QDELETED(patrol_ship) && !patrol_ship.is_disabled && embargo_over())
		standing_down = TRUE
		break_off()
		return
	return ..()

/// Payment (or goods handed over) settles the incident: the parent starts the departure, this pardons the crew
/datum/nt_patrol_director/police/on_negotiation_ended(datum/source, datum/pirate_negotiation/negotiation, success)
	SIGNAL_HANDLER
	var/was_paid = fine_paid
	. = ..()
	if(success && !was_paid && fine_paid)
		INVOKE_ASYNC(src, PROC_REF(pardon_quarry))

/datum/nt_patrol_director/police/proc/pardon_quarry()
	get_pursuit()?.pardon()

// ===== THE CREW =====
// Port security off the cutter: the customs corvette's crew in the same roles and the same guns (the zone ladder
// of nt_patrol.dm's outfit table), in police kit and with their own voice. They drop nothing, as before: gear
// locked, no loot pool, no cash.

/// What the cutter's crew says when things happen to their bodies (human_npc_barks.dm): the customs' emotes and
/// bark chances, in port security's words
/datum/human_npc_voice/nt_customs/police_cutter
	lines = list(
		PIRATE_BARK_SPOT = list("Port Authority! Stay where you are!", "There. Hold them.", "Contact. Detain them."),
		HUMAN_NPC_BARK_DOWNED = list("Officer down!", "Medic!"),
		HUMAN_NPC_BARK_PLEAD = list("Stand down... you're under arrest...", "You're making it worse..."),
		HUMAN_NPC_BARK_RECOVER = list("Back on my feet.", "Still here."),
		HUMAN_NPC_BARK_CUFFED = list("You're cuffing an officer. Think about that.", "That's going on your sheet."),
		HUMAN_NPC_BARK_SLIPPING = list("Almost..."),
		HUMAN_NPC_BARK_PULLED_FREE = list("Hands off!"),
	)

/// Port security, rank and file
/mob/living/carbon/human/npc/faction_pirate/nt_customs/officer/police
	npc_name = "Port Security Officer"
	crew_desc = "A port security officer off the cutter, here to board you. The baton is standard issue."
	npc_outfit_table = /datum/human_npc_outfit_table/pirate/nt_customs/police
	boarding_outfit_table = /datum/human_npc_outfit_table/pirate/nt_customs/police/boarding
	npc_voice = /datum/human_npc_voice/nt_customs/police_cutter
	crew_alert_lines = list(
		"Boarders on the cutter. Detain them.",
		"Intruders aboard. Weapons free.",
		"All officers, we have a breach.",
	)
	crew_spot_lines = list(
		"Port Authority! Stay where you are!",
		"There. Hold them.",
		"Contact. Detain them.",
	)

/// Port security marksman: a sidearm, or a WT-550 in the red zone
/mob/living/carbon/human/npc/faction_pirate/nt_customs/inspector/police
	npc_name = "Port Security Marksman"
	crew_desc = "A port security marksman off the cutter. They carry a sidearm and a warrant."
	npc_outfit_table = /datum/human_npc_outfit_table/pirate/nt_customs/police
	boarding_outfit_table = /datum/human_npc_outfit_table/pirate/nt_customs/police/boarding
	npc_voice = /datum/human_npc_voice/nt_customs/police_cutter
	crew_alert_lines = list(
		"Boarders on the cutter. Detain them.",
		"Intruders aboard. Weapons free.",
		"All officers, we have a breach.",
	)
	crew_spot_lines = list(
		"Port Authority! Stay where you are!",
		"There. Hold them.",
		"Contact. Detain them.",
	)

/// The cutter's senior officer: its captain, who carries its key
/mob/living/carbon/human/npc/faction_pirate/nt_customs/sergeant/police
	npc_name = "Port Security Sergeant"
	crew_desc = "The senior officer aboard the cutter."
	npc_outfit_table = /datum/human_npc_outfit_table/pirate/nt_customs/police
	boarding_outfit_table = /datum/human_npc_outfit_table/pirate/nt_customs/police/boarding
	npc_voice = /datum/human_npc_voice/nt_customs/police_cutter
	crew_alert_lines = list(
		"Boarders on the cutter. Detain them.",
		"Intruders aboard. Weapons free.",
		"All officers, we have a breach.",
	)
	crew_spot_lines = list(
		"Port Authority! Stay where you are!",
		"There. Hold them.",
		"Contact. Detain them.",
	)

/// The cutter's commander: the boss it sends last. Killing or taking him disables the cutter, and he leaves
/// nothing behind: no e-gun, no baton, no fines (abuse M9).
/mob/living/carbon/human/npc/faction_pirate/nt_customs/director/police
	npc_name = "Port Security Commander"
	crew_desc = "The cutter's commander, sent over when the officers aren't enough."
	npc_outfit_table = /datum/human_npc_outfit_table/pirate/nt_customs/police
	boarding_outfit_table = /datum/human_npc_outfit_table/pirate/nt_customs/police/boarding
	npc_voice = /datum/human_npc_voice/nt_customs/police_cutter
	loot_pool = null
	npc_death_cash = 0
	crew_alert_lines = list(
		"Boarders on the cutter. Detain them.",
		"Intruders aboard. Weapons free.",
		"All officers, we have a breach.",
	)
	crew_spot_lines = list(
		"Port Authority! Stay where you are!",
		"There. Hold them.",
		"Contact. Detain them.",
	)

// ===== Outfits: the customs kit's weapons in port security's clothes =====

/// The cutter's table: the corvette's, with port security's outfits in each role
/datum/human_npc_outfit_table/pirate/nt_customs/police
	melee = list(/datum/outfit/nanotrasensoldiercorpse/nt_customs_officer/police = 1)
	gunners = list(/datum/outfit/nanotrasensoldiercorpse/nt_customs_inspector/police = 1)
	elite = list(/datum/outfit/nanotrasenassaultsoldiercorpse/nt_customs_sergeant/police = 1)
	boss = list(/datum/outfit/police_cutter_commander = 1)
	red_gunners = list(/datum/outfit/nanotrasensoldiercorpse/nt_customs_inspector/smg/police = 1)
	red_elite = list(/datum/outfit/nanotrasenassaultsoldiercorpse/nt_customs_sergeant/rifle/police = 1)

/// Boarders cross space: a sealed suit and air, as the corvette's do
/datum/human_npc_outfit_table/pirate/nt_customs/police/boarding
	always_site = HUMAN_NPC_SITE_VACUUM

/datum/outfit/nanotrasensoldiercorpse/nt_customs_officer/police
	name = "Human NPC: Port Security Officer"
	head = /obj/item/clothing/head/helmet/sec
	mask = /obj/item/clothing/mask/gas/sechailer
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/job/security_officer

/datum/outfit/nanotrasensoldiercorpse/nt_customs_inspector/police
	name = "Human NPC: Port Security Marksman"
	head = /obj/item/clothing/head/helmet/sec
	mask = /obj/item/clothing/mask/gas/sechailer
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/job/security_officer

/datum/outfit/nanotrasensoldiercorpse/nt_customs_inspector/smg/police
	name = "Human NPC: Port Security Marksman (WT-550)"
	head = /obj/item/clothing/head/helmet/sec
	mask = /obj/item/clothing/mask/gas/sechailer
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/job/security_officer

/datum/outfit/nanotrasenassaultsoldiercorpse/nt_customs_sergeant/police
	name = "Human NPC: Port Security Sergeant"
	uniform = /obj/item/clothing/under/rank/security/warden
	suit = /obj/item/clothing/suit/armor/vest/warden
	head = /obj/item/clothing/head/hats/warden/police
	mask = /obj/item/clothing/mask/gas/sechailer
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/job/security_officer

/datum/outfit/nanotrasenassaultsoldiercorpse/nt_customs_sergeant/rifle/police
	name = "Human NPC: Port Security Sergeant (rifle)"
	uniform = /obj/item/clothing/under/rank/security/warden
	suit = /obj/item/clothing/suit/armor/vest/warden
	head = /obj/item/clothing/head/hats/warden/police
	mask = /obj/item/clothing/mask/gas/sechailer
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/job/security_officer

/// The commander: the corvette's Director's gear (a lethal e-gun and a baton) in a security chief's coat
/datum/outfit/police_cutter_commander
	name = "Human NPC: Port Security Commander"
	uniform = /obj/item/clothing/under/rank/security/head_of_security
	suit = /obj/item/clothing/suit/armor/hos
	shoes = /obj/item/clothing/shoes/combat
	gloves = /obj/item/clothing/gloves/combat
	mask = /obj/item/clothing/mask/gas/sechailer
	head = /obj/item/clothing/head/hats/hos/beret
	back = /obj/item/storage/backpack/security
	belt = /obj/item/melee/baton/security/loaded
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/job/head_of_security
	r_hand = /obj/item/gun/energy/e_gun/lethal
	l_pocket = /obj/item/knife/combat/survival

// ===== THE NEGOTIATION =====

/datum/pirate_faction_dialog/police_cutter
	faction_name = "Outpost Cutter"
	demand_multiplier = 1.0
	patience_modifier = 1.0

	greetings = list(
		"Vessel, this is the outpost cutter. Cut your engines.",
		"Heave to. The outpost has a warrant out on your crew.",
		"Attention vessel. Outpost authority. Hold your position.",
	)
	demand_lines = list(
		"You owe %CREDITS% credits for what you did at that outpost. Pay it, or hand over %QUANTITY% %ITEM%, and we're done.",
		"The fine is %CREDITS% credits. We'll take %QUANTITY% %ITEM% instead if you'd rather.",
		"%CREDITS% credits clears it. So does %QUANTITY% %ITEM%. Your call.",
	)
	barter_demand_lines = list(
		"Your accounts are empty. Put %QUANTITY% %ITEM% on the pad and we'll call it square.",
		"No money to take. %QUANTITY% %ITEM% will do.",
		"Nothing in your accounts. Hand over %QUANTITY% %ITEM%.",
	)
	barter_escalation_lines = list(
		"You're stalling. It's %QUANTITY% %ITEM% now.",
		"The price just went up. %QUANTITY% %ITEM%.",
	)
	acceptance_lines = list(
		"Payment logged. You're clear. Don't come back with more trouble.",
		"Received. That squares it with the outpost.",
		"That settles it. Fly straight.",
	)
	rejection_lines = list(
		"Then we do this the hard way. Boarding teams away.",
		"Refusal logged. Officers are coming over.",
		"Your choice. Brace for boarders.",
	)
	timeout_lines = list(
		"Time's up. Boarding.",
		"You had your chance. Officers are going over.",
	)
	impatience_lines = list(
		"%SECONDS% seconds. Make up your mind.",
		"Still waiting. %SECONDS% seconds.",
	)
	flee_warning_lines = list(
		"Running won't help. We have you on scan.",
		"That's evasion on top of everything else.",
	)
	movement_betrayal_lines = list(
		"You were told. Open fire.",
		"Second warning ignored. Weapons free.",
	)
	escape_warning_lines = list(
		"Don't run, and don't shoot. We'll answer in kind.",
		"Hold position. Any move on us gets answered.",
	)

// ===== THE HOLOPAD CAPTAIN =====

/// The cutter's captain on the holopad: a security chief's uniform and cap
/datum/preset_holoimage/pirate_captain/police_cutter
	outfit_type = /datum/outfit/job/hos

// The hologram picks its voice and its captain's image by faction string in pirate_hologram.dm (npc_ships, included
// before this file). These two chain onto those procs, running first and falling through to them for every other
// faction, so the cutter gets its own captain without an edit there.
/obj/effect/overlay/holo_pad_hologram/pirate/get_faction_voice_pack(faction)
	if(faction == "police_cutter")
		return "goon.bottalk_1" // bureaucratic monotone, as the customs patrol
	return ..()

/obj/effect/overlay/holo_pad_hologram/pirate/get_faction_holoimage(faction)
	if(faction == "police_cutter")
		return new /datum/preset_holoimage/pirate_captain/police_cutter()
	return ..()

/**
 * # Prospect Stake
 *
 * "Plant our claim beacon on this rock and keep it standing until the claim
 * matures. The filing goes out on Wideband, so expect... interest."
 *
 * The announced PvP flashpoint as a mission: a claim kit is dispensed at
 * accept, and the crew lands on a contested or lawless planet to raise it on
 * open ground, clear of the landing field and any parked hull. Deploying it
 * files the claim galaxy-wide - the contested-cache broadcast pattern - and
 * starts a defend clock that only runs while a crew member stands guard at
 * the beacon. Waves answer the filing on the ground around it; red space
 * means anyone else can too. The beacon survives, it prints a bonded deed for
 * the pad. Objectives: [deploy & defend] -> [carry the deed home].
 */
/datum/mission/prospect_stake
	name = "Prospect Stake"
	guarded_prize_family = "stake"
	weight = 6
	mission_limit = 1
	duration = 40 MINUTES
	quest_lost_policy = MISSION_QUEST_LOST_FAIL // the beacon IS the contract
	gps_tag_prefix = "CLAIM"
	// Top of the mission pay curve - it's an announced fight
	value_min = 1400
	value_max = 1800
	voucher_count = 1

	/// zone_mobs theme answering the claim
	var/wave_theme
	/// The defense objective (kit dispensing at start)
	var/datum/mission_objective/claim_defense/defense

/datum/mission/prospect_stake/Destroy()
	defense = null
	return ..()

/datum/mission/prospect_stake/get_archetype()
	return "claim"

/**
 * Picks the planet to stake. An offer pinned to a band (the reserved top-band
 * slots, the unarmed green bias) only tries that band, and a green pin finds
 * nothing. Otherwise the band is rolled, falling back to the other band when
 * the rolled one has no world to offer.
 */
/datum/mission/prospect_stake/setup_target()
	var/list/bands = list()
	if(!isnull(preferred_zone))
		bands += preferred_zone
	else
		// Yellow stakes are the on-ramp; red is the real thing
		var/list/weights = list(
			"[ZONE_YELLOW]" = 45,
			"[ZONE_RED]" = 55,
		)
		while(length(weights))
			var/band_key = pick_weight(weights)
			weights -= band_key
			bands += text2num(band_key)
	for(var/band in bands)
		var/datum/mission_target/planet/claim_site/site = new(src)
		site.preferred_zone = band
		if(site.resolve())
			target = site
			return TRUE
		qdel(site)
	return FALSE

/datum/mission/prospect_stake/generate_details()
	objective_name = "notarized claim deed"
	wave_theme = pick_weight(MISSION_WAVE_THEMES)

/datum/mission/prospect_stake/build_objectives()
	defense = new
	defense.wave_theme = wave_theme
	add_objective(defense)
	add_objective(new /datum/mission_objective/deliver/bound)

/datum/mission/prospect_stake/on_mission_started()
	defense?.dispense_kit()

/datum/mission/prospect_stake/update_text()
	var/datum/mission_target/planet/site = target
	var/site_name = istype(site) ? (site.planet?.name || "the planet") : "the planet"
	name = "Prospect Stake: [site_name]"
	desc = "File our mineral-rights claim on [site_name] at ([target.target_x], [target.target_y]) in the [target_zone_name]."

/datum/mission/prospect_stake/waypoint_label()
	return "Prospect stake"

// =========================================================================
// CLAIM SITE: a real world to stand on
// =========================================================================

/**
 * # Claim Site
 *
 * The planet target narrowed to ground a claim can stand on: terrain worlds
 * only (GLOB.overmap_planets also holds empty-space dock placeholders, crash
 * sites and weak signals, none of which have any), and never neutral space.
 * Picks a biome first and hands it to the planet target's wanted_planet
 * filter, so every other rule (exclusivity, occupancy, field contacts,
 * relocation tracking) is the planet target's own.
 */
/datum/mission_target/planet/claim_site
	/// Biomes a field contact may be minted as when no terrain world is on offer
	var/static/list/claim_biomes = list(
		/datum/overmap/planet/lava,
		/datum/overmap/planet/ice,
		/datum/overmap/planet/jungle,
		/datum/overmap/planet/beach,
		/datum/overmap/planet/wasteland,
	)

/// Claims are filed in contested and lawless space only
/datum/mission_target/planet/claim_site/zone_is_eligible(band)
	return band != ZONE_GREEN && ..()

/datum/mission_target/planet/claim_site/resolve()
	var/list/biomes = list()
	for(var/obj/structure/overmap/planet/candidate as anything in GLOB.overmap_planets)
		if(QDELETED(candidate) || candidate == planet || candidate.mission_exclusive || !candidate.is_terrain_planet())
			continue
		if(!istype(get_turf(candidate), /turf/open/overmap) || !zone_is_eligible(SSovermap_zones?.get_zone_type(get_turf(candidate))))
			continue
		biomes |= candidate.planet
	if(!length(biomes))
		// Never mint a contact in a band no claim can use (a green-pinned reserved slot
		// would leave a stray planet on the chart for an offer that then fails)
		if(!mission?.create_field_contact || !zone_is_eligible(preferred_zone))
			unhook()
			return FALSE
		// Nothing standing in the band: the planet target mints a contact of this biome
		biomes = claim_biomes
	wanted_planet = pick(biomes)
	return ..()

/**
 * Why a claim beacon can't stand on this turf, as a balloon line, or null if
 * it can. Open, solid ground on this world's own surface or caves - never a
 * deck, a ruin, space, lava, water or a chasm - and clear of the landing
 * berths and any parked hull, so no ship comes down on the claim and no wave
 * lands on somebody's floor.
 */
/datum/mission_target/planet/claim_site/proc/claim_ground_refusal(turf/spot)
	if(!spot || !isopenturf(spot) || isgroundlessturf(spot) || !contains_turf(spot))
		return "no claim ground here!"
	if(!istype(get_area(spot), /area/overmap_encounter/planetoid) || spot.is_blocked_turf(exclude_mobs = TRUE))
		return "no claim ground here!"
	var/datum/space_level/level = length(planet.mapzone?.z_levels) ? planet.mapzone.z_levels[1] : null
	var/strip_top = planet.get_dock_strip_top_y(level)
	if(!isnull(strip_top) && spot.y <= strip_top)
		return "too close to the landing field!"
	// One tile past where a wave can scatter, so no arrival lands on a deck
	for(var/turf/nearby as anything in RANGE_TURFS(ZONE_MOBS_WAVE_SCATTER + 1, spot))
		if(istype(nearby.loc, /area/shuttle))
			return "too close to a ship!"
	return null

/**
 * # Claim Beacon Kit
 *
 * The packed beacon handed over at accept. Use in hand on open ground at the
 * claim site; the deployment channel raises the beacon on the spot you're
 * standing.
 */
/obj/item/claim_beacon_kit
	name = "claim beacon kit"
	desc = "A folded prospecting claim beacon, bonded and pre-registered."
	icon = 'voidcrew/modules/missions/icons/recovery.dmi'
	icon_state = "recovery_anchored"
	w_class = WEIGHT_CLASS_BULKY

	/// Weakref to the claim_defense objective this kit serves
	var/datum/weakref/objective_ref

/obj/item/claim_beacon_kit/attack_self(mob/user)
	. = ..()
	if(.)
		return
	var/datum/mission_objective/claim_defense/objective = objective_ref?.resolve()
	if(!objective?.mission || objective.mission.failed || objective.mission.completed || !objective.active)
		balloon_alert(user, "contract expired!")
		return TRUE
	var/refusal = claim_refusal(objective, get_turf(user))
	if(refusal)
		balloon_alert(user, refusal)
		return TRUE
	balloon_alert(user, "deploying beacon...")
	playsound(src, 'sound/items/tools/ratchet.ogg', 60, TRUE)
	if(!do_after(user, 8 SECONDS, target = user))
		balloon_alert(user, "deployment interrupted!")
		return TRUE
	if(!objective.mission || objective.mission.failed || objective.mission.completed || !objective.active)
		return TRUE
	refusal = claim_refusal(objective, get_turf(user))
	if(refusal)
		balloon_alert(user, refusal)
		return TRUE
	objective.deploy(user, get_turf(user))
	return TRUE

/// Why the beacon can't go up here, or null if it can
/obj/item/claim_beacon_kit/proc/claim_refusal(datum/mission_objective/claim_defense/objective, turf/spot)
	var/datum/mission_target/planet/claim_site/site = objective.mission?.target
	if(!istype(site))
		return "no claim ground here!"
	return site.claim_ground_refusal(spot)

/**
 * # Claim Beacon
 *
 * The deployed stake: destructible on purpose - defending it is the mission.
 * Ticks the defend clock while a crew member stands guard, calls its own
 * waves, and files every beat on Wideband like the contested cache does.
 */
/obj/structure/mission_claim_beacon
	name = "prospecting claim beacon"
	desc = "A registered mineral-rights beacon, broadcasting its claim on every open channel."
	icon = 'voidcrew/modules/missions/icons/recovery.dmi'
	icon_state = "survey_pylon"
	anchored = TRUE
	density = TRUE
	max_integrity = 400
	// Driven into the ground: wind, force pushes and gravity never shift it off the claim
	move_resist = INFINITY

	/// Weakref to the claim_defense objective driving this beacon
	var/datum/weakref/objective_ref
	/// Internal wideband transmitter (the contested-cache broadcast pattern)
	var/obj/item/radio/headset/radio

/obj/structure/mission_claim_beacon/Initialize(mapload)
	. = ..()
	radio = new(src)
	radio.subspace_transmission = TRUE
	radio.canhear_range = 0
	radio.set_listening(FALSE)
	radio.recalculateChannels()
	START_PROCESSING(SSobj, src)

/obj/structure/mission_claim_beacon/Destroy()
	STOP_PROCESSING(SSobj, src)
	QDEL_NULL(radio)
	var/datum/mission_objective/claim_defense/objective = objective_ref?.resolve()
	objective_ref = null
	objective?.on_beacon_destroyed()
	return ..()

/obj/structure/mission_claim_beacon/process(seconds_per_tick)
	var/datum/mission_objective/claim_defense/objective = objective_ref?.resolve()
	if(!objective)
		return PROCESS_KILL
	objective.tick_defense(seconds_per_tick)

/// Galaxy-wide filing: Wideband + priority announcement, like the contested cache
/obj/structure/mission_claim_beacon/proc/file_claim(message)
	priority_announce(message, "Prospect Filing", sender_override = "Sector Claims Registry")
	radio?.talk_into(src, message, RADIO_CHANNEL_WIDEBAND)

/// The claim matured: stop being a mission object, stay as scenery
/obj/structure/mission_claim_beacon/proc/retire()
	STOP_PROCESSING(SSobj, src)
	objective_ref = null
	name = "matured claim beacon"
	desc = "A prospecting beacon whose claim has matured and printed. It hums contentedly."

/obj/structure/mission_claim_beacon/examine(mob/user)
	. = ..()
	var/datum/mission_objective/claim_defense/objective = objective_ref?.resolve()
	if(objective)
		. += span_boldwarning("[objective.get_progress_string()].")

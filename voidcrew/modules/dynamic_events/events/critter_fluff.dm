/**
 * Ship-scoped ports of TG's harmless critter fluff events:
 * Mice Migration (code/modules/events/mice_migration.dm),
 * Wisdom Cow (code/modules/events/wisdomcow.dm) and
 * Sentience (code/modules/events/ghost_role/sentience.dm).
 * See voidcrew/GUIDES/dynamic_events_port_spec.md
 */

/datum/round_event_control/voidcrew/mice_migration
	name = "Mice Migration"
	typepath = /datum/round_event/voidcrew/mice_migration
	weight = 10
	category = EVENT_CATEGORY_ENTITIES
	description = "A small horde of mice chews its way into the target ship's hull spaces."
	allowed_zones = null
	min_crew_aboard = 1

/datum/round_event/voidcrew/mice_migration
	/// Smallest migration pack: scaled down from TG's 5 for a ship's handful of crew.
	var/minimum_mice = 2
	/// Largest migration pack: scaled down from TG's 15.
	var/maximum_mice = 4

/datum/round_event/voidcrew/mice_migration/announce(fake)
	if(!target_valid())
		return
	var/cause = pick("space-winter", "budget-cuts", "Ragnarok",
		"space being cold", "\[REDACTED\]", "climate change",
		"bad luck")
	var/plural = pick("a number of", "a horde of", "a pack of", "a swarm of",
		"a whoop of", "not more than [maximum_mice]")
	var/critters = pick("rodents", "mice", "squeaking things",
		"wire eating mammals", "\[REDACTED\]", "energy draining parasites")
	var/movement = pick("migrated", "swarmed", "stampeded", "descended", "chewed their way")
	var/location = pick("hull spaces", "cargo hold", "crawlspace under the deck",
		"place with all those juicy wires")

	target_ship.ship_event_announce("Due to [cause], [plural] [critters] have [movement] \
		into the [location].", "Migration Alert",
		'sound/mobs/non-humanoids/mouse/mousesqueek.ogg')

/datum/round_event/voidcrew/mice_migration/start()
	if(!target_valid())
		return
	for(var/i in 1 to rand(minimum_mice, maximum_mice))
		var/turf/open/floor/spawn_turf = target_ship.get_random_open_ship_turf()
		if(!spawn_turf)
			return // Nowhere open left aboard, the rest of the horde stays in the walls.
		new /mob/living/basic/mouse(spawn_turf)

/datum/round_event_control/voidcrew/wisdom_cow
	name = "Wisdom Cow"
	typepath = /datum/round_event/voidcrew/wisdom_cow
	max_occurrences = 1
	weight = 20
	category = EVENT_CATEGORY_FRIENDLY
	description = "A cow appears aboard the target ship to tell the crew wise words."
	allowed_zones = null
	min_crew_aboard = 1

/datum/round_event/voidcrew/wisdom_cow/announce(fake)
	if(!target_valid())
		return
	target_ship.ship_event_announce("A wise cow has been spotted aboard the vessel. Be sure to ask for her advice.", "Nanotrasen Cow Ranching Agency")

/datum/round_event/voidcrew/wisdom_cow/start()
	if(!target_valid())
		return
	var/turf/open/floor/spawn_turf = target_ship.get_random_open_ship_turf()
	if(!spawn_turf)
		return
	var/mob/living/basic/cow/wisdom/wise = new(spawn_turf)
	do_smoke(1, holder = wise, location = spawn_turf)
	announce_to_ghosts(wise)

/datum/round_event_control/voidcrew/sentience
	name = "Random Human-level Intelligence"
	typepath = /datum/round_event/voidcrew/sentience
	weight = 10
	category = EVENT_CATEGORY_FRIENDLY
	description = "An animal or robot aboard the target ship becomes sentient!"
	allowed_zones = null
	min_crew_aboard = 1

/datum/round_event_control/voidcrew/sentience/can_spawn_event(players_amt, allow_magic = FALSE)
	. = ..()
	if(!.)
		return FALSE
	// TG gates sentience behind the ghost-role toggle via its ghost_role typepath check;
	// this is a voidcrew subtype, so the same gate is repeated here.
	return !!(GLOB.ghost_role_flags & GHOSTROLE_MIDROUND_EVENT)

/datum/round_event_control/voidcrew/sentience/is_valid_target(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return FALSE
	// No point polling ghosts aboard a ship with nothing to uplift.
	return length(get_candidate_animals(ship)) > 0

/**
 * Every valid sentience target aboard the ship, per TG's candidate rules: simple or
 * basic animals, alive, not player-controlled, not holograms. Recognisable pets
 * (GLOB.high_priority_sentience) are shuffled to the front like TG prioritises them.
 */
/datum/round_event_control/voidcrew/sentience/proc/get_candidate_animals(obj/structure/overmap/ship/ship)
	var/list/high_priority = list()
	var/list/low_priority = list()
	for(var/mob/living/checked_mob as anything in ship.get_all_mobs_aboard())
		if(!isanimal(checked_mob) && !isbasicmob(checked_mob))
			continue
		if((checked_mob in GLOB.player_list) || checked_mob.mind || (checked_mob.flags_1 & HOLOGRAM_1))
			continue
		if(is_type_in_typecache(checked_mob, GLOB.high_priority_sentience))
			high_priority += checked_mob
		else
			low_priority += checked_mob
	shuffle_inplace(high_priority)
	shuffle_inplace(low_priority)
	return high_priority + low_priority

/datum/round_event/voidcrew/sentience
	/// Name of the role, displayed in the ghost poll, logs and admin messages.
	var/role_name = "random animal"
	/// Number of ghost signups required for the event to go through.
	var/minimum_required = 1
	/// How many animals to uplift. Bounded in practice by whichever runs out first,
	/// the volunteers or the livestock.
	var/animals_to_uplift = 1

/datum/round_event/voidcrew/sentience/announce(fake)
	if(!target_valid())
		return
	var/data = pick("scans from our long-range sensors", "our sophisticated probabilistic models", "our omnipotence", "the communications traffic on your vessel", "energy emissions we detected", "\[REDACTED\]")
	var/pets = pick("animals/bots", "bots/animals", "pets", "simple animals", "lesser lifeforms", "\[REDACTED\]")
	var/strength = pick("human", "moderate", "lizard", "security", "command", "clown", "low", "very low", "\[REDACTED\]")

	target_ship.ship_event_announce("Based on [data], we believe that one of the vessel's [pets] has developed [strength] level intelligence, and the ability to communicate.", "Medium-Priority Update")

/**
 * Replicates the essential flow of TG's ghost_role base: poll ghost candidates first
 * and let the announcement fire only if an animal actually gets possessed.
 * start() sleeps for the poll duration; /datum/round_event/process() holds processing
 * FALSE around start(), so the event pauses until the poll concludes, then announces on
 * success or quietly kills itself (announce_chance = 0) on failure.
 */
/datum/round_event/voidcrew/sentience/start()
	if(!target_valid())
		return
	var/list/mob/dead/observer/candidates = SSpolling.poll_ghost_candidates(check_jobban = ROLE_SENTIENCE, role = ROLE_SENTIENCE, alert_pic = /obj/item/slimepotion/slime/sentience, role_name_text = role_name)
	if(length(candidates) < minimum_required)
		message_admins("[role_name] event aboard [target_ship.display_name || target_ship.name] got no ghost volunteers, fizzling.")
		deadchat_broadcast(" did not get enough candidates ([minimum_required]) to spawn.", "<b>[role_name]</b>", message_type = DEADCHAT_ANNOUNCEMENT)
		announce_chance = 0
		return
	if(!target_valid()) // The ship may have died while the ghosts were pondering.
		announce_chance = 0
		return
	var/datum/round_event_control/voidcrew/sentience/sentience_control = control
	var/list/potential = sentience_control.get_candidate_animals(target_ship)
	if(!length(potential))
		announce_chance = 0
		return
	var/uplifted = 0
	while(uplifted < animals_to_uplift && length(potential) && length(candidates))
		var/mob/living/selected = popleft(potential)
		var/mob/dead/observer/volunteer = pick_n_take(candidates)
		if(QDELETED(selected) || QDELETED(volunteer))
			continue

		selected.PossessByPlayer(volunteer.key)
		selected.grant_all_languages(UNDERSTOOD_LANGUAGE, grant_omnitongue = FALSE, source = LANGUAGE_ATOM)

		if(isanimal(selected))
			var/mob/living/simple_animal/animal_selected = selected
			animal_selected.sentience_act()
			animal_selected.del_on_death = FALSE
		else if(isbasicmob(selected))
			var/mob/living/basic/animal_selected = selected
			animal_selected.basic_mob_flags &= ~DEL_ON_DEATH

		selected.maxHealth = max(selected.maxHealth, 200)
		selected.health = selected.maxHealth

		to_chat(selected, span_userdanger("Hello world!"))
		to_chat(selected, span_warning("Due to freak radiation and/or chemicals \
			and/or lucky chance, you have gained human level intelligence \
			and the ability to speak and understand human language!"))
		announce_to_ghosts(selected)
		uplifted++

	if(!uplifted)
		announce_chance = 0

/**
 * Admin-only variant, as upstream: every animal and bot aboard wakes up, or as many as
 * there are ghosts willing to be one. Weight and occurrence cap are zero so it never
 * enters the random roster.
 */
/datum/round_event_control/voidcrew/sentience/all
	name = "Ship-wide Human-level Intelligence"
	typepath = /datum/round_event/voidcrew/sentience/all
	weight = 0
	max_occurrences = 0
	description = "EVERY animal and robot aboard the target ship becomes sentient, ghosts permitting."

/datum/round_event/voidcrew/sentience/all
	role_name = "ship-wide animal uplift"
	animals_to_uplift = INFINITY

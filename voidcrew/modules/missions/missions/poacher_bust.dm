/**
 * # Poacher Bust
 *
 * "An illegal hunting outfit is bleeding the protected ranges dry. Put the
 * squad down and bring back every trophy in their cache - the service needs
 * evidence, not excuses."
 *
 * A warden-service camp raid on a specific planet type: [fly to the planet] ->
 * [the camp field-spawns when the interior loads] -> [wipe the named squad] ->
 * [recover the tagged evidence] -> [pad turn-in]. Generation only offers busts
 * for planet types actually on the overmap this round (the wanted_planet
 * filter on the planet target), and the protected species, terrain and
 * evidence all come from a per-planet table.
 *
 * The squad is the fork's hermit family (simple_animal humanoids): scruffy
 * wild-country gunmen with working c38/c46x30mm casing fire, each renamed to
 * a generated poacher on spawn. Every death is attributed suppression-style
 * (last-attacker ckey or a living crew member in confirm range); unattributed
 * deaths still count - dead is dead, and the telemetry logs it - so the wipe
 * can never stall on a weather or wildlife kill.
 *
 * The evidence lives in a sealed trophy cache spawned WITH the camp rather
 * than as death drops: one sturdy quest atom carries the GPS beacon and the
 * loss policy through the whole field phase, and the bound pieces can't burn
 * in a lava pool under a dying poacher (a counted ask has no replacements).
 * Smashing the cache open early just dumps the pieces - closets dump contents
 * on destruction - the squad still has to die before the pad pays.
 *
 * Loss policy is FAIL, the big_game_hunt precedent: with one planet of each
 * type per round, a filtered retarget has nowhere to go. A live poacher
 * qdeleting without dying (site unload, admin cleanup) voids the contract the
 * same way losing the hunt's beast does; destroyed evidence kills the case.
 */
/datum/mission/poacher_bust
	name = "Poacher Bust"
	weight = 7
	mission_limit = 1
	duration = 40 MINUTES
	voucher_count = 2
	quest_lost_policy = MISSION_QUEST_LOST_FAIL
	gps_tag_prefix = "WARDN"
	// Green-band pay between field_expedition and big_game_hunt: a squad
	// fight plus a counted evidence haul, but no elite at the end of it.
	// The zone table makes a Lawless-zone bust a serious payday.
	value_min = 900
	value_max = 1200

	/// Per-planet bust tables, keyed by /datum/overmap/planet typepath: the
	/// protected species (named for the planet's actual fauna), the hunting
	/// ground flavor, the evidence-piece names, and the caged-critter type.
	/// EXISTING mobs/props only; the squad itself is always hermits.
	var/static/list/bust_tables = list(
		/datum/overmap/planet/lava = list(
			"species" = "goliath calves",
			"ground" = "ash barrens",
			"evidence" = list("plated goliath hide", "watcher lens cluster", "brimdemon fang rack", "goliath tendril whip"),
			"critter" = /mob/living/basic/lizard,
		),
		/datum/overmap/planet/ice = list(
			"species" = "ice whelp clutches",
			"ground" = "glacier fields",
			"evidence" = list("white wolf pelt", "ice whelp egg casing", "demon-sinew bowstring", "frost-tusk pair"),
			"critter" = /mob/living/basic/pet/penguin/baby,
		),
		/datum/overmap/planet/jungle = list(
			"species" = "canopy gorilla troops",
			"ground" = "deep canopy",
			"evidence" = list("cured gorilla pelt", "arachnid silk bolt", "chitin plate mount", "canopy plume fan"),
			"critter" = /mob/living/basic/butterfly,
		),
		/datum/overmap/planet/beach = list(
			"species" = "shore-carp shoals",
			"ground" = "drowned shallows",
			"evidence" = list("carp-skin boots", "mega-carp jaw arch", "salted trophy fin", "pearl-eye pendant"),
			"critter" = /mob/living/basic/crab,
		),
		/datum/overmap/planet/wasteland = list(
			"species" = "dune wolf packs",
			"ground" = "dead highways",
			"evidence" = list("dune wolf pelt", "tarantula fang crown", "bleached antler rack", "goliath scalp plate"),
			"critter" = /mob/living/basic/mouse,
		),
	)

	/// Poacher name fragments: every squad member gets a unique pair
	var/static/list/poacher_nicknames = list(
		"Snares", "Two-Trigger", "Deadfall", "Birdshot", "Saltlick", "Lampeye",
		"Halfjaw", "Smokey", "Wires", "Tallow", "Gutter", "Ratcatch",
	)
	var/static/list/poacher_surnames = list(
		"Okafor", "Tam", "Vance", "Mireles", "Kessler", "Draves",
		"Ferro", "Ashby", "Roan", "Petrov", "Sunday", "Obi",
	)

	/// /datum/overmap/planet typepath this bust is themed on
	var/bust_planet_type
	/// The rolled bust table row (points into the static table, never mutate)
	var/list/bust_row
	/// The rolled contract-grudge line (stable across text rebuilds)
	var/flavor_line
	/// The protected species phrase ("dune wolf packs")
	var/protected_species
	/// Named poachers in the squad (3 green / 4 yellow / 5 red)
	var/squad_count = 3
	/// Evidence pieces in the cache (2 green / 3 yellow / 4 red)
	var/evidence_count = 2
	/// Generated squad roster, trailboss first (built at generation)
	var/list/squad_names
	/// The camp-wipe objective (spawns the camp and cache on interior load)
	var/datum/mission_objective/field/wipe_camp/wipe
	/// The evidence turn-in objective (fed the bound pieces at camp spawn)
	var/datum/mission_objective/deliver/bound/poacher_evidence/evidence

/datum/mission/poacher_bust/Destroy()
	wipe = null
	evidence = null
	bust_row = null
	squad_names = null
	return ..()

/datum/mission/poacher_bust/get_archetype()
	return "bounty"

/datum/mission/poacher_bust/setup_target()
	// Only offer busts for planet types actually on the overmap this round
	var/list/present_types = list()
	for(var/obj/structure/overmap/planet/candidate as anything in GLOB.overmap_planets)
		if(QDELETED(candidate))
			continue
		if(!istype(get_turf(candidate), /turf/open/overmap))
			continue
		if(!candidate.planet || !bust_tables[candidate.planet])
			continue
		present_types |= candidate.planet
	if(!length(present_types))
		return FALSE
	bust_planet_type = pick(present_types)
	bust_row = bust_tables[bust_planet_type]

	var/datum/mission_target/planet/planet_target = new(src)
	planet_target.wanted_planet = bust_planet_type
	if(!planet_target.resolve())
		qdel(planet_target)
		return FALSE
	target = planet_target
	return TRUE

/datum/mission/poacher_bust/generate_details()
	// Yellow-leaning: the warden service farms most green-zone camps out to
	// locals, but green offers stay on the board (green-band paying) - the
	// board just rolls another mission when one declines.
	if(difficulty == MISSION_DIFFICULTY_EASY && prob(35))
		generation_failed = TRUE
		return
	objective_name = pick(list(
		"the Redclaw Boys",
		"Vashti's Skinners",
		"the Greyline Outfit",
		"the Long-Nine Company",
		"Mama Sho's Culling Crew",
		"the Ivory Chain",
	))
	protected_species = bust_row["species"]
	switch(difficulty)
		if(MISSION_DIFFICULTY_MEDIUM)
			squad_count = 4
		if(MISSION_DIFFICULTY_HARD)
			squad_count = 5
		else
			squad_count = 3
	evidence_count = squad_count - 1

	// The roster: unique nickname/surname pairs, the trailboss first
	squad_names = list()
	var/list/nick_pool = poacher_nicknames.Copy()
	var/list/surname_pool = poacher_surnames.Copy()
	for(var/i in 1 to squad_count)
		var/poacher_name = "'[pick_n_take(nick_pool)]' [pick_n_take(surname_pool)]"
		if(i == 1)
			poacher_name = "Trailboss [poacher_name]"
		squad_names += poacher_name

	flavor_line = pick(list(
		"The [protected_species] take three seasons to recover from one bad harvest. [objective_name] have been at it all year.",
		"[objective_name] shot a warden survey drone out of the sky last week. The service is done writing citations.",
		"Every fence between here and the core knows [objective_name]'s brand on a crate of [protected_species]. That supply ends now.",
		"Two protected ranges have gone silent where [objective_name] set up camp. The third is where you come in.",
		"The wardens seized the last shipment, and [objective_name] shot the seizure team. The service wants this finished.",
	))
	author = pick(list(
		"Warden-Captain Ilesa",
		"Ranger-Marshal Odum",
		"the Sector Wildlife Trust",
		"Game Warden Teller",
		"the Wildlands Conservancy",
	))

/datum/mission/poacher_bust/build_objectives()
	var/datum/mission_objective/goto_coords/approach = new
	approach.arrival_message = "On station over the poaching grounds. Take a ground team down and sweep for [objective_name]'s camp."
	add_objective(approach)

	wipe = new
	// The squad scales with the zone: green gets rifles and a knife, deeper
	// zones add the trailboss's SMG and more guns. Exact subtypes only, the
	// /survivor/random variant self-replaces on Initialize and would escape
	// tracking.
	var/list/squad_types = list()
	switch(difficulty)
		if(MISSION_DIFFICULTY_MEDIUM)
			squad_types += /mob/living/simple_animal/hostile/asteroid/hermit/ranged/gunslinger
			squad_types += /mob/living/simple_animal/hostile/asteroid/hermit/ranged/hunter
			squad_types += /mob/living/simple_animal/hostile/asteroid/hermit/ranged/hunter
			squad_types += /mob/living/simple_animal/hostile/asteroid/hermit/survivor
		if(MISSION_DIFFICULTY_HARD)
			squad_types += /mob/living/simple_animal/hostile/asteroid/hermit/ranged/gunslinger
			squad_types += /mob/living/simple_animal/hostile/asteroid/hermit/ranged/hunter
			squad_types += /mob/living/simple_animal/hostile/asteroid/hermit/ranged/hunter
			squad_types += /mob/living/simple_animal/hostile/asteroid/hermit/ranged/hunter
			squad_types += /mob/living/simple_animal/hostile/asteroid/hermit/survivor
		else
			squad_types += /mob/living/simple_animal/hostile/asteroid/hermit/ranged/hunter
			squad_types += /mob/living/simple_animal/hostile/asteroid/hermit/ranged/hunter
			squad_types += /mob/living/simple_animal/hostile/asteroid/hermit/survivor
	wipe.squad_types = squad_types
	wipe.squad_names = squad_names
	wipe.evidence_names = bust_row["evidence"]
	wipe.evidence_count = evidence_count
	wipe.critter_type = bust_row["critter"]
	add_objective(wipe)

	evidence = new
	evidence.required_amount = evidence_count
	add_objective(evidence)
	wipe.evidence_objective = evidence

/datum/mission/poacher_bust/update_text()
	var/datum/mission_target/planet/planet_target = target
	var/planet_name = istype(planet_target) ? (planet_target.planet?.name || "the planet") : "the planet"
	name = "Poacher Bust: [objective_name]"
	desc = "[flavor_line] \
		Warden's warrant: [objective_name] are running an illegal [protected_species] harvest from a camp in the [bust_row["ground"]] of [planet_name] at ([target.target_x], [target.target_y]) in the [target_zone_name]. \
		Put the whole squad down - the warrant reads dead, not detained - and recover all [evidence_count] pieces of tagged evidence from their trophy cache for prosecution. \
		Payment includes [voucher_count] trade voucher[voucher_count > 1 ? "s" : ""]. \
		Tap a GPS unit on the mission board to follow the case beacon ([gps_tag])."

/datum/mission/poacher_bust/waypoint_label()
	return "Bust: [objective_name]"

/datum/mission/poacher_bust/get_ui_data()
	var/list/data = ..()
	data["target_x"] = target.target_x
	data["target_y"] = target.target_y
	return data

// =========================================================================
// THE CAMP WIPE: field-spawn the outfit, count the squad down
// =========================================================================

/**
 * Field objective that raises the whole camp when the planet's interior
 * loads: the named squad scattered over a small radius, the dressing (fire,
 * barricades, bedrolls, live-catch cages), and the sealed trophy cache
 * holding the mission's bound evidence. Completes when every named poacher
 * is dead; the cache's warden override pops on completion.
 *
 * Death handling: a poacher's death always counts (attribution only flavors
 * the confirm line), so the wipe can't stall. A live poacher qdeleting
 * WITHOUT dying (site unload, admin cleanup) routes through the mission's
 * quest-loss policy (FAIL) instead, so despawns can't hand out a free wipe.
 */
/datum/mission_objective/field/wipe_camp
	/// Poacher typepaths to spawn, trailboss first (set by the mission)
	var/list/squad_types
	/// Generated names applied on spawn, parallel to squad_types
	var/list/squad_names
	/// Live squad members still being tracked
	var/list/mob/living/squad = list()
	/// Total squad size at spawn / members down so far
	var/squad_size = 0
	var/squad_down = 0
	/// How close (tiles) a living crew member must be to confirm a kill
	var/confirm_range = 9
	/// The camp's sealed trophy cache (unlocked when the squad drops)
	var/obj/structure/closet/crate/secure/poacher_cache/cache
	/// The evidence step, handed the bound pieces at camp spawn
	var/datum/mission_objective/deliver/bound/poacher_evidence/evidence_objective
	/// Names for the bound evidence pieces (per-planet, set by the mission)
	var/list/evidence_names
	/// How many evidence pieces the cache holds
	var/evidence_count = 2
	/// Caged-critter type for the live-catch cages (null = no cages)
	var/critter_type

/datum/mission_objective/field/wipe_camp/Destroy()
	release_squad()
	cache = null
	evidence_objective = null
	squad_types = null
	squad_names = null
	evidence_names = null
	return ..()

/datum/mission_objective/field/wipe_camp/deactivate()
	release_squad()
	cache = null
	return ..()

/datum/mission_objective/field/wipe_camp/reset()
	. = ..()
	release_squad()
	squad_down = 0
	squad_size = 0
	cache = null

/// Stops tracking every remaining squad member (mission over / reset)
/datum/mission_objective/field/wipe_camp/proc/release_squad()
	for(var/mob/living/poacher as anything in squad)
		UnregisterSignal(poacher, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	squad.Cut()

/datum/mission_objective/field/wipe_camp/spawn_field_objects(turf/camp_turf)
	// The squad, scattered around the campsite
	for(var/i in 1 to length(squad_types))
		var/poacher_type = squad_types[i]
		var/mob/living/simple_animal/poacher = new poacher_type(get_nearby_open_turf(camp_turf, 3))
		if(i <= length(squad_names))
			poacher.name = squad_names[i]
		poacher.desc += " The kit is professional: snare wire, skinning knives, and the brand of [mission.objective_name] burned into the stock."
		// Outfitted expedition: cold-weather gear keeps an ice-planet camp
		// from freezing to death before the crew arrives
		poacher.minbodytemp = 0
		protect_field_mob(poacher)
		RegisterSignal(poacher, COMSIG_LIVING_DEATH, PROC_REF(on_poacher_death))
		RegisterSignal(poacher, COMSIG_QDELETING, PROC_REF(on_poacher_removed))
		squad += poacher
	squad_size = length(squad)

	// Camp dressing: fire, crude cover, bedrolls. The dense prelit bonfire
	// can't be pathed into, so the squad won't cook itself.
	new /obj/structure/bonfire/dense/prelit(get_nearby_open_turf(camp_turf, 1))
	for(var/_ in 1 to 2)
		new /obj/structure/barricade/wooden/crude(get_nearby_open_turf(camp_turf, 3))
	for(var/_ in 1 to 2)
		var/turf/bed_turf = get_nearby_open_turf(camp_turf, 2)
		new /obj/structure/bed/maint(bed_turf)
		new /obj/item/bedsheet(bed_turf)

	// Live-catch cages: locked pet carriers with something small inside.
	// Alt-click unlocks, activate opens - releasing them is on the crew.
	if(critter_type)
		for(var/_ in 1 to rand(1, 2))
			var/obj/item/pet_carrier/cage = new(get_nearby_open_turf(camp_turf, 2))
			cage.name = "live-catch cage"
			cage.desc = "A warden-banned live trap, still occupied. The lock is a simple latch."
			var/mob/living/critter = new critter_type(cage)
			cage.add_occupant(critter)
			cage.open = FALSE
			cage.locked = TRUE
			cage.update_appearance()

	// The trophy cache: every bound evidence piece spawns sealed inside it.
	// The first piece carries the shell's beacon/loss tracking; the evidence
	// objective watches all of them for destruction.
	cache = new(get_nearby_open_turf(camp_turf, 1))
	cache.desc += " Stenciled with the marks of [mission.objective_name]."
	var/list/name_pool = evidence_names?.Copy()
	for(var/i in 1 to evidence_count)
		var/obj/item/mission_recovery/poacher_evidence/piece = new(cache)
		if(length(name_pool))
			piece.name = "tagged [pick_n_take(name_pool)]"
		mission.bind_item(piece)
		evidence_objective?.watch_evidence(piece)
		if(i == 1)
			mission.register_quest_atom(piece)

	notify_crew("[mission.objective_name] camp sighted - [squad_size] armed poachers holding a sealed trophy cache. The case beacon marks the cache ([mission.gps_tag]).", type = SHIP_NOTIFY_WARNING, sound = 'voidcrew/sound/notify2.ogg')

/**
 * A named poacher died: always counts toward the wipe (attribution only
 * flavors the line - dead is dead and the telemetry logs it, so a weather or
 * wildlife kill can never stall the objective). The del_on_death hermits
 * send COMSIG_LIVING_DEATH before their qdel, so this runs - and unhooks the
 * QDELETING watcher - before on_poacher_removed could.
 */
/datum/mission_objective/field/wipe_camp/proc/on_poacher_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	if(!(source in squad))
		return
	UnregisterSignal(source, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	squad -= source
	squad_down++
	if(!mission || mission.failed || mission.completed)
		return
	if(squad_down >= squad_size)
		unlock_cache()
		complete()
		return
	if(kill_attributable_to_crew(source, get_turf(source)))
		notify_crew("Kill confirmed: [source.name] down ([squad_down]/[squad_size]).", sound = 'voidcrew/sound/notify2.ogg')
	else
		notify_crew("[source.name] is down - warden telemetry logs the death ([squad_down]/[squad_size]).", sound = 'voidcrew/sound/notify2.ogg')

/**
 * A live poacher qdeleted without dying (site unload, admin cleanup): the
 * trail is cold, and counting it would hand out despawn-farmed wipes - void
 * the contract through the loss policy instead. Guarded no-op if the mission
 * is already failing (unload cascades qdel the evidence too, and whichever
 * signal lands first does the failing).
 */
/datum/mission_objective/field/wipe_camp/proc/on_poacher_removed(mob/living/source)
	SIGNAL_HANDLER
	if(!(source in squad))
		return
	squad -= source
	if(!mission || mission.failed || mission.completed)
		return
	mission.handle_quest_loss("Lost the squad's trail - [mission.objective_name] broke camp. Contract void.")

/**
 * Whether this kill belongs to the servant crew: the last attacker's ckey is
 * a crew member's, or a living crew member is close enough to have done it
 * (suppression's attribution - covers gunfire and environmental kills, which
 * never set attacker ckeys).
 */
/datum/mission_objective/field/wipe_camp/proc/kill_attributable_to_crew(mob/living/victim, turf/where)
	if(!where)
		return FALSE
	var/obj/structure/overmap/ship/ship = get_servant()
	var/datum/team/crew_team = ship?.ship_team
	if(!crew_team)
		return FALSE
	for(var/datum/mind/member as anything in crew_team.members)
		var/mob/living/crew_mob = member?.current
		if(!istype(crew_mob) || crew_mob.stat == DEAD)
			continue
		if(victim.lastattackerckey && crew_mob.ckey == victim.lastattackerckey)
			return TRUE
		if(crew_mob.z == where.z && get_dist(crew_mob, victim) <= confirm_range)
			return TRUE
	return FALSE

/// The squad is down: pop the cache's warden override
/datum/mission_objective/field/wipe_camp/proc/unlock_cache()
	if(!QDELETED(cache) && cache.locked)
		cache.locked = FALSE
		cache.update_appearance()
		cache.visible_message(span_notice("[cache]'s mag-seal releases with a hiss."))
	notify_crew("Camp cleared - all [squad_size] poachers accounted for. Warden override sent: the trophy cache is unlocked. Recover the evidence and return it to the mission pad.")

/datum/mission_objective/field/wipe_camp/get_progress_string()
	if(!spawned)
		return "Locate [mission?.objective_name || "the outfit"]'s camp on the surface"
	if(squad_down < squad_size)
		return "Squad down: [squad_down]/[squad_size]"
	return "Camp cleared"

// =========================================================================
// EVIDENCE TURN-IN, the counted bound hand-over, case-file flavored
// =========================================================================

/**
 * deliver/bound with a count: every piece the camp spawned must come home,
 * one hand-over at a time. The objective watches all outstanding pieces for
 * destruction (destroyed evidence kills the case - a counted bound ask has
 * no replacements), and consuming a piece at the pad steps the shell's
 * beacon/loss tracking to the next one out (the courier-pod precedent:
 * consuming isn't losing).
 */
/datum/mission_objective/deliver/bound/poacher_evidence
	required_name = "tagged evidence"
	/// Outstanding evidence pieces still watched for destruction
	var/list/obj/item/mission_recovery/evidence = list()

/datum/mission_objective/deliver/bound/poacher_evidence/Destroy()
	release_evidence()
	return ..()

/datum/mission_objective/deliver/bound/poacher_evidence/reset()
	release_evidence()
	return ..()

/// Stops watching every outstanding piece (mission over / reset)
/datum/mission_objective/deliver/bound/poacher_evidence/proc/release_evidence()
	for(var/obj/item/mission_recovery/piece as anything in evidence)
		UnregisterSignal(piece, COMSIG_QDELETING)
	evidence.Cut()

/// Called by the wipe objective as it fills the cache
/datum/mission_objective/deliver/bound/poacher_evidence/proc/watch_evidence(obj/item/mission_recovery/piece)
	evidence += piece
	RegisterSignal(piece, COMSIG_QDELETING, PROC_REF(on_evidence_destroyed))

/// An outstanding piece was destroyed in the field: the case is dead
/datum/mission_objective/deliver/bound/poacher_evidence/proc/on_evidence_destroyed(datum/source)
	SIGNAL_HANDLER
	evidence -= source
	if(!mission || mission.failed || mission.completed)
		return
	mission.handle_quest_loss("Evidence destroyed - the case against the outfit is dead.")

/datum/mission_objective/deliver/bound/poacher_evidence/accept_item(obj/item/item, atom/reward_anchor)
	// Consuming evidence at the pad isn't losing it: unhook the watcher (and
	// the shell's tracking) before the base hand-over qdels the piece, then
	// point the beacon at the next piece still out.
	UnregisterSignal(item, COMSIG_QDELETING)
	evidence -= item
	if(mission.quest_atom == item)
		mission.forget_quest_atom(item)
		for(var/obj/item/mission_recovery/piece as anything in evidence)
			if(!QDELETED(piece))
				mission.register_quest_atom(piece)
				break
	return ..()

/datum/mission_objective/deliver/bound/poacher_evidence/describe_ask()
	return "[required_amount] pieces of tagged evidence"

/datum/mission_objective/deliver/bound/poacher_evidence/get_progress_string()
	return "Deliver the tagged evidence to the pad ([delivered_count]/[required_amount])"

/**
 * # Tagged Evidence
 *
 * The confiscated trophies the case is built on: bound to their mission and
 * retarget era like every recovery item, and spawned sealed in the camp's
 * trophy cache.
 */
/obj/item/mission_recovery/poacher_evidence
	name = "tagged evidence"
	desc = "A confiscated poaching trophy under a warden-service evidence tag. Destroying it kills the case - the mission pad will accept it."
	icon_state = "recovery"
	w_class = WEIGHT_CLASS_NORMAL

/**
 * # Sealed Trophy Cache
 *
 * The outfit's stockpile: a secure crate whose mag-seal only answers the
 * warden override that fires when the squad is confirmed down. Never player
 * lockable/unlockable - though smashing it open works, dumps the contents,
 * and proves nothing to the pad.
 */
/obj/structure/closet/crate/secure/poacher_cache
	name = "sealed trophy cache"
	desc = "A battered cargo crate under a poacher outfit's mag-seal. The warden service can override the lock once the camp is confirmed clear."

/obj/structure/closet/crate/secure/poacher_cache/togglelock(mob/living/user, silent)
	if(locked)
		if(!silent)
			balloon_alert(user, "outfit mag-seal - no override yet!")
		return
	// The seal is dead once the wardens pop it; nobody re-arms it
	return

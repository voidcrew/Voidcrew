/**
 * # Hardcore drop: getting a body onto a planet
 *
 * The one genuinely hard part of this feature is timing. Planets in this fork have no
 * interior until somebody visits (every *_planet_count in voidcrew/mapping/_mapping.dm is
 * 0), so an unvisited world has to be BUILT - a terrain generation that queues behind
 * every other survey in the sector and then takes the better part of a minute at its
 * throttled tick budget. A body must not exist anywhere until that finishes: a
 * half-generated slot gets swept by /datum/space_level/clear_reservation(), which qdels
 * every atom on it with no exemption whatsoever for mobs holding a client.
 *
 * So this is a small state machine rather than a proc. It is deliberately the same shape
 * as /obj/structure/overmap/ship/proc/request_site_load(), which solves the identical
 * problem for a ship holding a docking approach: register for
 * COMSIG_VOIDCREW_SITE_LOAD_FINISHED, let the player sit in the lobby where they are safe,
 * and act on the answer.
 */

/// Pod flight time from "you pressed the button" to "the hatch is open", roughly. Long
/// enough to read the descent text, short enough that nobody thinks it hung.
#define HARDCORE_POD_TRANSIT (3 SECONDS)
#define HARDCORE_POD_FALLING (0.6 SECONDS)
#define HARDCORE_POD_OPENING (3 SECONDS)

/**
 * One player's in-flight hardcore drop, and afterwards the record that they are out there.
 *
 * Lives in GLOB.hardcore_drops from creation until the castaway is gone, because that list
 * is what hardcore_drops_active() counts against the concurrency cap and what
 * hardcore_drop_planet_candidates() reads to avoid stacking two castaways on one world.
 */
/datum/hardcore_drop
	/// The lobby mob that asked. Cleared the moment their body exists - transfer_character()
	/// qdels it, and holding the reference past that pins a deleted mob.
	var/mob/dead/new_player/player
	/// Kept so a disconnect mid-build can be told apart from a deletion, and so the log
	/// line at the end can name who this was.
	var/player_ckey
	/// The planet we are dropping onto.
	var/obj/structure/overmap/planet/planet
	/// The body, once it exists. Weak: a castaway who dies and gets deleted must not be
	/// held alive by this list.
	var/datum/weakref/castaway_ref
	/// TRUE once land() has run, so a late signal cannot land the same player twice.
	var/landed = FALSE

/datum/hardcore_drop/New(mob/dead/new_player/dropping_player, obj/structure/overmap/planet/target)
	. = ..()
	player = dropping_player
	player_ckey = dropping_player.ckey
	planet = target
	GLOB.hardcore_drops += src

/datum/hardcore_drop/Destroy(force)
	if(planet)
		UnregisterSignal(planet, list(COMSIG_VOIDCREW_SITE_LOAD_FINISHED, COMSIG_QDELETING))
	GLOB.hardcore_drops -= src
	player = null
	planet = null
	castaway_ref = null
	return ..()

/**
 * Whether this record still describes a castaway worth counting.
 *
 * TRUE while the drop is in flight (no body yet, but a slot is committed) and while the
 * body is alive. A dead castaway stops counting, which is the same rule the planet's own
 * keep-alive uses - /datum/map_footprint/get_mind_mobs() skips stat == DEAD - so the cap
 * and the map slot free up together.
 */
/datum/hardcore_drop/proc/is_live()
	if(QDELETED(src))
		return FALSE
	if(!landed)
		// In flight. A player who disconnected or was deleted while their world built is
		// not coming, so stop holding a slot for them.
		return !QDELETED(player)
	var/mob/living/castaway = castaway_ref?.resolve()
	return !QDELETED(castaway) && castaway.stat != DEAD

/// Gives up on a drop that cannot be completed, and puts the player back where they were.
/datum/hardcore_drop/proc/abort(reason)
	if(!QDELETED(player))
		player.spawning_ship = FALSE
		to_chat(player, span_warning("[reason]"))
		INVOKE_ASYNC(player, TYPE_PROC_REF(/mob/dead/new_player, select_ship))
	qdel(src)

/**
 * Entry point. Either drops now or waits for the planet to finish generating.
 *
 * Nothing here may create a mob - see the file header.
 */
/datum/hardcore_drop/proc/begin()
	if(QDELETED(player) || QDELETED(planet))
		return abort("Your drop was cancelled before it began.")

	if(planet.is_loaded() && planet.mapzone)
		INVOKE_ASYNC(src, PROC_REF(land))
		return

	// Not charted. Register BEFORE asking for the build, so a load that finishes inside
	// start_level_load()'s own call stack cannot fire the signal before we are listening.
	RegisterSignal(planet, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, PROC_REF(on_planet_load_finished))
	RegisterSignal(planet, COMSIG_QDELETING, PROC_REF(on_planet_deleted))

	var/queue_depth = SSovermap.worldgen_queue_length() + (SSovermap.worldgen_owner ? 1 : 0)
	to_chat(player, span_notice("Drop authorised for <b>[planet.get_site_label()]</b>. \
		The world is uncharted - a survey has to run before the pod can be aimed. \
		[queue_depth ? "There [queue_depth == 1 ? "is" : "are"] [queue_depth] survey operation[queue_depth == 1 ? "" : "s"] ahead of yours." : "The survey starts now."] \
		This usually takes about a minute. Stay in the lobby; you will drop automatically."))

	if(planet.is_loading())
		// Somebody else's ship is already surveying it. Their load sends the same signal
		// we just registered for, so there is nothing to do but wait.
		return
	planet.start_level_load(player)

/// Signal handler - the planet finished (or failed) generating.
/datum/hardcore_drop/proc/on_planet_load_finished(datum/source, success)
	SIGNAL_HANDLER
	UnregisterSignal(planet, list(COMSIG_VOIDCREW_SITE_LOAD_FINISHED, COMSIG_QDELETING))
	if(landed)
		return
	if(!success || QDELETED(planet) || !planet.is_loaded())
		abort("The survey of your drop site could not be completed - sector traffic is too heavy. Try again shortly.")
		return
	INVOKE_ASYNC(src, PROC_REF(land))

/// Signal handler - the planet was deleted out from under us mid-survey.
/datum/hardcore_drop/proc/on_planet_deleted(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(planet, list(COMSIG_VOIDCREW_SITE_LOAD_FINISHED, COMSIG_QDELETING))
	planet = null
	abort("Your drop site was lost from the chart. Pick another way in.")

/**
 * Builds the body, loads the pod, and drops it.
 *
 * Ordering here is load-bearing and mirrors AttemptSpawnOnShip() (voidcrew/edits/mobs/
 * new_player.dm) step for step, minus everything that needs a hull. The two places it
 * deviates:
 *
 * * The mob is created ON the landing turf and only then moved into the pod. A mob
 *   `new`'d straight into a pod sits in nullspace and never gets its HUD built - the same
 *   trap /obj/item/antag_spawner/loadout works around by touching a real turf first.
 *   create_character() can sleep (appearance-ban lookup), but the mob does not exist
 *   during that sleep, so there is no window where a body stands unattended on a planet.
 *   The player is briefly on open ground between transfer_character() and the forceMove
 *   into the pod; that is deliberate, since equipping and HUD setup both want a real turf,
 *   and nothing in between yields.
 *
 * * check_start_despawn() is called at the end. A planet's release countdown is otherwise
 *   only ever armed by a ship undocking (/obj/structure/overmap/planet/Entered), and a
 *   world generated for a castaway that no hull ever berths at would hold its map slot -
 *   a quarter of a z-level, against a hard world.maxz ceiling - until roundend. The call
 *   is refused while the castaway is alive and re-arms itself every 30 seconds
 *   (check_start_despawn's own TIMER_UNIQUE retry), so it is a heartbeat that does
 *   nothing until they die or leave and then releases the world five minutes later.
 *   This is why preserve_level is NOT used: it would pin the slot for the whole round.
 */
/datum/hardcore_drop/proc/land()
	if(landed)
		return
	if(QDELETED(player) || !player.client)
		return abort("Your drop was cancelled.")
	if(QDELETED(planet) || !planet.is_loaded() || !planet.mapzone)
		return abort("Your drop site is no longer habitable. Pick another way in.")

	var/turf/landing_turf = planet.get_hardcore_landing_turf()
	if(!landing_turf)
		return abort("No clear ground could be found on [planet.get_site_label()]. Pick another way in.")

	var/datum/job/castaway_job = SSjob.get_job_type(/datum/job/castaway)
	if(!castaway_job)
		return abort("The castaway role is missing from this server's job list. Please contact an admin.")
	if(!SSjob.assign_role(player, castaway_job, TRUE))
		return abort("There was an unexpected error putting you into the castaway role.")

	landed = TRUE
	SSticker.queued_players -= player
	SSticker.queue_delay = 4

	var/mob/living/character = player.create_character(landing_turf)
	if(!character)
		// The role has been consumed and the lobby mob may be half torn down; there is no
		// safe way back to the menu from here, so say so loudly rather than silently.
		landed = FALSE
		return abort("Failed to create your character. Please contact an admin.")
	player.transfer_character()
	player = null // transfer_character() qdel'd it

	SSjob.equip_rank(character, castaway_job, character.client)
	castaway_job.after_latejoin_spawn(character)

	SSticker.minds += character.mind
	character.client?.init_verbs()
	castaway_ref = WEAKREF(character)

	var/mob/living/carbon/human/castaway = ishuman(character) ? character : null
	if(castaway)
		// The global crew manifest, but no ship manifest and no ship team: there is no
		// hull to be on the roster of. Being on GLOB.manifest is what puts them in crew
		// records and in the admin crew panel's "addable players" list, which is the
		// remedy an admin needs if a castaway has to be folded into a crew later.
		GLOB.manifest.inject(castaway)
		// Deliberately NOT bound to any ship. An unbound headset stamps its transmissions
		// with wherever it physically is (voidcrew_physical_comms_net), so the common
		// channel reaches this planet only - while Wideband, which every headset carries,
		// reaches the whole galaxy. That asymmetry IS the rescue mechanic.
		castaway.increment_scar_slot()
		castaway.load_persistent_scars()
		if(GLOB.curse_of_madness_triggered)
			give_madness(castaway, GLOB.curse_of_madness_triggered)
		if((castaway_job.job_flags & JOB_ASSIGN_QUIRKS) && CONFIG_GET(flag/roundstart_traits))
			SSquirks.AssignQuirks(castaway, castaway.client)

	GLOB.joined_player_list += character.ckey
	if(player_ckey)
		GLOB.hardcore_drop_last_use[player_ckey] = world.time

	// Load the pod and send it down.
	var/obj/structure/closet/supplypod/drop_pod/pod = new(null)
	// The drop pod's stock explosionSize is list(0,0,1,0) - a small blast meant for
	// punching into a hull. Landing one on top of the crate that is the player's entire
	// round is not the moment for it.
	pod.explosionSize = list(0, 0, 0, 0)
	pod.delays = list(
		POD_TRANSIT = HARDCORE_POD_TRANSIT,
		POD_FALLING = HARDCORE_POD_FALLING,
		POD_OPENING = HARDCORE_POD_OPENING,
		POD_LEAVING = HARDCORE_POD_OPENING,
	)
	pod.set_anchored(TRUE)
	new /obj/structure/closet/crate/engineering/hardcore_drop(pod)
	character.forceMove(pod)
	new /obj/effect/pod_landingzone/drop_pod(landing_turf, pod)

	// See the proc header: this is the whole release mechanism.
	planet.check_start_despawn()

	to_chat(character, span_boldannounce("You are on your own."))
	to_chat(character, span_notice("No ship, no crew, no pickup. The crate in the pod with you is everything \
		you have. Deploy the shelter capsule before dark, get the generator running, and keep your headset on - \
		<b>Wideband (:w) is the only channel that reaches other ships</b>, and somebody answering it is the \
		only way off this rock."))

	log_shuttle("[key_name(character)] hardcore-dropped onto [planet.name] at ([landing_turf.x],[landing_turf.y],[landing_turf.z])")
	log_manifest(character.mind.key, character.mind, character, latejoin = TRUE)
	SSblackbox.record_feedback("tally", "hardcore_drop", 1, "[planet.type]")
	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_CREWMEMBER_JOINED, character, castaway_job.title)

	try_show_orientation_briefing(character)

/**
 * Join-menu entry point: take a hardcore drop instead of a ship.
 *
 * Everything the menu checked is checked again here. The menu can sit open for minutes,
 * and the cap, the cooldown and the pool of habitable worlds all move underneath it.
 */
/mob/dead/new_player/proc/attempt_hardcore_drop()
	var/refusal = hardcore_drop_refusal(src)
	if(refusal)
		to_chat(src, span_warning("[refusal]"))
		return select_ship()

	// Shared with the ship-purchase paths, so a player cannot have a hull and a drop both
	// being prepared for them at once.
	if(spawning_ship)
		to_chat(src, span_warning("You are already being spawned in. Please wait..."))
		return
	spawning_ship = TRUE

	var/obj/structure/overmap/planet/target = pick_hardcore_drop_planet()
	if(!target)
		spawning_ship = FALSE
		to_chat(src, span_warning("No charted world is habitable enough to drop onto right now."))
		return select_ship()

	var/datum/hardcore_drop/drop = new(src, target)
	drop.begin()

#undef HARDCORE_POD_TRANSIT
#undef HARDCORE_POD_FALLING
#undef HARDCORE_POD_OPENING

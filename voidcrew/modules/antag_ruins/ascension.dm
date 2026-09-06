/**
 * # Vestige ascension: the capstone tier
 *
 * The end of the boon ladder. A patron whose every trial you have fulfilled will,
 * late enough in the round, offer one last thing: it opens a way into a private
 * arena, sends you through ALONE, and what is waiting there is a boss on the
 * hoarfrost/lich tier. Kill it and you walk out with a round-warping capstone
 * ability. Die and the arena keeps the body.
 *
 * Three exist, one per host patron, each with its own boss, arena and capstone:
 *
 * | Patron                        | Boss              | Capstone            |
 * |-------------------------------|-------------------|---------------------|
 * | the Magister's Echo (wizard)  | the Ancient Oracle| Voice of the Word   |
 * | the Curator (abductor)        | the Mutant        | Greater Telekinesis |
 * | the Hollow Master (ninja)     | the Warframe      | Machine Communion   |
 *
 * ## The rules that shape everything here
 *
 * **Solo.** One mind goes in. Nobody follows, nothing docks. There is no overmap
 * object and no docking port, just a turf reservation the run owns outright and
 * frees when it ends. The arena areas are NOTELEPORT so neither the supplicant nor
 * a friend outside can shortcut the walls.
 *
 * **One-way for the body.** Dying in there deletes the corpse and frees the ghost
 * with no re-entry (see [/datum/vestige_ascension_run/proc/on_supplicant_death]).
 * There is nothing to clone, nothing to drag home, and the arena unloads behind
 * them. A respawned soul that still meets the gate may ask again, the ledger
 * remembers the boons, not the failure.
 *
 * **One capstone per soul, ever.** `/datum/vestige_record.ascension_boon` is set the
 * moment a capstone is granted and every patron refuses afterward. Grinding all
 * three is not on the table; the choice of which one to chase is the point.
 *
 * **Solo-defeatable by design.** These bosses face exactly one player, always. They
 * are tuned as a hard single-player fight, not a raid boss with the HP divided,
 * see each boss file for its own budget.
 *
 * ## State ownership
 *
 * Same rule as the rest of the vestige system (trial.dm): patrons and ruin
 * interiors are disposable, so nothing durable may live on them. Eligibility is
 * read from the ckey-keyed `/datum/vestige_record`, and the live run hangs off the
 * MIND so it survives the supplicant's body being swapped out from under it.
 *
 * The run datum owns the reservation, the boss and the timers, and is the only
 * thing that may free them, every exit path funnels through
 * [/datum/vestige_ascension_run/proc/finish].
 */

/datum/mind
	/// The ascension run this mind is currently inside, if any
	var/datum/vestige_ascension_run/active_ascension_run

/datum/vestige_record
	/// The capstone boon typepath this soul has taken. Non-null locks out all three.
	var/ascension_boon
	/// Ascension typepaths this soul has walked into and not walked out of. Flavor
	/// and logging only, a failed run does not bar a retry.
	var/list/ascension_failures = list()

// =========================================================================
// THE OFFER: one per host patron
// =========================================================================

/**
 * A capstone on offer: which patron hosts it, what waits in the arena, and what
 * you get for killing it. Stateless data, instantiated once into a global lookup
 * keyed by host patron type. The run (below) is the stateful half.
 */
/datum/vestige_ascension
	/// Shown as the offer's title
	var/name = "Ascension"
	/// The patron's pitch, shown in the confirm dialog before anyone commits
	var/desc
	/// The blunt statement of the stakes, appended to the pitch. Overridable but never omitted.
	var/warning = "You go in alone. If you die in there, that's it. No body comes back."
	/// Said by the patron as the way opens
	var/departure_line = "Go, then."
	/// Patron typepath that hosts this offer
	var/patron_type
	/// The boss spawned on the arena's boss landmark
	var/boss_type
	/// The capstone granted on the kill
	var/boon_type
	/// Arena map template typepath, instantiated per run (see the templates below)
	var/template_type

/// Ascension offers keyed by host patron typepath, built once on demand
GLOBAL_LIST_EMPTY(vestige_ascensions_by_patron)

/// The capstone offer hosted by the given patron typepath, or null
/proc/get_vestige_ascension(patron_type)
	if(!length(GLOB.vestige_ascensions_by_patron))
		for(var/datum/vestige_ascension/offer_type as anything in subtypesof(/datum/vestige_ascension))
			var/host = initial(offer_type.patron_type)
			if(!host)
				continue
			GLOB.vestige_ascensions_by_patron[host] = new offer_type()
	return GLOB.vestige_ascensions_by_patron[patron_type]

/datum/vestige_ascension/oracle
	name = "The Last Recitation"
	desc = "There's something older than me still reciting in the dark down there. It has been getting the \
		words wrong for about four centuries and it will not stop. Go and shut it up. I don't care how."
	departure_line = "Don't listen to it. Talk over it."
	patron_type = /mob/living/basic/vestige_patron/magister
	boss_type = /mob/living/basic/vestige_oracle
	boon_type = /datum/vestige_boon/spell/voice_of_the_word
	template_type = /datum/map_template/vestige_arena/oracle

/datum/vestige_ascension/mutant
	name = "Specimen Zero"
	desc = "Specimen left its cell on the fourth revision. I kept it anyway. It moves things without touching \
		them, which is the part you want, and it stopped cooperating with note-taking a long time ago. You'll \
		have to take it off the subject directly."
	departure_line = "Observation will continue."
	patron_type = /mob/living/basic/vestige_patron/abductor
	boss_type = /mob/living/basic/vestige_mutant
	boon_type = /datum/vestige_boon/spell/greater_telekinesis
	template_type = /datum/map_template/vestige_arena/mutant

/datum/vestige_ascension/warframe
	name = "The Standing Opponent"
	desc = "The clan built one opponent nobody could beat, so there would always be something to train \
		against. Then everyone who knew how to switch it off left. It's still in the lower hall and it hasn't \
		lost a match yet. Go beat it, and take the thing that runs it."
	departure_line = "It's had a hundred years of practice. Go anyway."
	patron_type = /mob/living/basic/vestige_patron/hollow_master
	boss_type = /mob/living/basic/vestige_warframe
	boon_type = /datum/vestige_boon/spell/machine_communion
	template_type = /datum/map_template/vestige_arena/warframe

// =========================================================================
// ELIGIBILITY
// =========================================================================

/**
 * Why this mind can't ascend through this patron right now, as a line the patron
 * can say out loud, or null if it can.
 *
 * Reads completions off the soul record rather than the mind so that a respawned
 * player who has already had their legacy restored is judged on everything they
 * ever did, not on what this body remembers.
 */
/proc/vestige_ascension_refusal(mob/living/user, mob/living/basic/vestige_patron/patron)
	var/datum/mind/mind = user?.mind
	if(!mind)
		return "There's nobody in there to talk to."
	var/datum/vestige_ascension/offer = get_vestige_ascension(patron.type)
	if(!offer)
		return null // this patron hosts nothing; the option is never shown
	if(mind.active_ascension_run)
		return "You're already in the middle of one. Go finish it."
	var/datum/vestige_record/record = get_vestige_record(mind, create = TRUE)
	if(record.ascension_boon)
		return "You already took one. You only get one."
	if(STATION_TIME_PASSED() < VESTIGE_ASCENSION_UNLOCK_TIME)
		return "Not yet. Come back later in the shift."
	// "Maxed out", every trial this patron has, fulfilled. Two for some, three for most.
	for(var/trial_type in patron.trial_types)
		if(!(trial_type in record.completed_trials))
			return "You haven't finished my work. Come back when there's nothing of mine left to do."
	if(mind.active_vestige_trial)
		return "You've got someone else's job half-finished. Deal with that first."
	// The ledger, not just the mind: a pact that completed with no body left to hand
	// the claim button to books the debt on the record alone (trial.dm, offer_reward),
	// and the Pact option rebuilds the button from it.
	if(mind.vestige_pending_reward || length(record.pending_candidates))
		return "Collect what you're owed before you ask me for something like this."
	if(vestige_ascension_passenger(user))
		return "You go in alone. Someone else would follow you through."
	return null

/// Nested bags, swallowed mobs, and revivable bodies travel with forceMove too.
/// A shapeshifter's own stored body and a cyborg's installed brain are parts of the supplicant.
/proc/vestige_ascension_passenger(mob/living/user)
	var/list/own_bodies = list(user)
	for(var/index = 1; index <= length(own_bodies); index++)
		var/mob/living/body = own_bodies[index]
		var/datum/status_effect/shapechange_mob/from_spell/shape = body.has_status_effect(/datum/status_effect/shapechange_mob/from_spell)
		if(!QDELETED(shape?.caster_mob))
			own_bodies |= shape.caster_mob
	var/list/own_mobs = own_bodies.Copy()
	for(var/mob/living/body as anything in own_bodies)
		// A manifested guardian stands outside the inventory, but recall still brings it to its host.
		for(var/mob/living/basic/guardian/linked as anything in body.get_all_linked_holoparasites())
			if(!QDELETED(linked))
				return linked
		var/mob/living/brain/installed_brain
		if(iscarbon(body))
			var/mob/living/carbon/carbon_body = body
			var/obj/item/organ/brain/brain = carbon_body.get_organ_slot(ORGAN_SLOT_BRAIN)
			installed_brain = brain?.brainmob
		else if(iscyborg(body))
			var/mob/living/silicon/robot/robot_body = body
			installed_brain = robot_body.mmi?.brainmob
		// An independently occupied brain is still another person, even if installed.
		if(!QDELETED(installed_brain) && !installed_brain.mind && !installed_brain.client)
			own_mobs |= installed_brain
	for(var/mob/living/passenger as anything in user.get_all_contents_type(/mob/living))
		if(!QDELETED(passenger) && !(passenger in own_mobs))
			return passenger
	return null

/// Does this patron host a capstone at all? Gates the radial option's existence.
/mob/living/basic/vestige_patron/proc/hosts_ascension()
	return !isnull(get_vestige_ascension(type))

/**
 * The ascension conversation. Refusals are spoken and nothing else happens;
 * acceptance needs the supplicant to pass a confirm that states the stakes plainly.
 */
/mob/living/basic/vestige_patron/proc/offer_ascension(mob/living/user)
	var/datum/vestige_ascension/offer = get_vestige_ascension(type)
	if(!offer)
		return
	var/refusal = vestige_ascension_refusal(user, src)
	if(refusal)
		say(refusal)
		return

	var/pitch = "[offer.desc]\n\n[offer.warning]"
	var/accept = tgui_alert(user, pitch, offer.name, list("Open the way", "Not yet"), timeout = 0)
	if(accept != "Open the way")
		return
	// Re-check the whole gate: the dialog sleeps, and a lot can change while it's open
	if(!check_menu(user) || vestige_ascension_refusal(user, src))
		return

	say(offer.departure_line)
	var/datum/vestige_ascension_run/run = new(offer, user)
	if(!run.begin(user))
		qdel(run)
		to_chat(user, span_warning("[src] reaches for something and doesn't find it. The way doesn't open."))

// =========================================================================
// THE RUN
// =========================================================================

/**
 * One supplicant's live attempt: the reservation, the loaded arena, the boss and
 * every timer that can end it.
 *
 * Held on the mind (`active_ascension_run`) rather than on the body, so the run
 * survives anything that swaps the supplicant's mob. Every ending, victory,
 * death, timeout, the player disconnecting into oblivion, lands in [finish],
 * which is the only place the reservation is allowed to be freed.
 */
/datum/vestige_ascension_run
	/// The offer being attempted
	var/datum/vestige_ascension/offer
	/// The mind attempting it
	var/datum/mind/supplicant
	/// The body whose death/deletion signals are currently watched.
	var/mob/living/watched_supplicant
	/// The arena's turf reservation, owned outright by this run
	var/datum/turf_reservation/reservation
	/// Bottom-left turf of the loaded template footprint
	var/turf/arena_bottom_left
	/// The boss, while it lives
	var/mob/living/boss
	/// Moves with a ship and disappears with an unloaded ruin, unlike a cached turf.
	var/obj/effect/vestige_trial_marker/return_marker
	/// The ship they came in on, as a fallback destination when that turf is gone
	var/datum/weakref/home_ship_ref
	/// Timer id of the hard time limit
	var/deadline_timer
	/// TRUE once the boss is dead. The arena is safe and the exit is open
	var/won = FALSE
	/// Guards [finish] against re-entry from stacked signal handlers
	var/finishing = FALSE
	/// The encounter ended, but no safe exterior destination has accepted the supplicant yet.
	var/awaiting_return = FALSE
	/// The one physical exit, also available while a failed return is being retried.
	var/obj/structure/vestige_way_home/way_home

/datum/vestige_ascension_run/New(datum/vestige_ascension/attempted, mob/living/user)
	. = ..()
	offer = attempted
	supplicant = user?.mind
	if(supplicant)
		RegisterSignal(supplicant, COMSIG_MIND_TRANSFERRED, PROC_REF(on_supplicant_transferred))
		RegisterSignal(supplicant, COMSIG_QDELETING, PROC_REF(on_mind_deleted))

/datum/vestige_ascension_run/Destroy()
	watch_supplicant(null)
	if(supplicant)
		UnregisterSignal(supplicant, list(COMSIG_MIND_TRANSFERRED, COMSIG_QDELETING))
	if(supplicant?.active_ascension_run == src)
		supplicant.active_ascension_run = null
	deltimer(deadline_timer)
	deadline_timer = null
	QDEL_NULL(return_marker)
	QDEL_NULL(way_home)
	var/mob/living/old_boss = boss
	watch_boss(null)
	if(!QDELETED(old_boss))
		qdel(old_boss)
	// The reservation is the expensive part; it must not outlive the run
	if(reservation)
		QDEL_NULL(reservation)
	arena_bottom_left = null
	supplicant = null
	offer = null
	return ..()

/**
 * Stands the arena up and puts the supplicant in it. Returns FALSE and cleans up
 * after itself if anything fails, in which case the caller reports the failure.
 * A half-loaded arena must never be left holding a reservation.
 */
/datum/vestige_ascension_run/proc/begin(mob/living/user)
	if(!offer || QDELETED(supplicant) || QDELETED(user) || user.mind != supplicant || supplicant.current != user || user.stat != CONSCIOUS || supplicant.active_ascension_run)
		return FALSE
	if(vestige_ascension_passenger(user))
		to_chat(user, span_warning("The way admits you alone. Someone else would follow you through."))
		return FALSE
	if(!ispath(offer.template_type, /datum/map_template/vestige_arena))
		log_mapping("VESTIGE ASCENSION: [offer.name] has no arena template")
		return FALSE
	// Arena loading can yield. Claim the slot before another open dialog starts a run.
	supplicant.active_ascension_run = src
	// Instantiating parses the .dmm for its bounds, so this is also the size preload
	var/datum/map_template/vestige_arena/template = new offer.template_type()
	var/opened = load_arena(template)
	qdel(template)
	if(!opened || QDELETED(src) || QDELETED(user) || user.mind != supplicant || user.stat != CONSCIOUS)
		return FALSE
	// Loading can yield long enough for somebody to put a passenger into the inventory.
	if(vestige_ascension_passenger(user))
		to_chat(user, span_warning("The way admits you alone. Someone else would follow you through."))
		return FALSE

	var/turf/entry = pick_landmark(/obj/effect/landmark/vestige_arena/entry)
	var/turf/boss_spot = pick_landmark(/obj/effect/landmark/vestige_arena/boss)
	if(!entry || !boss_spot)
		log_mapping("VESTIGE ASCENSION: [offer.name]'s arena is missing an entry or boss landmark")
		return FALSE

	watch_boss(new offer.boss_type(boss_spot))

	remember_origin(user)
	supplicant.active_ascension_run = src
	watch_supplicant(user)

	user.forceMove(entry)
	user.flash_act(1, TRUE)
	to_chat(user, span_boldannounce("[offer.name]"))
	to_chat(user, span_userdanger("The only way out is through whatever is in here with you."))
	playsound(entry, 'sound/effects/magic/curse.ogg', 75, TRUE)

	deadline_timer = addtimer(CALLBACK(src, PROC_REF(on_deadline)), VESTIGE_ASCENSION_TIME_LIMIT, TIMER_STOPPABLE)
	log_game("[key_name(user)] entered vestige ascension '[offer.name]'.")
	return TRUE

/// Reserves space for the template plus a thin blank margin and loads it. Sets [reservation] on success.
/datum/vestige_ascension_run/proc/load_arena(datum/map_template/vestige_arena/template)
	// New() already parsed the bounds off mappath; this only catches a missing file.
	// (prefix/suffix are /datum/map_template/ruin vars. Arenas aren't ruins.)
	if(!template.width || !template.height)
		log_mapping("VESTIGE ASCENSION: couldn't read bounds from '[template.mappath]'")
		return FALSE

	var/pad = VESTIGE_ASCENSION_ARENA_PADDING
	reservation = SSmapping.request_turf_block_reservation(template.width + (pad * 2), template.height + (pad * 2), 1)
	if(!reservation)
		return FALSE

	var/turf/bottom_left = reservation.bottom_left_turfs[1]
	arena_bottom_left = locate(bottom_left.x + pad, bottom_left.y + pad, bottom_left.z)
	// Deliberately NOT wrapped in try/catch. stack_trace() is CRASH-based: left alone
	// it ends its own frame and the caller carries on, but inside a try block it
	// unwinds everything up to the catch. Loading an arena raises those warnings as a
	// matter of course, a reservation hands back recycled turfs and turfs keep their
	// signal registrations when they are replaced, so every wall built where a wall
	// already stood warns once as it re-registers itself. Catching that threw away a
	// working arena and made the second run of any arena impossible. A missing or
	// unreadable .dmm is caught by the bounds check above instead.
	var/loaded = template.load(arena_bottom_left)
	if(!loaded)
		log_mapping("VESTIGE ASCENSION: '[template.name]' failed to load from '[template.mappath]'")
		QDEL_NULL(reservation)
		arena_bottom_left = null
		return FALSE
	if(!extend_arena_area())
		log_mapping("VESTIGE ASCENSION: '[template.name]' has no arena area at its footprint origin")
		QDEL_NULL(reservation)
		arena_bottom_left = null
		return FALSE

	// The margin loads as uninitialized /turf/open/space/basic, which players cannot
	// interact with at all. Anything reachable has to pass through here first.
	initialize_uninitialized_block_turfs(reservation.bottom_left_turfs[1], reservation.top_right_turfs[1])
	return TRUE

/// A breached outer wall must not expose a teleportable strip inside the private reservation.
/datum/vestige_ascension_run/proc/extend_arena_area()
	var/area/arena_area = get_area(arena_bottom_left)
	if(!istype(arena_area, /area/ruin/space/has_grav/vestige/arena) || !reservation)
		return FALSE
	for(var/turf/interior as anything in block(reservation.bottom_left_turfs[1], reservation.top_right_turfs[1]))
		var/area/previous_area = get_area(interior)
		if(previous_area != arena_area)
			interior.change_area(previous_area, arena_area)
	// The allocator's dense NOJAUNT cordon lies outside these bounds and keeps its own area.
	return TRUE

/// A turf inside the loaded footprint carrying the given landmark type, or null. Consumes the landmark.
/datum/vestige_ascension_run/proc/pick_landmark(landmark_type)
	if(!arena_bottom_left)
		return null
	var/turf/top_right = locate(
		arena_bottom_left.x + reservation.width - (VESTIGE_ASCENSION_ARENA_PADDING * 2) - 1,
		arena_bottom_left.y + reservation.height - (VESTIGE_ASCENSION_ARENA_PADDING * 2) - 1,
		arena_bottom_left.z,
	)
	if(!top_right)
		return null
	for(var/turf/candidate as anything in block(arena_bottom_left, top_right))
		var/obj/effect/landmark/vestige_arena/mark = locate(landmark_type) in candidate
		if(!mark)
			continue
		qdel(mark)
		return candidate
	return null

// ===== WATCHING THE SUPPLICANT =====

/// Hooks the signals that end the run on the supplicant's side. Re-callable across body swaps.
/datum/vestige_ascension_run/proc/watch_supplicant(mob/living/user)
	if(watched_supplicant)
		UnregisterSignal(watched_supplicant, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	watched_supplicant = user
	if(QDELETED(user))
		return
	RegisterSignal(user, COMSIG_LIVING_DEATH, PROC_REF(on_supplicant_death), override = TRUE)
	RegisterSignal(user, COMSIG_QDELETING, PROC_REF(on_supplicant_deleted), override = TRUE)

/// Shapeshifting deletes the old shape after transferring the mind out of it.
/datum/vestige_ascension_run/proc/on_supplicant_transferred(datum/mind/source)
	SIGNAL_HANDLER
	watch_supplicant(supplicant?.current)

/datum/vestige_ascension_run/proc/on_mind_deleted(datum/mind/source)
	SIGNAL_HANDLER
	INVOKE_ASYNC(src, PROC_REF(finish), "mind destroyed")

/**
 * The whole point of the tier. The body is deleted outright, no corpse, no
 * cloning, no drag-it-home, and the ghost is freed without re-entry. The arena
 * goes with them.
 *
 * The retry is deliberately left open: a respawned soul that still meets the gate
 * can ask again (the ledger keeps boons and completions, so nothing is refarmed).
 * What a failure costs is the body and everything that was on it.
 */
/datum/vestige_ascension_run/proc/on_supplicant_death(mob/living/user)
	SIGNAL_HANDLER
	if(finishing || won)
		return
	INVOKE_ASYNC(src, PROC_REF(consume_supplicant), user)

/datum/vestige_ascension_run/proc/consume_supplicant(mob/living/user)
	if(finishing || QDELETED(user))
		return
	var/datum/vestige_record/record = get_vestige_record(supplicant, create = TRUE)
	if(record)
		record.ascension_failures |= offer.type
	log_game("[key_name(user)] died in vestige ascension '[offer.name]'. Body consumed.")

	to_chat(user, span_userdanger("You're not coming back from this one."))
	user.visible_message(span_boldwarning("[user] comes apart and doesn't leave anything behind."))
	playsound(get_turf(user), 'sound/effects/magic/demon_dies.ogg', 90, TRUE)
	// UnregisterSignal first: qdel(user) would otherwise re-enter through on_supplicant_deleted
	UnregisterSignal(user, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	user.ghostize(can_reenter_corpse = FALSE)
	qdel(user)
	finish("death")

/// Gibbed, admin-deleted, or otherwise unmade without a death, same ending.
/datum/vestige_ascension_run/proc/on_supplicant_deleted(mob/living/user)
	SIGNAL_HANDLER
	if(finishing || won)
		return
	var/datum/vestige_record/record = get_vestige_record(supplicant, create = TRUE)
	if(record)
		record.ascension_failures |= offer.type
	INVOKE_ASYNC(src, PROC_REF(finish), "body destroyed")

// ===== WINNING =====

/// Keep the encounter attached to its boss without TRAIT_NO_TRANSFORM, which also stops AI movement.
/datum/vestige_ascension_run/proc/watch_boss(mob/living/new_boss)
	if(boss)
		UnregisterSignal(boss, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING, COMSIG_LIVING_PRE_WABBAJACKED, COMSIG_PRE_MOB_CHANGED_TYPE))
	boss = new_boss
	if(QDELETED(boss))
		return
	RegisterSignal(boss, COMSIG_LIVING_DEATH, PROC_REF(on_boss_death))
	RegisterSignal(boss, COMSIG_QDELETING, PROC_REF(on_boss_deleted))
	RegisterSignal(boss, COMSIG_LIVING_PRE_WABBAJACKED, PROC_REF(on_boss_polymorph))
	RegisterSignal(boss, COMSIG_PRE_MOB_CHANGED_TYPE, PROC_REF(on_boss_type_change))

/datum/vestige_ascension_run/proc/on_boss_polymorph(mob/living/source)
	SIGNAL_HANDLER
	return STOP_WABBAJACK

/datum/vestige_ascension_run/proc/on_boss_type_change(mob/living/source)
	SIGNAL_HANDLER
	return COMPONENT_BLOCK_MOB_CHANGE

/**
 * The kill. Grants the capstone immediately (no radial. There is exactly one
 * thing on offer and it was named up front), locks the soul out of the other two,
 * and opens the way home.
 *
 * The victor is NOT yanked out on the spot: the arena is theirs for
 * VESTIGE_ASCENSION_VICTORY_GRACE so they can strip the place, and the gate at the
 * entry sends them back whenever they're ready.
 */
/datum/vestige_ascension_run/proc/on_boss_death(mob/living/dead_boss)
	SIGNAL_HANDLER
	if(finishing || won)
		return
	won = TRUE
	INVOKE_ASYNC(src, PROC_REF(award_capstone))

/datum/vestige_ascension_run/proc/on_boss_deleted(mob/living/dead_boss)
	SIGNAL_HANDLER
	watch_boss(null)
	if(finishing || won)
		return
	// Let the removed boss finish its cleanup before ending the encounter.
	addtimer(CALLBACK(src, PROC_REF(finish), "boss disappeared"), 0)

/datum/vestige_ascension_run/proc/award_capstone()
	var/mob/living/victor = supplicant?.current
	if(QDELETED(victor))
		return
	var/datum/vestige_record/record = get_vestige_record(supplicant, create = TRUE)
	if(!record?.ascension_boon)
		var/datum/vestige_boon/capstone = new offer.boon_type()
		capstone.grant(victor, supplicant)
		LAZYADD(supplicant.vestige_boons, offer.boon_type)
		qdel(capstone)
		if(record)
			record.boons |= offer.boon_type
			record.ascension_boon = offer.boon_type
		log_game("[key_name(victor)] completed vestige ascension '[offer.name]' and took [offer.boon_type].")
		to_chat(victor, span_boldannounce("It stops moving. Whatever it could do, you can do now."))
		playsound(get_turf(victor), 'sound/effects/magic/curse.ogg', 100, TRUE)
	else
		// Another body's encounter may have settled this soul's one capstone first.
		to_chat(victor, span_boldnotice("The fight is over. You have already taken your ascension; the way home is yours."))

	open_the_gate()
	deltimer(deadline_timer)
	deadline_timer = addtimer(CALLBACK(src, PROC_REF(on_deadline)), VESTIGE_ASCENSION_VICTORY_GRACE, TIMER_STOPPABLE)

/// Open one physical exit beside the current supplicant.
/datum/vestige_ascension_run/proc/open_the_gate()
	var/mob/living/victor = supplicant?.current
	var/turf/spot = get_turf(victor)
	if(!spot)
		return
	if(!QDELETED(way_home))
		return
	way_home = new(spot)
	way_home.run_ref = WEAKREF(src)
	var/exit_message = awaiting_return ? "A way back opens next to you. It is waiting for safe ground." : "A way back opens next to you. It won't stay open forever."
	to_chat(victor, span_boldnotice(exit_message))

// ===== ENDINGS =====

/// Time limit, or the victory grace running out. Living supplicants get sent home.
/datum/vestige_ascension_run/proc/on_deadline()
	deadline_timer = null
	finish(won ? "victory grace expired" : "time limit")

/**
 * The single exit. Sends a living supplicant home if there is one, then tears the
 * arena down. Idempotent, every caller may assume it is safe to call twice.
 */
/datum/vestige_ascension_run/proc/finish(reason)
	if(finishing)
		return
	finishing = TRUE
	var/mob/living/user = supplicant?.current
	if(!QDELETED(user))
		if(in_arena(user) && !send_home(user))
			// A failed forceMove or an unavailable destination cannot cost the survivor their body.
			finishing = FALSE
			awaiting_return = TRUE
			var/mob/living/old_boss = boss
			watch_boss(null)
			if(!QDELETED(old_boss))
				qdel(old_boss)
			open_the_gate()
			deltimer(deadline_timer)
			deadline_timer = addtimer(CALLBACK(src, PROC_REF(on_deadline)), 30 SECONDS, TIMER_STOPPABLE)
			to_chat(user, span_warning("The way back cannot find safe ground yet. The encounter is over; the doorway will keep trying."))
			return FALSE
		UnregisterSignal(user, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	log_game("Vestige ascension '[offer?.name]' ended: [reason].")
	qdel(src)
	return TRUE

/// Is this mob standing inside our reservation?
/datum/vestige_ascension_run/proc/in_arena(mob/living/user)
	var/turf/spot = get_turf(user)
	return spot && reservation?.contains_turf(spot)

/// Cache the physical origin and the crew's vessel before leaving the patron's ruin.
/datum/vestige_ascension_run/proc/remember_origin(mob/living/user)
	QDEL_NULL(return_marker)
	var/turf/origin = get_turf(user)
	if(origin)
		return_marker = new(origin)
	home_ship_ref = WEAKREF(get_ship_from_atom(user) || get_crew_ship(user))

/// Return only to safe ground outside this reservation; recycled turf addresses prove nothing.
/datum/vestige_ascension_run/proc/send_home(mob/living/user)
	var/turf/destination = QDELETED(return_marker) ? null : get_turf(return_marker)
	if(!safe_return_turf(destination))
		destination = find_home_ship_turf()
	if(!safe_return_turf(destination))
		destination = find_return_fallback()
	if(!safe_return_turf(destination))
		return FALSE
	user.forceMove(destination)
	if(QDELETED(user) || in_arena(user) || get_turf(user) != destination)
		return FALSE
	user.flash_act(1, TRUE)
	to_chat(user, span_boldnotice("The floor changes under you. You're back."))
	return TRUE

/// Even a generic station fallback may pick another reserved arena on the same z-level.
/datum/vestige_ascension_run/proc/safe_return_turf(turf/destination)
	if(QDELETED(destination) || reservation?.contains_turf(destination))
		return FALSE
	return is_safe_turf(destination, extended_safety_checks = TRUE, no_teleport = TRUE)

/// Keep the existing bounded searches, but do not accept their relaxed NOTELEPORT fallback.
/datum/vestige_ascension_run/proc/find_return_fallback()
	var/turf/destination
	if(length(SSmapping.levels_by_trait(ZTRAIT_STATION)))
		destination = find_safe_turf()
	if(safe_return_turf(destination))
		return destination
	if(length(GLOB.the_station_areas))
		destination = get_safe_random_station_turf()
	return safe_return_turf(destination) ? destination : null

/// An open turf aboard the ship they left from, or null if it's gone too
/datum/vestige_ascension_run/proc/find_home_ship_turf()
	var/obj/structure/overmap/ship/home = home_ship_ref?.resolve()
	if(QDELETED(home) || !home.shuttle)
		return null
	var/list/candidates = list()
	for(var/turf/deck as anything in home.shuttle.return_turfs())
		if(!safe_return_turf(deck))
			continue
		candidates += deck
	return length(candidates) ? pick(candidates) : null

// =========================================================================
// THE WAY HOME
// =========================================================================

/**
 * The exit, spawned only once the boss is dead. Clicking it ends the run on the
 * victor's own schedule rather than on a timer they can't see.
 */
/obj/structure/vestige_way_home
	name = "the way back"
	desc = "A doorway standing up on its own with no wall around it. The other side is wherever you were when you agreed to this."
	// The stock portal swirl (what /obj/effect/portal wears). NOT gateway.dmi,
	// that file has no "portal" state and renders nothing at all.
	icon = 'icons/obj/anomaly.dmi'
	icon_state = "portal"
	anchored = TRUE
	density = FALSE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	light_range = 3
	light_color = COLOR_VIOLET
	/// The run that opened it
	var/datum/weakref/run_ref

/obj/structure/vestige_way_home/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	return enter_gate(user)

/obj/structure/vestige_way_home/attack_paw(mob/living/user, list/modifiers)
	return enter_gate(user)

/obj/structure/vestige_way_home/attack_alien(mob/living/user, list/modifiers)
	return enter_gate(user)

/obj/structure/vestige_way_home/attack_larva(mob/living/user, list/modifiers)
	return enter_gate(user)

/obj/structure/vestige_way_home/attack_animal(mob/living/user, list/modifiers)
	return enter_gate(user)

/obj/structure/vestige_way_home/handle_basic_attack(mob/living/user, list/modifiers)
	return enter_gate(user)

/obj/structure/vestige_way_home/attack_robot(mob/living/user, list/modifiers)
	return enter_gate(user)

/obj/structure/vestige_way_home/attack_ai(mob/living/user)
	return enter_gate(user)

/// Every admitted body may use the physical exit; a silicon's remote click is insufficient.
/obj/structure/vestige_way_home/proc/enter_gate(mob/living/user)
	if(QDELETED(user) || user.stat != CONSCIOUS || !Adjacent(user))
		return TRUE
	var/datum/vestige_ascension_run/run = run_ref?.resolve()
	if(!run || run.supplicant != user.mind || run.supplicant.current != user || (!run.won && !run.awaiting_return))
		to_chat(user, span_warning("It isn't for you."))
		return TRUE
	run.finish("victor left")
	return TRUE

// =========================================================================
// MAP TEMPLATES, AREAS AND LANDMARKS
// =========================================================================

/**
 * Arena templates. Never seeded, never docked at, never on the overmap, the run
 * instantiates one, loads it into a reservation, and frees both when it ends.
 *
 * These deliberately do NOT go through `SSmapping.map_templates`. That registry is
 * populated by `preloadTemplates()`, which only walks `_maps/templates/` and
 * `/datum/map_template/ruin` subtypes, and keys everything by `.name` rather than
 * `.id` (mapping.dm:503-532). An arena is neither, so it would never be registered
 * and every lookup would come back null. Subtyping `/ruin` to get registered would
 * be worse: that drops them into `ruins_templates` and the themed-ruin seeding
 * pool, which is exactly where a solo one-way arena must never appear.
 *
 * So `mappath` is set directly (not prefix/suffix, `/datum/map_template/New` reads
 * mappath and nothing else) and the run just news the typepath it was given.
 *
 * Every arena map MUST place exactly one entry landmark and exactly one boss
 * landmark, or the run refuses to open and says so in the mapping log.
 */
/datum/map_template/vestige_arena

/datum/map_template/vestige_arena/oracle
	name = "The Last Recitation"
	mappath = "_maps/voidcrew/RandomRuins/SpaceRuins/vestige_arena_oracle.dmm"

/datum/map_template/vestige_arena/mutant
	name = "Specimen Zero"
	mappath = "_maps/voidcrew/RandomRuins/SpaceRuins/vestige_arena_mutant.dmm"

/datum/map_template/vestige_arena/warframe
	name = "The Standing Opponent"
	mappath = "_maps/voidcrew/RandomRuins/SpaceRuins/vestige_arena_warframe.dmm"

/// Where the supplicant materializes. Exactly one per arena map.
/obj/effect/landmark/vestige_arena
	name = "vestige arena landmark"
	icon_state = "x2"

/obj/effect/landmark/vestige_arena/entry
	name = "vestige arena entry"

/obj/effect/landmark/vestige_arena/boss
	name = "vestige arena boss spawn"

/**
 * Arena areas. NOTELEPORT is load-bearing: it stops the supplicant from jaunting
 * past the arena's geometry with boons they already own, and stops anyone outside
 * from teleporting in to help.
 */
/area/ruin/space/has_grav/vestige/arena
	name = "vestige arena"
	area_flags = HIDDEN_AREA | UNIQUE_AREA | NOTELEPORT
	ambience_index = AMBIENCE_SPOOKY
	// Arenas carry no APC and nobody is coming to fix one. Without this, every
	// mapped light is dead on arrival and the whole fight happens in the dark.
	requires_power = FALSE

/area/ruin/space/has_grav/vestige/arena/oracle
	name = "\improper The Last Recitation"

/area/ruin/space/has_grav/vestige/arena/mutant
	name = "\improper Specimen Zero"

/area/ruin/space/has_grav/vestige/arena/warframe
	name = "\improper The Standing Opponent"

// =========================================================================
// ADMIN
// =========================================================================

/**
 * Skips the gate entirely and drops you into an arena. The run is real, the boss,
 * the death rule and the capstone all behave exactly as they would in a live
 * attempt, so this is a playtest tool, not a viewer.
 */
ADMIN_VERB(open_vestige_ascension, R_FUN, "Open Vestige Ascension", "Drop into an endgame vestige arena. The death rule applies.", ADMIN_CATEGORY_EVENTS)
	var/mob/living/body = user.mob
	if(!isliving(body))
		to_chat(user, span_warning("You need a living body for this."))
		return
	if(!body.mind)
		to_chat(user, span_warning("That mob has no mind; the run has nothing to hang off."))
		return
	if(body.mind.active_ascension_run)
		to_chat(user, span_warning("That mind is already inside a run."))
		return

	// Build the picker off the live offers, so the name shown resolves straight back
	// to the instance the run needs, no re-deriving it from a typepath.
	var/list/choices = list()
	for(var/patron_type in GLOB.vestige_ascensions_by_patron)
		var/datum/vestige_ascension/candidate = GLOB.vestige_ascensions_by_patron[patron_type]
		choices[candidate.name] = candidate
	if(!length(choices)) // nothing has forced the lazy build yet
		for(var/datum/vestige_ascension/offer_type as anything in subtypesof(/datum/vestige_ascension))
			var/datum/vestige_ascension/candidate = get_vestige_ascension(initial(offer_type.patron_type))
			if(candidate)
				choices[candidate.name] = candidate
	var/pick = tgui_input_list(body, "Which arena?", "Vestige Ascension", choices)
	if(isnull(pick))
		return
	var/datum/vestige_ascension/offer = choices[pick]
	if(!offer)
		return

	var/datum/vestige_ascension_run/run = new(offer, body)
	if(!run.begin(body))
		qdel(run)
		to_chat(user, span_warning("The arena failed to load. Check the mapping log."))
		return
	log_admin("[key_name(user)] opened vestige ascension '[offer.name]' on themselves.")
	message_admins("[key_name_admin(user)] opened vestige ascension '[offer.name]' on themselves.")

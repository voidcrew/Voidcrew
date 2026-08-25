/**
 * # Live Capture
 *
 * "The client wants it breathing. Wear it down, box it up, and don't
 * scratch the merchandise."
 *
 * A xenofauna procurement contract for a survey-marked wild specimen on a
 * specific planet type: [fly to the planet] -> [find the marked beast the
 * survey tagged] -> [wear it down without killing it and seal it in the
 * dispensed capture crate] -> [deliver the sealed crate with the specimen
 * alive inside]. Generation only offers contracts for planet types actually
 * on the overmap this round (the wanted_planet filter on the planet target),
 * and the specimen comes from a per-planet table of smaller distinctive
 * fauna - never the big-game elites, never megafauna.
 *
 * Quest-atom chain: the marked specimen from field spawn to delivery; the
 * capture crate is watched separately by the objectives. Losing either voids
 * the contract (FAIL policy - with one planet of each type per round and one
 * crate per contract, a retarget has nothing to re-arm). Killing the
 * specimen ALSO voids the contract, before or after crating: the client
 * pays for live delivery only.
 *
 * CONTAINMENT: a sealed occupant has ZERO self-escape agency. The crate
 * overrides both pet-carrier escape paths (relaymove's door-shove and
 * container_resist_act's reach-the-lock / push-out channels) into flavored
 * no-ops, and the occupant rides in dormancy built from EXISTING tools: the
 * grouped stasis status effect (the legion-consumed pattern - halts Life,
 * metabolism and adds TRAIT_IMMOBILIZED/TRAIT_HANDS_BLOCKED/TRAIT_STASIS)
 * plus TRAIT_AI_PAUSED (the frog-statue pattern - shuts the AI controller
 * off entirely). Outside forces destroying the crate release the beast
 * alive, awake and furious - and void the contract with it.
 */

/// The occupant health fraction at (or below) which the crate will accept it
#define CAPTURE_HEALTH_FRACTION 0.3
/// How long wrestling the subdued specimen into the crate takes
#define CRATE_SEAL_TIME (5 SECONDS)
/// Throttle on the captive's futile-struggle feedback messages
#define CRATE_STRUGGLE_COOLDOWN (3 SECONDS)
/// Stasis source key for the crate's suspension field
#define STASIS_CAPTURE_CRATE "capture_crate"

/datum/mission/live_capture
	name = "Live Capture"
	weight = 8
	mission_limit = 1
	duration = 35 MINUTES
	voucher_count = 1
	quest_lost_policy = MISSION_QUEST_LOST_FAIL
	gps_tag_prefix = "FAUNA"
	// Green-band pay between field_expedition and big_game_hunt: harder than
	// pulling a probe core, gentler than killing an apex - the specimen is
	// smaller fauna, but you have to win WITHOUT the killing blow.
	value_min = 900
	value_max = 1250

	/// Per-planet capture tables, keyed by /datum/overmap/planet typepath:
	/// the specimen, the board-title form, the ask phrase, and the habitat
	/// flavor. EXISTING smaller fauna only - never the big-game elites.
	var/static/list/capture_tables = list(
		/datum/overmap/planet/lava = list(
			"beast" = /mob/living/basic/mining/goldgrub,
			"title" = "Breeding-Age Goldgrub",
			"ask" = "a breeding-age goldgrub",
			"ground" = "ash wastes",
		),
		/datum/overmap/planet/ice = list(
			"beast" = /mob/living/basic/mining/ice_whelp,
			"title" = "Unscarred Ice Whelp",
			"ask" = "an unscarred ice whelp",
			"ground" = "glacier fields",
		),
		/datum/overmap/planet/jungle = list(
			"beast" = /mob/living/basic/gorilla/beach,
			"title" = "Canopy Gorilla",
			"ask" = "a healthy canopy gorilla",
			"ground" = "deep canopy",
		),
		/datum/overmap/planet/beach = list(
			"beast" = /mob/living/basic/turtle/beach,
			"title" = "Adult Shore Turtle",
			"ask" = "an adult shore turtle",
			"ground" = "drowned shallows",
		),
		/datum/overmap/planet/wasteland = list(
			"beast" = /mob/living/basic/wumborian_fugu/wasteland,
			"title" = "Intact Fugu Specimen",
			"ask" = "an intact wumborian fugu specimen",
			"ground" = "dead highways",
		),
	)

	/// /datum/overmap/planet typepath this contract is themed on
	var/capture_planet_type
	/// The rolled capture table row (points into the static table, never mutate)
	var/list/capture_row
	/// The rolled buyer-flavor line (stable across text rebuilds)
	var/flavor_line
	/// The capture objective (kit dispensing at start)
	var/datum/mission_objective/field/capture_beast/capture

/datum/mission/live_capture/Destroy()
	capture = null
	capture_row = null
	return ..()

/datum/mission/live_capture/get_archetype()
	return "procurement"

/datum/mission/live_capture/setup_target()
	// Only offer contracts for planet types actually on the overmap this round
	var/list/present_types = list()
	for(var/obj/structure/overmap/planet/candidate as anything in GLOB.overmap_planets)
		if(QDELETED(candidate))
			continue
		if(!istype(get_turf(candidate), /turf/open/overmap))
			continue
		if(!candidate.planet || !capture_tables[candidate.planet])
			continue
		present_types |= candidate.planet
	if(!length(present_types))
		return FALSE
	capture_planet_type = pick(present_types)
	capture_row = capture_tables[capture_planet_type]

	var/datum/mission_target/planet/planet_target = new(src)
	planet_target.wanted_planet = capture_planet_type
	if(!planet_target.resolve())
		qdel(planet_target)
		return FALSE
	target = planet_target
	return TRUE

/datum/mission/live_capture/generate_details()
	objective_name = capture_row["ask"]
	flavor_line = pick(list(
		"The Ostrand Xenozoological Institute's breeding program is down to one aging bloodline. They need fresh breeding stock, and it has to be alive.",
		"A private collector wants a living centerpiece for their habitat dome. Taxidermy was offered and firmly declined.",
		"A terraforming concern needs a proven survivor to seed its pilot biome. It only works if the animal arrives alive.",
		"A university exobiology wing lost its last live specimen to a customs incident nobody will talk about. You're the quiet replacement.",
		"A licensed wildlife broker has a standing buyer on retainer: one live specimen, subdued, sealed, unspoiled.",
	))
	author = pick(list(
		"the Ostrand Xenozoological Institute",
		"Curator Vasquez",
		"the Verdance Terraforming Concern",
		"Registrar Imm of the Wildlife Exchange",
		"Broker Tam",
	))

/datum/mission/live_capture/build_objectives()
	var/datum/mission_objective/goto_coords/approach = new
	approach.arrival_message = "On station over the habitat. Take the capture crate down to the surface and find the marked specimen."
	add_objective(approach)

	capture = new
	capture.target_mob_type = capture_row["beast"]
	add_objective(capture)

	var/datum/mission_objective/deliver/bound/live_cargo/delivery = new
	add_objective(delivery)
	capture.deliver_objective = delivery

/datum/mission/live_capture/on_mission_started()
	capture?.dispense_kit()

/datum/mission/live_capture/update_text()
	var/datum/mission_target/planet/planet_target = target
	var/planet_name = istype(planet_target) ? (planet_target.planet?.name || "the planet") : "the planet"
	name = "Live Capture: [capture_row["title"]]"
	desc = "[flavor_line] \
		The guild survey has tagged [objective_name] in the [capture_row["ground"]] of [planet_name] at ([target.target_x], [target.target_y]) in the [target_zone_name]. \
		A capture crate has been delivered to your mission pad. Fly out, wear the marked specimen down without killing it, then use the crate on it - it only takes the tagged animal, and only once it's badly hurt. \
		Bring the sealed crate back breathing; a dead specimen voids the contract. \
		Payment includes [voucher_count] trade voucher[voucher_count > 1 ? "s" : ""]. \
		Tap a GPS unit on the mission board to follow the specimen's survey tag ([gps_tag])."

/datum/mission/live_capture/waypoint_label()
	return "Capture: [objective_name]"

/datum/mission/live_capture/get_ui_data()
	var/list/data = ..()
	data["target_x"] = target.target_x
	data["target_y"] = target.target_y
	return data

// =========================================================================
// THE CAPTURE: find the marked specimen, wear it down, seal it in
// =========================================================================

/**
 * kill_named's spawn machinery with the win condition inverted: the marked
 * specimen breaks cover at the site when the interior loads, and the
 * objective completes when the crate seals it - its DEATH fails the mission
 * instead. The crate kit is dispensed at the servant's mission pad on accept
 * (the prospect-stake kit pattern) and watched for destruction the whole
 * phase; the specimen itself is the shell-tracked quest atom (GPS, qdel
 * backstop, site-stranding) from spawn to delivery. Assumes the FAIL loss
 * policy: the one crate can't re-arm after a retarget reset.
 */
/datum/mission_objective/field/capture_beast
	/// Mob typepath of the specimen (set by the mission at generation)
	var/target_mob_type
	/// The live marked specimen, from field spawn to the delivery handoff
	var/mob/living/target_mob
	/// The capture crate dispensed at accept
	var/obj/item/mission_recovery/capture_crate/kit
	/// The delivery step this objective hands the sealed crate to
	var/datum/mission_objective/deliver/bound/live_cargo/deliver_objective
	/// Whether the specimen has been sealed in the crate
	var/captured = FALSE

/datum/mission_objective/field/capture_beast/Destroy()
	target_mob = null
	kit = null // the item survives; it self-reports expiry on use
	deliver_objective = null
	return ..()

/datum/mission_objective/field/capture_beast/deactivate()
	// The refs were copied onto the delivery step before complete() advanced
	// the chain; its activate() re-registers both watches with no gap
	if(target_mob)
		UnregisterSignal(target_mob, COMSIG_LIVING_DEATH)
		target_mob = null
	if(kit)
		UnregisterSignal(kit, COMSIG_QDELETING)
		kit = null
	return ..()

/datum/mission_objective/field/capture_beast/reset()
	. = ..()
	captured = FALSE
	target_mob = null
	kit = null

/// Called by the mission at start: hand the crate over at the ship's pad
/datum/mission_objective/field/capture_beast/proc/dispense_kit()
	var/obj/structure/overmap/ship/ship = get_servant()
	var/turf/kit_turf
	for(var/obj/machinery/mission_pad/pad as anything in ship?.linked_mission_pads)
		if(!QDELETED(pad))
			kit_turf = get_turf(pad)
			break
	if(!kit_turf)
		mission.fail("No mission pad to dispense the capture crate to.")
		return FALSE
	kit = new(kit_turf)
	kit.objective_ref = WEAKREF(src)
	mission.bind_item(kit)
	// One crate per contract: losing it voids the capture
	RegisterSignal(kit, COMSIG_QDELETING, PROC_REF(on_crate_destroyed))
	notify_crew("Capture crate delivered to your mission pad. It only seals the survey-marked specimen, and only subdued.")
	return TRUE

/datum/mission_objective/field/capture_beast/spawn_field_objects(turf/spawn_turf)
	var/mob/living/beast = new target_mob_type(spawn_turf)
	beast.name = "marked [beast.name]"
	beast.desc += " It's wearing a guild survey tag. This is the contracted specimen, and it's worth nothing dead."
	target_mob = beast
	protect_field_mob(beast)
	RegisterSignal(beast, COMSIG_LIVING_DEATH, PROC_REF(on_target_death))
	mission.register_quest_atom(beast)
	notify_crew("Survey tag live - the marked specimen is on the surface ([mission.gps_tag]). Wear it down and crate it breathing.", type = SHIP_NOTIFY_WARNING, sound = 'voidcrew/sound/notify2.ogg')

/**
 * The specimen died before delivery: the client pays for live capture only.
 * An explicit fail (not kill_named's proof drop) - the mission is torn down
 * cleanly, so the dead contract can't gum up the board UI.
 */
/datum/mission_objective/field/capture_beast/proc/on_target_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	if(!mission || mission.failed || mission.completed)
		return
	UnregisterSignal(source, COMSIG_LIVING_DEATH)
	target_mob = null
	mission.fail("The specimen is dead. The client pays for live capture only - contract void.")

/// The one crate is gone before the seal: nothing left to deliver in
/datum/mission_objective/field/capture_beast/proc/on_crate_destroyed(datum/source)
	SIGNAL_HANDLER
	kit = null
	if(!mission || mission.failed || mission.completed)
		return
	mission.fail("Capture crate lost - the client's containment bond is void.")

/**
 * The crate sealed the specimen: hand both watches to the delivery step and
 * advance. The refs must land on the delivery objective BEFORE complete() -
 * its activate() runs synchronously off the advance and re-registers them.
 */
/datum/mission_objective/field/capture_beast/proc/on_captured(mob/living/user, mob/living/beast, obj/item/mission_recovery/capture_crate/crate)
	if(completed || !active || !mission || mission.failed || mission.completed)
		return
	captured = TRUE
	if(deliver_objective)
		deliver_objective.crate = crate
		deliver_objective.beast = beast
	notify_crew("Specimen sealed and stable in suspension. Bring the crate back to the mission pad alive.", sound = 'voidcrew/sound/notify2.ogg')
	complete()

/datum/mission_objective/field/capture_beast/get_progress_string()
	if(captured)
		return "Specimen crated"
	if(!spawned)
		var/datum/mission_target/target = mission?.target
		return target ? "Find the marked specimen at ([target.target_x], [target.target_y])" : "Find the marked specimen"
	return "Subdue the marked specimen and seal it in the capture crate"

// =========================================================================
// LIVE CARGO TURN-IN, the sealed crate, occupant breathing
// =========================================================================

/**
 * The bound carry-home step with a pulse check: only THIS contract's crate
 * matches (instance + binding serial, so a foreign crate never pays), and
 * only sealed with the contracted specimen alive inside. The step owns both
 * death-in-transit and crate-destruction watches from the seal onward;
 * either fires the contract void.
 */
/datum/mission_objective/deliver/bound/live_cargo
	required_name = "the sealed capture crate"
	/// The sealed crate (set by the capture step at handoff)
	var/obj/item/mission_recovery/capture_crate/crate
	/// The living specimen inside (set by the capture step at handoff)
	var/mob/living/beast

/datum/mission_objective/deliver/bound/live_cargo/Destroy()
	crate = null
	beast = null
	return ..()

/datum/mission_objective/deliver/bound/live_cargo/activate()
	. = ..()
	// The capture step set our refs before completing; take over both watches
	if(QDELETED(crate) || QDELETED(beast))
		mission?.fail("The sealed specimen was lost in handoff - contract void.")
		return
	RegisterSignal(crate, COMSIG_QDELETING, PROC_REF(on_crate_destroyed))
	RegisterSignal(beast, COMSIG_LIVING_DEATH, PROC_REF(on_beast_death))

/datum/mission_objective/deliver/bound/live_cargo/deactivate()
	if(crate)
		UnregisterSignal(crate, COMSIG_QDELETING)
	if(beast)
		UnregisterSignal(beast, COMSIG_LIVING_DEATH)
	return ..()

/datum/mission_objective/deliver/bound/live_cargo/reset()
	. = ..()
	crate = null
	beast = null

/// The crate was destroyed in transit: the beast is already loose (and angry)
/datum/mission_objective/deliver/bound/live_cargo/proc/on_crate_destroyed(datum/source)
	SIGNAL_HANDLER
	crate = null
	if(!mission || mission.failed || mission.completed)
		return
	mission.fail("The capture crate was destroyed and the specimen is loose - contract void.")

/// The specimen died inside the crate (or loose after a breakout)
/datum/mission_objective/deliver/bound/live_cargo/proc/on_beast_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	if(!mission || mission.failed || mission.completed)
		return
	UnregisterSignal(source, COMSIG_LIVING_DEATH)
	beast = null
	mission.fail("The specimen died in transit. The client pays for live delivery only - contract void.")

/datum/mission_objective/deliver/bound/live_cargo/describe_ask()
	return "the sealed crate holding [mission?.objective_name || "the specimen"] - alive"

/datum/mission_objective/deliver/bound/live_cargo/get_progress_string()
	return "Deliver the sealed crate to the mission pad - specimen alive"

/datum/mission_objective/deliver/bound/live_cargo/can_turn_in(obj/item/item)
	if(!..()) // mission_recovery family + contract binding + era serial
		return FALSE
	if(item != crate) // the one crate this contract dispensed; foreign crates never match
		return FALSE
	var/obj/item/mission_recovery/capture_crate/offered = item
	if(!offered.sealed)
		return FALSE
	var/mob/living/cargo = offered.occupant
	if(QDELETED(cargo) || cargo.stat == DEAD)
		return FALSE
	if(beast && cargo != beast)
		return FALSE
	return TRUE

/datum/mission_objective/deliver/bound/live_cargo/describe_turn_in_failure(obj/item/item)
	if(!item)
		return "No item provided."
	if(!istype(item, /obj/item/mission_recovery/capture_crate))
		return "The client wants the sealed capture crate."
	if(item != crate)
		return ..() // the bound-family binding messages cover foreign crates
	var/obj/item/mission_recovery/capture_crate/offered = item
	if(!offered.sealed)
		return "The crate hasn't sealed - the specimen isn't inside."
	var/mob/living/cargo = offered.occupant
	if(QDELETED(cargo))
		return "The crate is empty."
	if(cargo.stat == DEAD)
		return "The specimen inside is dead. The client pays for live delivery only."
	if(beast && cargo != beast)
		return "That isn't the contracted specimen."
	return ..()

/datum/mission_objective/deliver/bound/live_cargo/accept_item(obj/item/item, atom/reward_anchor)
	var/obj/item/mission_recovery/capture_crate/delivered = item
	// Consuming the delivery isn't losing it: stop the shell's and our own
	// watches before the crate (and its sleeper) leave the world
	if(beast)
		mission.forget_quest_atom(beast)
		UnregisterSignal(beast, COMSIG_LIVING_DEATH)
		beast = null
	if(crate)
		UnregisterSignal(crate, COMSIG_QDELETING)
		crate = null
	delivered.handed_over = TRUE
	qdel(delivered)
	complete()
	return MISSION_ITEM_COMPLETE

/**
 * # Capture Crate
 *
 * The kit handed over at accept: a guild-issue xenofauna transport pod. Use
 * it on the survey-marked specimen - only the marked one, only subdued -
 * and a short wrestle seals it inside under a suspension field.
 *
 * CONTAINMENT AUDIT (vs the stock pet carrier, which leaks):
 * * relaymove: carrier lets closed-but-unlocked occupants shove the door
 *   open. Here: flavored no-op, throttled feedback, no state change.
 * * container_resist_act: carrier lets small mobs reach the lock (30-40s)
 *   and big mobs shove out (20s). Here: flavored no-op, nothing else.
 * * acting from inside: the occupant rides the grouped stasis status effect
 *   (TRAIT_IMMOBILIZED + TRAIT_HANDS_BLOCKED + TRAIT_STASIS - no Life ticks,
 *   no attacks, no ability use) with TRAIT_AI_PAUSED shutting the mob's AI
 *   controller off entirely.
 * * no open/close or lock toggle exists: the seal is one-way. Only outside
 *   destruction reopens it - and that releases the specimen alive, awake
 *   and furious (which is intended; the ban is on freeing ITSELF).
 */
/obj/item/mission_recovery/capture_crate
	name = "capture crate"
	desc = "A guild-issue xenofauna transport pod: reinforced shell, intake maw, suspension-field emitter. \
		It only takes the survey-marked specimen, and only once it's been worn down. After it seals, nobody opens it but the client's assayer."
	icon_state = "capture_crate"
	base_icon_state = "capture_crate"
	w_class = WEIGHT_CLASS_BULKY
	throw_speed = 2
	throw_range = 3

	/// Weakref to the capture objective this crate serves
	var/datum/weakref/objective_ref
	/// The sealed-in specimen
	var/mob/living/occupant
	/// Whether the crate has sealed (one-way; only destruction reopens it)
	var/sealed = FALSE
	/// TRUE during turn-in: the delivery leaves with the crate instead of being released
	var/handed_over = FALSE
	/// Throttle so a captive mashing movement keys doesn't spam the room
	COOLDOWN_DECLARE(struggle_message_cooldown)

/obj/item/mission_recovery/capture_crate/Destroy()
	if(!QDELETED(occupant))
		if(handed_over)
			QDEL_NULL(occupant) // the delivery leaves with the client
		else
			release_angry()
	occupant = null
	return ..()

/obj/item/mission_recovery/capture_crate/examine(mob/user)
	. = ..()
	if(sealed && occupant)
		if(occupant.stat == DEAD)
			. += span_warning("Through the viewport, [occupant] hangs limp. It's dead.")
		else
			. += span_notice("Through the viewport, [occupant] floats motionless in the suspension field, alive and completely out of it.")
	else if(!sealed)
		. += span_notice("Its intake maw stands open. It will only take the survey-marked specimen, and only subdued.")

/// Whether the specimen is worn down enough for the crate to take it
/obj/item/mission_recovery/capture_crate/proc/is_subdued(mob/living/beast)
	if(beast.health <= beast.maxHealth * CAPTURE_HEALTH_FRACTION)
		return TRUE
	if(beast.stat == HARD_CRIT || HAS_TRAIT(beast, TRAIT_KNOCKEDOUT))
		return TRUE
	if(HAS_TRAIT(beast, TRAIT_INCAPACITATED))
		return TRUE
	return FALSE

/obj/item/mission_recovery/capture_crate/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(user.combat_mode || !isliving(interacting_with))
		return NONE
	if(sealed)
		balloon_alert(user, "already sealed!")
		return ITEM_INTERACT_BLOCKING
	var/datum/mission_objective/field/capture_beast/objective = objective_ref?.resolve()
	if(!objective?.mission || objective.mission.failed || objective.mission.completed)
		balloon_alert(user, "contract expired!")
		return ITEM_INTERACT_BLOCKING
	if(!objective.active)
		balloon_alert(user, "not the contract's current step!")
		return ITEM_INTERACT_BLOCKING
	var/mob/living/beast = interacting_with
	if(beast != objective.target_mob)
		balloon_alert(user, "not the marked specimen!")
		return ITEM_INTERACT_BLOCKING
	if(beast.stat == DEAD)
		balloon_alert(user, "it's dead - worthless!")
		return ITEM_INTERACT_BLOCKING
	if(!is_subdued(beast))
		balloon_alert(user, "too lively - wear it down first!")
		return ITEM_INTERACT_BLOCKING
	if(!isturf(beast.loc))
		balloon_alert(user, "can't box it from there!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "wrestling it in...")
	playsound(src, 'sound/items/handling/cardboard_box/cardboardbox_drop.ogg', 60, TRUE)
	if(!do_after(user, CRATE_SEAL_TIME, target = beast))
		balloon_alert(user, "sealing interrupted!")
		return ITEM_INTERACT_BLOCKING
	// Re-validate: the channel gave the specimen (and the contract) time to change
	if(sealed || QDELETED(beast) || !objective.active || !objective.mission || objective.mission.failed || objective.mission.completed)
		return ITEM_INTERACT_BLOCKING
	if(beast != objective.target_mob || beast.stat == DEAD || !is_subdued(beast) || !isturf(beast.loc) || !user.Adjacent(beast))
		balloon_alert(user, "it slipped the crate!")
		return ITEM_INTERACT_BLOCKING
	user.visible_message(span_notice("[user] wrestles [beast] into [src], and its suspension field spins up with a low hum."))
	seal_in(beast)
	objective.on_captured(user, beast, src)
	return ITEM_INTERACT_SUCCESS

/// Clear feedback for clicking the specimen from out of reach
/obj/item/mission_recovery/capture_crate/ranged_interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!user.combat_mode && isliving(interacting_with) && !sealed)
		balloon_alert(user, "too far away!")
		return ITEM_INTERACT_BLOCKING
	return NONE

/**
 * The one-way seal: specimen inside, dormancy on, door welded shut forever.
 * Dormancy uses EXISTING tools only - the grouped stasis status effect (the
 * legion-consumed pattern) plus TRAIT_AI_PAUSED (the frog-statue pattern).
 */
/obj/item/mission_recovery/capture_crate/proc/seal_in(mob/living/beast)
	occupant = beast
	sealed = TRUE
	beast.forceMove(src)
	beast.apply_status_effect(/datum/status_effect/grouped/stasis, STASIS_CAPTURE_CRATE)
	ADD_TRAIT(beast, TRAIT_AI_PAUSED, REF(src))
	name = "sealed capture crate"
	icon_state = "[base_icon_state]_sealed"
	playsound(src, 'sound/machines/airlock/boltsdown.ogg', 40, TRUE)

/obj/item/mission_recovery/capture_crate/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone != occupant)
		return
	// However the specimen leaves - breakout release, admin move, anything -
	// the suspension field comes off with it, so it can never be left frozen
	var/mob/living/freed = occupant
	occupant = null
	freed.remove_status_effect(/datum/status_effect/grouped/stasis, STASIS_CAPTURE_CRATE)
	REMOVE_TRAIT(freed, TRAIT_AI_PAUSED, REF(src))
	freed.setDir(SOUTH)

/// The shell gave way with the specimen inside: alive, awake and furious
/obj/item/mission_recovery/capture_crate/proc/release_angry()
	if(QDELETED(occupant))
		return
	var/mob/living/freed = occupant
	freed.forceMove(drop_location()) // Exited() wakes it and strips the field
	freed.visible_message(span_boldwarning("[freed] bursts out of the ruptured [name], furious!"))

/obj/item/mission_recovery/capture_crate/atom_destruction(damage_flag)
	release_angry()
	return ..()

/// ESCAPE PATH 1 (pet carrier: shove the unlocked door open): closed forever
/obj/item/mission_recovery/capture_crate/relaymove(mob/living/user, direction)
	if(user != occupant)
		return
	if(!COOLDOWN_FINISHED(src, struggle_message_cooldown))
		return
	COOLDOWN_START(src, struggle_message_cooldown, CRATE_STRUGGLE_COOLDOWN)
	to_chat(user, span_warning("You strain against [src]'s shell, but the suspension field saps the strength out of every push."))
	visible_message(span_warning("[src] rocks faintly."), vision_distance = 2)

/// ESCAPE PATH 2 (pet carrier: reach the lock / push out over a channel): no channel exists
/obj/item/mission_recovery/capture_crate/container_resist_act(mob/living/user)
	to_chat(user, span_warning("The suspension field kills every movement before it starts. [src] doesn't even rattle."))

/obj/item/mission_recovery/capture_crate/attack_self(mob/user)
	. = ..()
	if(.)
		return
	if(sealed)
		balloon_alert(user, "sealed until delivery!")
	else
		balloon_alert(user, "use it on the subdued, marked specimen!")
	return TRUE

#undef CAPTURE_HEALTH_FRACTION
#undef CRATE_SEAL_TIME
#undef CRATE_STRUGGLE_COOLDOWN
#undef STASIS_CAPTURE_CRATE

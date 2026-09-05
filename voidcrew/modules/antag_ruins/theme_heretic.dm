/**
 * # The Reliquary: heretic vestige
 *
 * A shrine ship parked in front of a door to the Mansus that never opened.
 * The scholar aboard transcribed at that threshold for a lifetime while the
 * rust (the door's toll, paid in iron) ate the ship around them. The trials
 * are the Scrivener's own work, farmed out: spreading the rust, transcribing
 * locked doors, paying tolls; the boons are pages copied from the threshold: clean
 * heretic path spells granted directly where their cast chains carry no
 * IS_HERETIC gate (ash jaunt, ashen walk, shadow cloak, verified against
 * live code), and local ports where the upstream spell couples to the
 * heretic datum (the rusted grasp; see each spell's doc comment).
 */

// ===== PATRON =====

/mob/living/basic/vestige_patron/scrivener
	name = "the Scrivener"
	desc = "A robed figure at a lectern, quill still moving. The hand holding it rusted to the bone a long time ago, and kept writing anyway."
	gender = NEUTER
	outfit_path = /datum/outfit/job/curator
	appearance_tint = "#a06438"
	trial_types = list(
		/datum/vestige_trial/rite_of_rust,
		/datum/vestige_trial/rite_of_transcription,
		/datum/vestige_trial/rite_of_toll,
	)
	boon_types = list(
		/datum/vestige_boon/spell/ashen_passage,
		/datum/vestige_boon/spell/ashen_passage/walk,
		/datum/vestige_boon/spell/cloak_of_shadow,
		/datum/vestige_boon/spell/rusted_grasp,
		/datum/vestige_boon/spell/rusted_grasp/second_reading,
		/datum/vestige_boon/spell/iron_refusal,
	)
	idle_lines = list(
		"The door never opened. I thought that was the tragedy. Then I understood - the rust was the answer. It had been replying the whole time.",
		"Every lock is a sentence. Rust is how iron confesses.",
		"I transcribed four hundred volumes waiting at that threshold. The ship read them before I did. Look what it learned.",
		"Don't pity the corroded. Rust is just metal remembering it used to be dirt.",
		"Every threshold takes a toll. The ship paid in iron. I paid in years. Years are the heavier coin, believe me.",
	)
	accept_line = "Yes. Spread the reply. Let the iron confess."
	busy_line = "Your hand is already promised to someone else. I don't write over other people's work."
	fulfilled_line = "That page is written. I don't copy twice."
	renounce_line = "Blank pages burn just as well."
	claim_line = "You're owed something. Collect it before you start a new page."
	exhausted_line = "You've copied everything I kept. The rest belongs to the door."
	remember_line = "Death edits. It doesn't delete. Your notes survived it."

// ===== RITE OF RUST =====

/datum/vestige_trial/rite_of_rust
	name = "Rite of Rust"
	desc = "Set the threshold weight beside an ordinary iron wall with clear floor beyond. Anoint the wall twice to dissolve it: this releases a rust guardian. Pull the weight through that exact breach, protect it, and rebuild the wall behind it with the supplied iron and welder. Recover the weight on the far side of the sealed wall to finish. You may fight the guardian or outbuild it. Build an internal test wall first if your ship has no suitable safe breach."
	var/obj/item/vestige_threshold_weight/weight
	var/turf/passage
	var/turf/destination
	var/opened = FALSE
	var/crossed = FALSE
	var/turf/starting_side
	var/mob/living/basic/hivebot/vestige_threshold_guardian/guardian

/datum/vestige_trial/rite_of_rust/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_chrism(get_turf(user)))
	weight = hand_over(user, new /obj/item/vestige_threshold_weight(get_turf(user)))
	weight.keeper = owner
	hand_over(user, new /obj/item/stack/sheet/iron(get_turf(user), 10))
	hand_over(user, new /obj/item/weldingtool(get_turf(user)))

/datum/vestige_trial/rite_of_rust/Destroy()
	STOP_PROCESSING(SSobj, src)
	QDEL_NULL(guardian)
	return ..()

/datum/vestige_trial/rite_of_rust/get_progress_text()
	return opened ? "Protect the weight, pull it through the breach, and rebuild the wall behind it. Passage crossed: [crossed ? "yes" : "no"]. Recover it on the far side." : "Place the threshold weight beside an iron wall, then anoint that wall twice. Ready a weapon and building materials first."

/// May complete (and delete) the trial
/datum/vestige_trial/rite_of_rust/proc/choose_wall(turf/closed/wall/wall)
	if(wall.type != /turf/closed/wall || !isturf(weight?.loc) || get_dist(weight, wall) != 1)
		return FALSE
	if(weight.x != wall.x && weight.y != wall.y)
		return FALSE
	var/turf/far_side = get_step(wall, get_dir(weight, wall))
	if(!isopenturf(far_side) || isspaceturf(far_side) || far_side.is_blocked_turf(exclude_mobs = TRUE))
		return FALSE
	passage = wall
	destination = far_side
	starting_side = get_turf(weight)
	return TRUE

/datum/vestige_trial/rite_of_rust/process(seconds_per_tick)
	if(!opened || !crossed || !weight || get_turf(weight) != destination || !isturf(weight.loc) || !istype(passage, /turf/closed/wall))
		return
	var/turf/open/floor = destination
	if(floor.return_air()?.return_pressure() < 80)
		return
	complete()

/datum/vestige_trial/rite_of_rust/proc/release_guardian()
	guardian = new(starting_side)
	guardian.ai_controller?.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, weight)

/obj/item/vestige_threshold_weight
	name = "threshold weight"
	desc = "Drop it beside an iron wall, dissolve the wall, pull the weight through the breach, and rebuild the wall behind it. The released guardian wants the weight."
	icon = 'icons/obj/ore.dmi'
	icon_state = "iron"
	w_class = WEIGHT_CLASS_BULKY
	max_integrity = 120
	var/datum/mind/keeper

/obj/item/vestige_threshold_weight/Moved(atom/old_loc, movement_dir, forced, list/old_locs)
	. = ..()
	var/datum/vestige_trial/rite_of_rust/trial = keeper?.active_vestige_trial
	if(istype(trial) && trial.weight == src && trial.opened && old_loc == trial.passage && loc == trial.destination)
		trial.crossed = TRUE
		trial.refresh_tracker()

/mob/living/basic/hivebot/vestige_threshold_guardian
	name = "threshold guardian"
	desc = "The door's answer, pursuing the stolen iron. Seal the breach after getting the weight through."
	health = 65
	maxHealth = 65
	melee_damage_lower = 8
	melee_damage_upper = 8
	obj_damage = 12
	melee_attack_cooldown = 2 SECONDS
	ai_controller = /datum/ai_controller/basic_controller/hivebot/vestige_threshold_guardian

/datum/ai_controller/basic_controller/hivebot/vestige_threshold_guardian
	blackboard = list(BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic/vestige_threshold_guardian)

/datum/targeting_strategy/basic/vestige_threshold_guardian/can_attack(mob/living/living_mob, atom/the_target, vision_range)
	if(istype(the_target, /obj/item/vestige_threshold_weight))
		return !QDELETED(the_target) && living_mob.z == the_target.z && (!vision_range || get_dist(living_mob, the_target) <= vision_range)
	return ..()

/obj/item/vestige_chrism
	name = "corroding chrism"
	desc = "A flask of oil the colour of old blood. Anything it touches starts rusting through."
	icon = 'icons/obj/drinks/bottles.dmi'
	icon_state = "holyflask"
	color = "#c46a33"
	w_class = WEIGHT_CLASS_SMALL

/obj/item/vestige_chrism/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/datum/vestige_trial/rite_of_rust/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || trial.opened || !istype(interacting_with, /turf/closed/wall))
		return NONE
	if(trial.passage != interacting_with && !trial.choose_wall(interacting_with))
		balloon_alert(user, "weight beside wall, clear floor beyond!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "anointing...")
	if(!do_after(user, 2 SECONDS, interacting_with))
		return ITEM_INTERACT_BLOCKING
	if(user.mind?.active_vestige_trial != trial || !user.is_holding(src))
		return ITEM_INTERACT_BLOCKING
	interacting_with.rust_heretic_act()
	if(!isopenturf(trial.passage) && !HAS_TRAIT(interacting_with, TRAIT_RUSTY))
		balloon_alert(user, "it won't take!")
		return ITEM_INTERACT_BLOCKING
	user.visible_message(
		span_danger("[user] smears something dark across [interacting_with], and the rust follows [user.p_their()] hand."),
		span_notice("You smear the chrism across [interacting_with] and watch the rust take hold."),
	)
	playsound(interacting_with, 'sound/effects/magic/curse.ogg', 25, TRUE)
	if(isopenturf(trial.passage))
		trial.opened = TRUE
		trial.release_guardian()
		START_PROCESSING(SSobj, trial)
	trial.refresh_tracker()
	return ITEM_INTERACT_SUCCESS

// ===== RITE OF TRANSCRIPTION =====

/datum/vestige_trial/rite_of_transcription
	name = "Rite of Transcription"
	desc = "Read a closed airlock that is bolted or denies your actual ID. Use engineering to make it pryable, then successfully crowbar it open, walk through its tile, and shut and transcribe it from the opposite side. It must again deny your ID or be bolted when you finish. Your own ship's bolted airlock is valid, but remote toggling alone does not count: the quill witnesses a real manual breach. The tools are supplied."
	var/obj/machinery/door/airlock/threshold
	var/turf/approach
	var/crossed = FALSE
	var/mob/living/walker
	var/breached = FALSE
	var/pry_until = 0
	var/datum/weakref/prying_tool

/datum/vestige_trial/rite_of_transcription/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_quill(get_turf(user)))
	hand_over(user, new /obj/item/storage/toolbox/mechanical(get_turf(user)))
	hand_over(user, new /obj/item/multitool(get_turf(user)))
	walker = user
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(on_walked))
	to_chat(user, span_notice("The quill settles between your fingers, nib first."))

/datum/vestige_trial/rite_of_transcription/Destroy()
	if(walker)
		UnregisterSignal(walker, COMSIG_MOVABLE_MOVED)
	walker = null
	if(threshold)
		UnregisterSignal(threshold, list(COMSIG_ATOM_TOOL_ACT(TOOL_CROWBAR), COMSIG_AIRLOCK_OPEN))
	return ..()

/// Listen to the successful result of an actual pry attempt, not to panel toggles or failed tool clicks.
/datum/vestige_trial/rite_of_transcription/proc/on_prying(atom/source, mob/living/user, obj/item/tool, list/recipes)
	SIGNAL_HANDLER
	if(user != owner?.current || !threshold.density || threshold.operating || threshold.locked || threshold.welded || threshold.seal)
		return
	var/obj/item/crowbar/crowbar = tool
	if(threshold.hasPower() && (!istype(crowbar) || !crowbar.force_opens))
		return
	pry_until = world.time + 6 SECONDS
	prying_tool = WEAKREF(tool)

/datum/vestige_trial/rite_of_transcription/proc/on_pried(obj/machinery/door/airlock/source, forced)
	SIGNAL_HANDLER
	var/mob/living/user = owner?.current
	if(forced == BYPASS_DOOR_CHECKS && world.time <= pry_until && user?.is_holding(prying_tool?.resolve()))
		breached = TRUE
		refresh_tracker()
	pry_until = 0
	prying_tool = null

/datum/vestige_trial/rite_of_transcription/proc/on_walked(mob/living/source)
	SIGNAL_HANDLER
	if(threshold && breached && !threshold.density && get_turf(source) == get_turf(threshold))
		crossed = TRUE
		refresh_tracker()

/datum/vestige_trial/rite_of_transcription/get_progress_text()
	return threshold ? "Pry open [threshold], cross it, then shut and read it from the opposite side. Manual breach: [breached ? "yes" : "no"]. Crossing: [crossed ? "yes" : "no"]." : "Read a bolted airlock or one that denies your ID from an adjacent cardinal tile."

/// May complete (and delete) the trial. Returns FALSE if this door was already transcribed.
/datum/vestige_trial/rite_of_transcription/proc/transcribe(obj/machinery/door/airlock/door, mob/living/user)
	var/turf/here = get_turf(user)
	if(get_dist(here, door) != 1 || (here.x != door.x && here.y != door.y))
		return FALSE
	if(!threshold || QDELETED(threshold))
		threshold = door
		RegisterSignal(threshold, COMSIG_ATOM_TOOL_ACT(TOOL_CROWBAR), PROC_REF(on_prying))
		RegisterSignal(threshold, COMSIG_AIRLOCK_OPEN, PROC_REF(on_pried))
		approach = here
		crossed = FALSE
		breached = FALSE
		refresh_tracker()
		return TRUE
	if(door != threshold || !crossed || get_dir(door, here) != turn(get_dir(door, approach), 180))
		return FALSE
	complete()
	return TRUE

/obj/item/vestige_quill
	name = "rust-cut quill"
	desc = "A sliver of rusted iron, shaved thin enough to flex like a feather. It only writes what doors tell it."
	icon = 'icons/obj/service/bureaucracy.dmi'
	icon_state = "feather"
	color = "#c46a33"
	w_class = WEIGHT_CLASS_TINY

/obj/item/vestige_quill/examine(mob/user)
	. = ..()
	. += span_notice("Read a shut airlock that is bolted or denies your ID, engineer a successful crowbar opening and cross it, then close and read it from the opposite side. Stand directly north, south, east or west when reading.")

/obj/item/vestige_quill/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!istype(interacting_with, /obj/machinery/door/airlock))
		return NONE
	var/obj/machinery/door/door = interacting_with
	var/datum/vestige_trial/rite_of_transcription/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the quill won't write!")
		return ITEM_INTERACT_BLOCKING
	// No pressing it to the vestige's own doors. Those pages are the patron's, already written
	if(istype(get_area(door), /area/ruin/space/has_grav/vestige))
		balloon_alert(user, "these doors don't count!")
		return ITEM_INTERACT_BLOCKING
	if(!has_sentence(door, user))
		balloon_alert(user, "no lock, nothing to write!")
		return ITEM_INTERACT_BLOCKING
	// The reading is public: a stranger tracing a guarded door's seams looks exactly like what it is
	user.visible_message(
		span_warning("[user] presses [src] flat against [door] and begins tracing its seams."),
		span_notice("You press [src] to [door] and wait for it to start writing."),
	)
	playsound(door, 'sound/effects/page_turn/pageturn1.ogg', 40, TRUE)
	if(!do_after(user, 5 SECONDS, door)) // long enough for the door's keepers to take issue
		return ITEM_INTERACT_BLOCKING
	if(user.mind?.active_vestige_trial != trial || !user.is_holding(src))
		return ITEM_INTERACT_BLOCKING
	// Opening the door mid-reading breaks the line. Its keepers can foil the rite by simply using it
	if(!has_sentence(door, user))
		balloon_alert(user, "the door opened!")
		return ITEM_INTERACT_BLOCKING
	if(!trial.transcribe(door, user))
		balloon_alert(user, "cross first, then read the opposite side!")
		return ITEM_INTERACT_BLOCKING
	user.visible_message(
		span_warning("A line of rust-red script crawls across [door] and fades."),
		span_notice("The quill finishes: every refusal this door ever made, written down."),
	)
	playsound(door, 'sound/effects/magic/curse.ogg', 25, TRUE)
	return ITEM_INTERACT_SUCCESS

/// A door has a sentence worth taking down while it stands shut against somebody: bolted, or access-restricted
/obj/item/vestige_quill/proc/has_sentence(obj/machinery/door/door, mob/living/user)
	if(QDELETED(door) || !door.density)
		return FALSE
	return door.locked || !door.allowed(user)

// ===== RITE OF THE TOLL =====

/datum/vestige_trial/rite_of_toll
	name = "Rite of the Toll"
	desc = "The casket's lock is caught between pressure and spring tension. A wrench vents up to two pressure; a screwdriver releases up to two tension. Removing two adds one to the other force; releasing a final single point is gentle. A crowbar removes one of each but strains the casing. Reach zero in both without breaking it, then use the casket in hand to sacrifice the last tool that worked the lock. A jam can be reset without losing tools."
	var/obj/item/vestige_toll_casket/casket

/datum/vestige_trial/rite_of_toll/on_accepted(mob/living/user)
	casket = hand_over(user, new /obj/item/vestige_toll_casket(get_turf(user)))
	hand_over(user, new /obj/item/screwdriver(get_turf(user)))
	hand_over(user, new /obj/item/wrench(get_turf(user)))
	hand_over(user, new /obj/item/crowbar(get_turf(user)))

/datum/vestige_trial/rite_of_toll/get_progress_text()
	return casket ? "Lock pressure [casket.pressure], spring tension [casket.tension], casing strain [casket.strain]/4. Zero both forces; then use the casket in hand with the last tool in your other hand." : "The casket is missing. Restart the pact for a fresh kit."

/obj/item/vestige_toll_casket
	name = "toll-casket"
	desc = "A lock whose forces must be balanced before it will name its price."
	icon = 'icons/obj/storage/case.dmi'
	icon_state = "lockbox+l"
	color = "#c46a33"
	w_class = WEIGHT_CLASS_NORMAL
	var/pressure = 0
	var/tension = 0
	var/strain = 0
	var/datum/weakref/last_tool
	var/working = FALSE

/obj/item/vestige_toll_casket/Initialize(mapload)
	. = ..()
	reset_lock()

/obj/item/vestige_toll_casket/proc/reset_lock()
	pressure = rand(3, 6)
	tension = rand(3, 6)
	strain = 0
	last_tool = null

/obj/item/vestige_toll_casket/examine(mob/user)
	. = ..()
	. += span_notice("Pressure: [pressure]. Tension: [tension]. Casing strain: [strain]/4. Wrench removes up to two pressure; screwdriver removes up to two tension. Removing two adds one to the other force; removing one does not. Crowbar removes one of each and adds one strain. Four strain jams the casing. Use in hand to reset, or, once balanced, to sacrifice the last tool from your other hand.")

/obj/item/vestige_toll_casket/proc/work_lock(instrument)
	if(strain >= 4 || (!pressure && !tension))
		return FALSE
	switch(instrument)
		if(TOOL_WRENCH)
			if(!pressure)
				return FALSE
			if(pressure >= 2)
				tension++
			pressure = max(0, pressure - 2)
		if(TOOL_SCREWDRIVER)
			if(!tension)
				return FALSE
			if(tension >= 2)
				pressure++
			tension = max(0, tension - 2)
		if(TOOL_CROWBAR)
			pressure = max(0, pressure - 1)
			tension = max(0, tension - 1)
			strain++
		else
			return FALSE
	return TRUE

/obj/item/vestige_toll_casket/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	var/datum/vestige_trial/rite_of_toll/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || trial.casket != src || working)
		return ITEM_INTERACT_BLOCKING
	if(!(tool.tool_behaviour in list(TOOL_WRENCH, TOOL_SCREWDRIVER, TOOL_CROWBAR)))
		return NONE
	working = TRUE
	var/success = tool.use_tool(src, user, 2 SECONDS)
	working = FALSE
	if(!success || user.mind?.active_vestige_trial != trial || !user.is_holding(tool))
		return ITEM_INTERACT_BLOCKING
	if(!work_lock(tool.tool_behaviour))
		balloon_alert(user, strain >= 4 ? "jammed! reset in hand" : "balanced! pay in hand")
		return ITEM_INTERACT_BLOCKING
	last_tool = WEAKREF(tool)
	trial.refresh_tracker()
	to_chat(user, span_notice(trial.get_progress_text()))
	return ITEM_INTERACT_SUCCESS

/obj/item/vestige_toll_casket/attack_self(mob/living/user, modifiers)
	var/datum/vestige_trial/rite_of_toll/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || trial.casket != src || working)
		return TRUE
	if(pressure || tension || strain >= 4)
		reset_lock()
		trial.refresh_tracker()
		to_chat(user, span_notice("The lock winds back. No tools were spent; examine the new forces."))
		return TRUE
	var/obj/item/payment = last_tool?.resolve()
	if(!payment || !user.is_holding(payment) || !user.temporarilyRemoveItemFromInventory(payment))
		balloon_alert(user, "hold the final tool in your other hand!")
		return TRUE
	qdel(payment)
	trial.complete()
	return TRUE

// ===== BOONS =====

// The passage, the walk and the cloak are "clean" heretic magic used directly:
// spell_requirements = NONE upstream, no IS_HERETIC gate anywhere in their
// cast chains (the whole spell_types/jaunt/ module is antag-free, verified).
// The rust boons further down are local ports; each spell's doc comment
// records exactly what upstream coupling forced the copy.
/datum/vestige_boon/spell/ashen_passage
	name = "Ashen Passage"
	desc = "Turn into ash and drift through walls for a moment. It doesn't last long, and it is slow to recharge."
	grant_text = "Your edges loosen. Walls stop looking solid."
	spell_type = /datum/action/cooldown/spell/jaunt/ethereal_jaunt/ash/vestige

// The jaunt's own upstream upgrade (ethereal_jaunt/ash/long): identical clean
// cast chain, the drift simply holds for 5 seconds instead of 1.1.
/datum/vestige_boon/spell/ashen_passage/walk
	name = "Ashen Walk"
	desc = "The same drift, but it holds long enough to cross a whole corridor instead of one wall, and it recharges faster."
	grant_text = "The ash holds together for a lot longer now."
	upgrades_from = /datum/vestige_boon/spell/ashen_passage
	spell_type = /datum/action/cooldown/spell/jaunt/ethereal_jaunt/ash/long/vestige

/datum/vestige_boon/spell/cloak_of_shadow
	name = "Cloak of Shadow"
	desc = "Wrap yourself in shadow. It hides your name and face from anyone looking at you."
	grant_text = "The shadows settle over you like they were cut to fit."
	spell_type = /datum/action/cooldown/spell/shadow_cloak

/datum/vestige_boon/spell/rusted_grasp
	name = "Rusted Grasp"
	desc = "Rust your hand, then touch something with it. People lose stamina and start slurring, airlocks lose power for a while, machines corrode visibly, and iron walls and floors rust through, reinforced ones included."
	grant_text = "Red rust settles into the creases of your palm."
	spell_type = /datum/action/cooldown/spell/touch/vestige_rusted_grasp

/datum/vestige_boon/spell/rusted_grasp/second_reading
	name = "Second Reading"
	desc = "The grasp, improved. It rusts titanium hull plating as well as iron, wrecks most machines in one touch, knocks people down for a moment, and comes back faster."
	grant_text = "The rust on your palm darkens and sets deeper."
	upgrades_from = /datum/vestige_boon/spell/rusted_grasp
	spell_type = /datum/action/cooldown/spell/touch/vestige_rusted_grasp/second_reading

/datum/vestige_boon/spell/iron_refusal
	name = "Iron Refusal"
	desc = "Point at a floor and it stands up as a wall of rusted iron. Anyone standing on it gets knocked aside."
	grant_text = "Rusted floors start listening to you."
	spell_type = /datum/action/cooldown/spell/pointed/rust_construction/vestige

// ===== BOON SPELLS =====

/**
 * The passage, slowed down and given a voice. Upstream's ash jaunt is silent
 * on purpose, it nulls both the cast sound and exit_jaunt_sound the base
 * ethereal jaunt carries, and recharges in 15 seconds, which for a crewman is
 * a wall that may as well not be there. Subtyped rather than edited in place so
 * the heretic's own passage keeps upstream's numbers.
 */
/datum/action/cooldown/spell/jaunt/ethereal_jaunt/ash/vestige
	name = "Ashen Drift"
	cooldown_time = 90 SECONDS
	sound = 'sound/effects/magic/ethereal_enter.ogg'
	exit_jaunt_sound = 'sound/effects/magic/ethereal_exit.ogg'

/// The long drift, on the same terms: the recharge relaxes to a minute.
/datum/action/cooldown/spell/jaunt/ethereal_jaunt/ash/long/vestige
	name = "Ashen Crossing"
	cooldown_time = 60 SECONDS
	sound = 'sound/effects/magic/ethereal_enter.ogg'
	exit_jaunt_sound = 'sound/effects/magic/ethereal_exit.ogg'

/**
 * A rust-fist in the Scrivener's style, standing in for the Mansus grasp. The
 * upstream grasp is hard-coupled. Its can_cast_spell demands IS_HERETIC or
 * IS_LUNATIC, and all of its interesting effects ride heretic knowledge
 * signals, so this is a fresh touch spell on the same chassis (the touch
 * base class in _touch.dm carries no antag checks, verified).
 *
 * One hand, four confessions, all tuned below the antag original (which
 * deals 80 stamina plus a 5-second knockdown on a 10-second loop):
 * - the living: a stamina sap and a rusted tongue; no knockdown at this tier
 * - airlocks: loseMainPower: ~60 seconds without power, pryable meanwhile
 * - machines and structures: corrosion damage plus the rust element, so the
 *   hit is visible; still far below the flat 500 the heretic
 *   rust_heretic_act deals to machinery. The damage carries no armour flag on
 *   purpose, machinery melee armour was soaking a third to a half of it, and
 *   plating is not an argument against oxidation.
 * - walls and floors: a single aimed turf rusted, never a spread. Strength 2
 *   reads basic and reinforced iron; the second reading's 3 adds titanium and
 *   plastitanium, which in this fork means ship hulls and shuttle plating,
 *   most of what a crewman ever stands on. Earth (planet ground, ice, sand,
 *   wood: RUST_RESISTANCE_ORGANIC) answers to neither tier, and an already
 *   rusted turf is refused rather than scraped away, so the grasp cannot
 *   demolish a wall the way an unguarded second rust_turf() would.
 */
/datum/action/cooldown/spell/touch/vestige_rusted_grasp
	name = "Rusted Grasp"
	desc = "Touch something to rust it. Drains people, cuts airlock power for a while, and corrodes machines, structures and iron walls."
	button_icon = 'icons/mob/actions/actions_ecult.dmi'
	button_icon_state = "mansus_grasp"
	background_icon_state = "bg_heretic"
	overlay_icon_state = "bg_heretic_border"
	sound = 'sound/items/tools/welder.ogg'
	school = SCHOOL_FORBIDDEN
	cooldown_time = 45 SECONDS
	invocation_type = INVOCATION_NONE
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC
	antimagic_flags = MAGIC_RESISTANCE | MAGIC_RESISTANCE_HOLY
	hand_path = /obj/item/melee/touch_attack/vestige_rust
	/// Strength passed to rust_heretic_act: 2 reads basic and reinforced iron, 3 (the second reading) reads titanium hulls
	var/rust_strength = 2
	/// Stamina sapped from living victims
	var/stamina_sap = 50
	/// Brute dealt to machines and structures
	var/corrosion_damage = 150
	/// Knockdown applied to living victims: 0 until the second reading
	var/knockdown_time = 0

/**
 * The second reading: mastery, not arithmetic. The loop tightens, the rust
 * learns titanium, and the living buckle for a moment, still well short of
 * the antag grasp's 5-second drop.
 */
/datum/action/cooldown/spell/touch/vestige_rusted_grasp/second_reading
	name = "Second Reading"
	desc = "Touch something to rust it. Drains and briefly knocks down people, cuts airlock power for a while, wrecks machines outright, and rusts titanium hull plating too."
	button_icon_state = "corrode"
	cooldown_time = 30 SECONDS
	rust_strength = 3
	stamina_sap = 70
	corrosion_damage = 250
	knockdown_time = 1.5 SECONDS

/datum/action/cooldown/spell/touch/vestige_rusted_grasp/is_valid_target(atom/cast_on)
	return TRUE // sorting out what the rust can and cannot read happens on hit

/datum/action/cooldown/spell/touch/vestige_rusted_grasp/on_antimagic_triggered(obj/item/melee/touch_attack/hand, atom/victim, mob/living/carbon/caster)
	victim.visible_message(
		span_danger("The rust recoils from [victim] and crumbles away!"),
		span_danger("The rust recoils from you and crumbles away!"),
	)

/datum/action/cooldown/spell/touch/vestige_rusted_grasp/cast_on_hand_hit(obj/item/melee/touch_attack/hand, atom/victim, mob/living/carbon/caster)
	if(isliving(victim))
		return grasp_living(victim, caster)
	if(istype(victim, /obj/machinery/door/airlock))
		return grasp_airlock(victim, caster)
	if(isturf(victim))
		return grasp_turf(victim, caster)
	if(ismachinery(victim) || isstructure(victim))
		return grasp_object(victim, caster)
	caster.balloon_alert(caster, "nothing to rust!")
	return FALSE // no confession in it, keep the hand

/// The living confess in stamina: a sap, a rusted tongue, and (once upgraded) buckled knees
/datum/action/cooldown/spell/touch/vestige_rusted_grasp/proc/grasp_living(mob/living/victim, mob/living/carbon/caster)
	victim.apply_damage(stamina_sap, STAMINA)
	victim.adjust_timed_status_effect(4 SECONDS, /datum/status_effect/speech/slurring/heretic)
	if(knockdown_time)
		victim.Knockdown(knockdown_time)
	victim.visible_message(
		span_danger("[caster]'s rusted hand closes on [victim], and the strength runs out of [victim.p_them()] like filings!"),
		span_userdanger("A rusted grip closes on you, and your strength runs out like filings!"),
	)
	playsound(victim, 'sound/effects/magic/curse.ogg', 40, TRUE)
	return TRUE

/// Doors confess their wiring: loseMainPower cuts the lock for ~a minute, prying allowed meanwhile
/datum/action/cooldown/spell/touch/vestige_rusted_grasp/proc/grasp_airlock(obj/machinery/door/airlock/lock, mob/living/carbon/caster)
	lock.loseMainPower()
	do_sparks(3, FALSE, lock)
	lock.visible_message(span_danger("Rust crawls into the seams of [lock], and its lights gutter out!"))
	lock.balloon_alert(caster, "the lock loses power")
	playsound(lock, 'sound/items/tools/welder.ogg', 50, TRUE)
	return TRUE

/// Surfaces confess to having been earth: the same aimed single-turf rust act as the trial chrism
/datum/action/cooldown/spell/touch/vestige_rusted_grasp/proc/grasp_turf(turf/surface, mob/living/carbon/caster)
	if(HAS_TRAIT(surface, TRAIT_RUSTY))
		caster.balloon_alert(caster, "already rusted!")
		return FALSE
	surface.rust_heretic_act(rust_strength)
	// Anything that was never iron, planet ground, ice, wood, space itself.
	// Refuses the reading. Keep the hand rather than waste it, and say why
	if(!HAS_TRAIT(surface, TRAIT_RUSTY))
		caster.balloon_alert(caster, "it won't take!")
		to_chat(caster, span_warning("[surface] does not answer. Whatever it is made of was never iron."))
		return FALSE
	surface.visible_message(span_danger("Rust spreads out from [caster]'s palm across [surface]."))
	playsound(surface, 'sound/effects/magic/curse.ogg', 25, TRUE)
	return TRUE

/**
 * Machines and structures confess in filings. The rust element goes on first
 * and the damage second: a damaged machine looks exactly like an undamaged one
 * until the moment it breaks, so without the overlay the whole confession was
 * invisible to the person making it. Messaging happens before the damage too,
 * since a machine at the second reading's numbers may not survive the sentence.
 */
/datum/action/cooldown/spell/touch/vestige_rusted_grasp/proc/grasp_object(obj/target, mob/living/carbon/caster)
	target.visible_message(span_danger("[target] corrodes under [caster]'s rusted grip!"))
	playsound(target, 'sound/items/tools/welder.ogg', 50, TRUE)
	do_sparks(2, FALSE, target)
	if(!HAS_TRAIT(target, TRAIT_RUSTY))
		target.AddElement(/datum/element/rust)
	// No damage flag: armour plating soaked a third to a half of this, and rust
	// is not the kind of thing plating is for
	target.take_damage(corrosion_damage, BRUTE, NONE, TRUE)
	return TRUE

/obj/item/melee/touch_attack/vestige_rust
	name = "rusted grasp"
	desc = "A hand the colour of old blood and older iron. Whatever it touches next is going to rust."
	icon_state = "mansus"
	inhand_icon_state = "mansus"
	color = "#c46a33" // the chrism's oxide, moved into the palm

/**
 * Rust Formation, re-covenanted. The upstream spell is requirement-free
 * (spell_requirements = NONE, no IS_HERETIC anywhere in the raise-a-wall
 * path), but its cast-at-a-wall branch routes through do_rust_heretic_act,
 * which resolves a null rust_strength for anyone without a heretic datum and
 * silently does nothing. This subtype refuses closed turfs up front so every
 * cast takes the branch that actually works for a plain crewman, adds the
 * standard antimagic hooks, and slows the heretic's 8-second loop down to
 * something a whole crew can be trusted with.
 */
/datum/action/cooldown/spell/pointed/rust_construction/vestige
	name = "Iron Refusal"
	desc = "Raise a floor tile into a wall of rusted iron. Anyone standing on it is shoved aside."
	background_icon_state = "bg_heretic"
	overlay_icon_state = "bg_heretic_border"
	cooldown_time = 20 SECONDS
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC
	antimagic_flags = MAGIC_RESISTANCE | MAGIC_RESISTANCE_HOLY

/**
 * The parent gates on TRAIT_RUSTY: a heretic rusts the ground first and raises
 * it second, because rusting the ground is free for them. Here the rust is a
 * whole separate boon on its own cooldown, so the gate meant "this boon does
 * nothing unless you also took that one". The wall the spell raises is rusted
 * regardless (the parent's cast rusts it as it goes up), which is the part that
 * ever mattered. Closed turfs are still refused up front, the parent would
 * crumble them through the heretic-only do_rust_heretic_act path, which
 * silently does nothing for a plain crewman.
 */
/datum/action/cooldown/spell/pointed/rust_construction/vestige/is_valid_target(atom/cast_on)
	if(!isturf(cast_on))
		if(owner)
			cast_on.balloon_alert(owner, "not a wall or floor!")
		return FALSE
	if(isclosedturf(cast_on))
		if(owner)
			cast_on.balloon_alert(owner, "already standing!")
		return FALSE
	return TRUE

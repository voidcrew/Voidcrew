/**
 * # Prison contraband: stashes and shakedowns
 *
 * Owner: XF (extras-plan.md 4.14). Sour prisoners sharpen a shiv and hide it under their
 * mattress, or brew pruno in their toilet's cistern, out of sight of staff. A stash stays with the
 * cell. A shiv stash makes the yard tenser and its owner quicker to riot, and is the shiv they
 * draw when they do (decision 8 unchanged: every rioter still has a shiv, and shivs only come out
 * in riots). Pruno cheers the drinker and makes them quarrelsome for a while. Members search a
 * cell's mattress by hand (a right click), its toilet cistern by hand once the lid is off (tg's
 * crowbar, then a click), or pat a prisoner down from the talk menu ("Search"); searching costs the
 * yard's goodwill either way. Numbers in voidcrew/_DEFINES/outpost_prison_contraband.dm.
 *
 * Every stash is made where someone could have seen it: only while the prisoner's AI runs (someone
 * is on the level), with an emote and a sound, and it stops as soon as staff come into view. A shiv
 * stash is a record on the cell, never an item, until it is found or drawn. Pruno is tg's own bag
 * in tg's own cistern (code/game/objects/structures/water_structures/toilet.dm), fermenting on
 * tg's own timer. Razor blades and yeast from the mail (outpost_prison_mail.dm) are carried
 * hidden until the prisoner can stash them.
 *
 * The cells' beds and toilets are hooked lazily from the contraband clock, so a rebuilt bed or
 * toilet works too.
 */

// What an activity's tick() wants next, as in outpost_prison_routine.dm (which undefines its own)
#define ACTIVITY_CONTINUE 0
#define ACTIVITY_DONE 1
/// The talk menu's pat-down choice
#define CONTRABAND_PATDOWN_CHOICE "Search"
/// The prison's own pruno bag
#define CONTRABAND_PRUNO_TYPE /obj/item/reagent_containers/cup/glass/bottle/pruno/outpost_prison

// ===== STATE =====

/datum/outpost_prison_cell
	/// A shiv hidden under the mattress: a record only; no shiv exists until it is found or drawn
	var/stash_shiv = FALSE
	/// The bag of pruno brewing or brewed in this cell's toilet cistern
	var/datum/weakref/stash_pruno_ref
	/// world.time a search of this cell last cost its owner mood
	var/searched_at = 0

/mob/living/basic/outpost_prisoner
	/// Seconds their mood has stayed low enough to make a shiv, and to brew pruno
	var/contraband_shiv_sour = 0
	var/contraband_brew_sour = 0
	/// A razor blade or yeast from the mail, hidden in their contents until they stash it
	var/obj/item/carried_contraband
	/// Seconds of being drunk on pruno left, and to their next sway
	var/contraband_drunk_left = 0
	var/contraband_sway_left = 0
	/// world.time a pat-down last cost them mood
	var/contraband_patted_at = 0

/datum/outpost_prison
	/// Seconds since the last look for new stashes and at the cells' beds and toilets
	var/contraband_clock = 0
	/// REF() of each bed and toilet the prison listens to -> its weakref
	var/list/contraband_hooked = list()
	/// Tests only: TRUE or FALSE decides every contraband and mail roll; null rolls the dice
	var/contraband_force_rolls = null

// ===== THE PRISONER'S SIDE =====

/// Hooks up the prisoner's side of contraband and mail (the letter hand-over); called from setup_extras()
/mob/living/basic/outpost_prisoner/proc/setup_contraband()
	// An element, since the prisoner's own handler for item use already takes the signal (outpost_prison_mail.dm)
	AddElement(/datum/element/outpost_prison_mail_handover)

/// The sour clocks, the drink wearing off and the drunk's sway
/mob/living/basic/outpost_prisoner/proc/contraband_counters(seconds)
	// Each sour clock counts while mood is under its line, holds just above it, and resets once they cheer up
	if(mood >= OUTPOST_CONTRABAND_SOUR_RESET)
		contraband_shiv_sour = 0
	else if(mood < OUTPOST_CONTRABAND_SHIV_MOOD)
		contraband_shiv_sour += seconds
	if(mood >= OUTPOST_CONTRABAND_BREW_RESET)
		contraband_brew_sour = 0
	else if(mood < OUTPOST_CONTRABAND_BREW_MOOD)
		contraband_brew_sour += seconds
	if(contraband_drunk_left <= 0)
		return
	contraband_drunk_left = max(0, contraband_drunk_left - seconds)
	contraband_sway_left -= seconds
	if(contraband_sway_left > 0 || contraband_drunk_left <= 0)
		return
	contraband_sway_left = rand(OUTPOST_CONTRABAND_SWAY_MIN, OUTPOST_CONTRABAND_SWAY_MAX)
	if(stat == CONSCIOUS && isturf(loc) && !buckled)
		Shake(1, 0, 0.5 SECONDS)

/mob/living/basic/outpost_prisoner/proc/contraband_drunk()
	return contraband_drunk_left > 0

/// Whether they have been sour long enough to make a shiv, and their cell has none
/mob/living/basic/outpost_prisoner/proc/contraband_can_make_shiv()
	return cell && !cell.stash_shiv && contraband_shiv_sour >= OUTPOST_CONTRABAND_SOUR_TIME

/// Whether they have been grumbling long enough to brew, and their cell's cistern has no pruno
/mob/living/basic/outpost_prisoner/proc/contraband_can_brew()
	return cell && contraband_brew_sour >= OUTPOST_CONTRABAND_BREW_SOUR_TIME && !prison?.contraband_pruno(cell)

/// Hides `thing` (a razor blade or yeast from the mail) on them until they can stash it. FALSE if they already carry something.
/mob/living/basic/outpost_prisoner/proc/contraband_carry(obj/item/thing)
	if(QDELETED(thing) || carried_contraband)
		return FALSE
	thing.forceMove(src)
	if(thing.loc != src)
		return FALSE
	carried_contraband = thing
	RegisterSignals(thing, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING), PROC_REF(on_carried_contraband_moved))
	return TRUE

/// Forgets what they carried, leaving the item wherever it is
/mob/living/basic/outpost_prisoner/proc/contraband_clear_carried()
	if(carried_contraband)
		UnregisterSignal(carried_contraband, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
	carried_contraband = null

/mob/living/basic/outpost_prisoner/proc/on_carried_contraband_moved(obj/item/source)
	SIGNAL_HANDLER
	if(source != carried_contraband)
		UnregisterSignal(source, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
		return
	if(QDELETED(source) || source.loc != src)
		contraband_clear_carried()

/// A new arrival finds what the last occupant left and says so, if it is still there
/mob/living/basic/outpost_prisoner/proc/contraband_remark_inherited()
	if(stat != CONSCIOUS || phase != PRISONER_PRESENT || !cell || in_trouble())
		return FALSE
	if(!cell.stash_shiv && !prison?.contraband_pruno(cell))
		return FALSE
	return say_context("contraband_inherit")

// ===== THE CLOCK =====

/// A roll for contraband or mail: prob(chance), unless a test decides it
/datum/outpost_prison/proc/contraband_roll(chance)
	return isnull(contraband_force_rolls) ? prob(chance) : contraband_force_rolls

/// Sour clocks, shiv making, brewing and drinking, and the cells' beds and toilets
/datum/outpost_prison/proc/contraband_tick(seconds)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase != PRISONER_PRESENT || prisoner.stat == DEAD)
			continue
		prisoner.contraband_counters(seconds)
		// Mail contraband goes into hiding once they are home and unwatched
		if(prisoner.carried_contraband && prisoner.ai_running())
			contraband_try_stash_carried(prisoner)
	contraband_clock += seconds
	if(contraband_clock < OUTPOST_CONTRABAND_CLOCK)
		return
	contraband_clock = 0
	contraband_hook_fixtures()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase != PRISONER_PRESENT || prisoner.stat != CONSCIOUS)
			continue
		// Nobody on the level: whatever came in the mail is stashed wherever they are, unless they are cuffed
		if(prisoner.carried_contraband && !prisoner.ai_running())
			if(!prisoner.cuffs)
				contraband_stash_carried(prisoner)
			continue
		contraband_try_start(prisoner)

/**
 * The rolls for a sour prisoner to start on a stash: a shiv, else pruno. Only while their AI runs,
 * they are free, nothing more pressing has them busy and no staff are in sight. Returns the
 * activity started, or null.
 */
/datum/outpost_prison/proc/contraband_try_start(mob/living/basic/outpost_prisoner/prisoner)
	if(!prisoner.ai_running() || !prisoner.routine_allowed() || !prisoner.cell)
		return null
	var/datum/prisoner_activity/current = prisoner.activity
	if(current && (!current.leisure || current.sleeping || !current.interruptible))
		return null
	var/per_clock = OUTPOST_CONTRABAND_CLOCK / 60
	var/activity_type
	if(prisoner.contraband_can_make_shiv() && contraband_roll(OUTPOST_CONTRABAND_SHIV_CHANCE * per_clock))
		activity_type = /datum/prisoner_activity/make_shiv
	else if(prisoner.contraband_can_brew() && contraband_roll(OUTPOST_CONTRABAND_BREW_CHANCE * per_clock))
		activity_type = /datum/prisoner_activity/brew
	if(!activity_type || contraband_watcher(prisoner))
		return null
	var/datum/prisoner_activity/stash = new activity_type(prisoner)
	if(!stash.setup())
		qdel(stash)
		return null
	prisoner.start_activity(stash)
	return stash

/// Staff (on-duty guards included) who can see `prisoner`, or null
/datum/outpost_prison/proc/contraband_watcher(mob/living/basic/outpost_prisoner/prisoner)
	for(var/mob/living/person in view(OUTPOST_CONTRABAND_WATCH_RANGE, prisoner))
		if(is_outpost_prison_staff(person))
			return person
	return null

/// Caught at it: they stop, deny it, and have to sour all over again before the next try
/datum/outpost_prison/proc/contraband_caught(mob/living/basic/outpost_prisoner/prisoner, mob/living/watcher, shiv = TRUE)
	if(shiv)
		prisoner.contraband_shiv_sour = 0
	else
		prisoner.contraband_brew_sour = 0
	prisoner.stand_up()
	if(watcher)
		prisoner.face_atom(watcher)
	prisoner.say_context("contraband_hide")

// ===== STASHES =====

/// The toilet inside `cell`, if it has one
/datum/outpost_prison/proc/contraband_cistern(datum/outpost_prison_cell/cell)
	for(var/turf/tile as anything in cell?.turfs)
		var/obj/structure/toilet/toilet = locate() in tile
		if(toilet && !QDELETED(toilet))
			return toilet
	return null

/// Whether tg's cistern takes one more item of `weight` (toilet.dm's own limits)
/datum/outpost_prison/proc/contraband_cistern_room(obj/structure/toilet/toilet, weight)
	return toilet && weight <= WEIGHT_CLASS_NORMAL && toilet.w_items + weight <= WEIGHT_CLASS_HUGE

/// The weight of the prison's pruno bag
/proc/outpost_prison_pruno_weight()
	var/obj/item/bag_type = CONTRABAND_PRUNO_TYPE
	return initial(bag_type.w_class)

/// The cell's pruno, while it is still in a cistern inside the cell; forgets a bag that has gone
/datum/outpost_prison/proc/contraband_pruno(datum/outpost_prison_cell/cell)
	var/obj/item/reagent_containers/cup/glass/bottle/pruno/bag = cell?.stash_pruno_ref?.resolve()
	if(!bag || QDELETED(bag) || !istype(bag.loc, /obj/structure/toilet) || !cell.contains(bag.loc))
		if(cell)
			cell.stash_pruno_ref = null
		return null
	return bag

/// Whether a bag of pruno has fermented
/proc/outpost_prison_pruno_ready(obj/item/reagent_containers/cup/glass/bottle/pruno/bag)
	return !!bag?.reagents?.has_reagent(/datum/reagent/consumable/ethanol/pruno)

/**
 * Puts a new bag of pruno mix in `toilet`'s cistern as `cell`'s stash, the way tg's cistern takes
 * an item (contents, cistern_items and w_items). Moving it into the toilet starts tg's own
 * fermentation timer. Returns the bag, or null.
 */
/datum/outpost_prison/proc/contraband_brew_into(datum/outpost_prison_cell/cell, obj/structure/toilet/toilet)
	if(!cell || QDELETED(toilet) || contraband_pruno(cell) || !contraband_cistern_room(toilet, outpost_prison_pruno_weight()))
		return null
	var/obj/item/reagent_containers/cup/glass/bottle/pruno/outpost_prison/bag = new(null)
	bag.forceMove(toilet)
	LAZYADD(toilet.cistern_items, bag)
	toilet.w_items += bag.w_class
	cell.stash_pruno_ref = WEAKREF(bag)
	contraband_hook_toilet(toilet)
	return bag

/// Takes the cell's pruno out of its cistern and deletes it (drunk, or cleared by an admin). Returns TRUE if there was one.
/datum/outpost_prison/proc/contraband_spill_pruno(datum/outpost_prison_cell/cell)
	var/obj/item/reagent_containers/cup/glass/bottle/pruno/bag = contraband_pruno(cell)
	// Forgotten first, so the cistern watch does not count it as found
	cell.stash_pruno_ref = null
	if(!bag)
		return FALSE
	var/obj/structure/toilet/toilet = bag.loc
	if(istype(toilet))
		// tg only takes the weight off when someone pulls an item out by hand
		toilet.w_items = max(0, toilet.w_items - bag.w_class)
	qdel(bag)
	return TRUE

/// A prisoner drinks the pruno in their cell's cistern: a lift, then a while drunk. Returns TRUE if they drank.
/datum/outpost_prison/proc/contraband_drink(mob/living/basic/outpost_prisoner/prisoner)
	var/obj/item/reagent_containers/cup/glass/bottle/pruno/bag = contraband_pruno(prisoner?.cell)
	if(!outpost_prison_pruno_ready(bag))
		return FALSE
	contraband_spill_pruno(prisoner.cell)
	prisoner.manual_emote("takes a long pull from a bag of something.")
	playsound(prisoner, 'sound/items/drink.ogg', 30, TRUE)
	prisoner.adjust_mood(OUTPOST_CONTRABAND_PRUNO_MOOD)
	prisoner.contraband_drunk_left = OUTPOST_CONTRABAND_DRUNK_TIME
	prisoner.contraband_sway_left = rand(OUTPOST_CONTRABAND_SWAY_MIN, OUTPOST_CONTRABAND_SWAY_MAX)
	return TRUE

/// Home and unwatched, with the AI running: whatever came in the mail goes into hiding
/datum/outpost_prison/proc/contraband_try_stash_carried(mob/living/basic/outpost_prisoner/prisoner)
	if(!prisoner.cell?.contains(prisoner) || !prisoner.routine_allowed() || contraband_watcher(prisoner))
		return FALSE
	return contraband_stash_carried(prisoner)

/**
 * Stashes what they carry: a razor blade becomes a shiv under the mattress, yeast a bag of pruno in
 * the cistern. A cell that already has that stash, or no room for it, leaves them carrying it.
 * Returns TRUE if it was stashed.
 */
/datum/outpost_prison/proc/contraband_stash_carried(mob/living/basic/outpost_prisoner/prisoner)
	var/obj/item/thing = prisoner.carried_contraband
	var/datum/outpost_prison_cell/home = prisoner.cell
	if(!thing || thing.loc != prisoner || !home)
		return FALSE
	if(istype(thing, /obj/item/outpost_prison_contraband/razor_blade))
		if(home.stash_shiv)
			return FALSE
		prisoner.contraband_clear_carried()
		qdel(thing)
		home.stash_shiv = TRUE
		if(prisoner.ai_running())
			prisoner.manual_emote("tucks something under the mattress.")
		return TRUE
	if(istype(thing, /obj/item/outpost_prison_contraband/yeast))
		if(!contraband_brew_into(home, contraband_cistern(home)))
			return FALSE
		prisoner.contraband_clear_carried()
		qdel(thing)
		if(prisoner.ai_running())
			prisoner.manual_emote("fiddles with the toilet tank.")
		return TRUE
	return FALSE

// ===== THE BEDS AND TOILETS =====

/// Listens to every bed (right click: the mattress search) and toilet (a click with the lid off: the cistern search; the cistern itself) inside the cells
/datum/outpost_prison/proc/contraband_hook_fixtures()
	for(var/key in contraband_hooked.Copy())
		var/datum/weakref/known = contraband_hooked[key]
		if(!known?.resolve())
			contraband_hooked -= key
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		for(var/turf/tile as anything in cell.turfs)
			for(var/obj/structure/bed/bed in tile)
				contraband_hook(bed, list((COMSIG_ATOM_ATTACK_HAND_SECONDARY) = PROC_REF(contraband_on_bed_click)))
			for(var/obj/structure/toilet/toilet in tile)
				contraband_hook_toilet(toilet)

/// Registers each signal -> proc of `signal_procs` on `thing`, once for all of them. Returns TRUE if it was new.
/datum/outpost_prison/proc/contraband_hook(obj/thing, list/signal_procs)
	if(QDELETED(thing))
		return FALSE
	var/key = REF(thing)
	var/datum/weakref/known = contraband_hooked[key]
	if(known?.resolve() == thing)
		return FALSE
	contraband_hooked[key] = WEAKREF(thing)
	for(var/signal in signal_procs)
		RegisterSignal(thing, signal, signal_procs[signal], override = TRUE)
	return TRUE

/// A cell toilet's hooks: the hand search, and the watch on its cistern for the pruno leaving it
/datum/outpost_prison/proc/contraband_hook_toilet(obj/structure/toilet/toilet)
	if(QDELETED(toilet))
		return FALSE
	// A structure's hand click ends in interact(), which overwrites a signal's cancel and does nothing
	// for a toilet. Without it, tg's attack_hand() stops when the search takes the click, and does
	// everything else as before.
	toilet.interaction_flags_atom &= ~INTERACT_ATOM_ATTACK_HAND
	return contraband_hook(toilet, list(
		(COMSIG_ATOM_ATTACK_HAND) = PROC_REF(contraband_on_toilet_click),
		(COMSIG_ATOM_EXITED) = PROC_REF(contraband_on_cistern_exited),
	))

/// A right click with an empty hand on a bed inside a cell: members search the mattress
/datum/outpost_prison/proc/contraband_on_bed_click(obj/structure/bed/source, mob/user, list/modifiers)
	SIGNAL_HANDLER
	if(!isliving(user) || is_outpost_prisoner(user) || !cell_at(get_turf(source)))
		return NONE
	if(!is_member(user))
		source.balloon_alert(user, "members only")
		return COMPONENT_CANCEL_ATTACK_CHAIN
	if(source.has_buckled_mobs())
		// A prisoner lying on it can be told to get up from the talk menu, or shaken awake; the balloon only says who is in the way.
		var/mob/living/basic/outpost_prisoner/lying = locate() in source.buckled_mobs
		source.balloon_alert(user, lying?.activity?.sleeping ? "someone's asleep on it" : "someone's lying on it")
		return COMPONENT_CANCEL_ATTACK_CHAIN
	INVOKE_ASYNC(src, PROC_REF(contraband_search_mattress), user, source)
	return COMPONENT_CANCEL_ATTACK_CHAIN

/**
 * A member searches a cell's mattress for OUTPOST_CONTRABAND_SEARCH_TIME. Returns "found", "empty",
 * or null when nothing was searched. Sleeps.
 */
/datum/outpost_prison/proc/contraband_search_mattress(mob/living/user, obj/structure/bed/bed)
	if(QDELETED(user) || QDELETED(bed) || !is_member(user) || DOING_INTERACTION_WITH_TARGET(user, bed))
		return null
	var/datum/outpost_prison_cell/cell = cell_at(get_turf(bed))
	if(!cell || bed.has_buckled_mobs())
		return null
	user.visible_message(span_notice("[user] turns over the mattress on [bed] and searches it."), span_notice("You search the mattress."))
	playsound(bed, SFX_RUSTLE, 40, TRUE)
	if(!do_after(user, OUTPOST_CONTRABAND_SEARCH_TIME, target = bed))
		return null
	if(QDELETED(src) || QDELETED(bed) || QDELETED(user) || cell_at(get_turf(bed)) != cell)
		return null
	var/mob/living/basic/outpost_prisoner/owner = cell.occupant
	if(cell.stash_shiv)
		cell.stash_shiv = FALSE
		var/obj/item/knife/shiv/shiv = new(get_turf(user))
		user.put_in_hands(shiv)
		to_chat(user, span_notice("There's a shiv under the mattress."))
		add_log("[user.name] found a shiv in cell [cell.number].")
		contraband_owner_caught(owner, user, cell)
		return "found"
	to_chat(user, span_notice("There's nothing under the mattress."))
	contraband_search_came_up_empty(owner, user, cell)
	return "empty"

/**
 * An empty-hand click on a toilet inside a cell with its cistern lid off (tg's crowbar step): members
 * search the cistern, in place of tg's grab of one item, and visitors are refused, so nobody gets
 * round the search's rules. With the lid on, or a swirlie going, the click is tg's own; so is the
 * right click, the flush.
 */
/datum/outpost_prison/proc/contraband_on_toilet_click(obj/structure/toilet/source, mob/user, list/modifiers)
	SIGNAL_HANDLER
	if(!source.cistern_open || LAZYACCESS(modifiers, RIGHT_CLICK) || !isliving(user) || is_outpost_prisoner(user) || !cell_at(get_turf(source)))
		return NONE
	if(source.swirlie || isliving(user.pulling))
		return NONE
	if(!is_member(user))
		source.balloon_alert(user, "members only")
		return COMPONENT_CANCEL_ATTACK_CHAIN
	if(source.has_buckled_mobs())
		source.balloon_alert(user, "someone's sitting on it")
		return COMPONENT_CANCEL_ATTACK_CHAIN
	INVOKE_ASYNC(src, PROC_REF(contraband_search_cistern), user, source)
	return COMPONENT_CANCEL_ATTACK_CHAIN

/**
 * A member searches a cell toilet's cistern, its lid off, for OUTPOST_CONTRABAND_SEARCH_TIME, and
 * takes out everything in it. Prison contraband (the cell's pruno, a shiv, a razor blade or yeast)
 * is a find, as under the mattress; anything else is handed over, but the search counts as empty.
 * Returns "found", "empty", or null when nothing was searched. Sleeps.
 */
/datum/outpost_prison/proc/contraband_search_cistern(mob/living/user, obj/structure/toilet/toilet)
	if(QDELETED(user) || QDELETED(toilet) || !is_member(user) || DOING_INTERACTION_WITH_TARGET(user, toilet))
		return null
	var/datum/outpost_prison_cell/cell = cell_at(get_turf(toilet))
	if(!cell || !toilet.cistern_open || toilet.has_buckled_mobs())
		return null
	user.visible_message(span_notice("[user] feels around inside the cistern of [toilet]."), span_notice("You search the cistern."))
	playsound(toilet, SFX_RUSTLE, 40, TRUE)
	if(!do_after(user, OUTPOST_CONTRABAND_SEARCH_TIME, target = toilet))
		return null
	if(QDELETED(src) || QDELETED(toilet) || QDELETED(user) || cell_at(get_turf(toilet)) != cell || !toilet.cistern_open || toilet.has_buckled_mobs())
		return null
	var/obj/item/pruno = contraband_pruno(cell)
	// Forgotten first, so the cistern watch does not count the pruno a second time
	cell.stash_pruno_ref = null
	var/list/found = list()
	var/caught = FALSE
	for(var/obj/item/hidden in LAZYCOPY(toilet.cistern_items))
		if(hidden == pruno || outpost_prison_is_contraband(hidden))
			caught = TRUE
		// tg only takes the weight off when someone pulls an item out by hand
		toilet.w_items = max(0, toilet.w_items - hidden.w_class)
		hidden.forceMove(get_turf(user))
		user.put_in_hands(hidden)
		found += hidden.name
	if(!length(found))
		to_chat(user, span_notice("There's nothing in the cistern."))
	else
		to_chat(user, span_notice("You find [english_list(found)] in the cistern."))
	var/mob/living/basic/outpost_prisoner/owner = cell.occupant
	if(!caught)
		contraband_search_came_up_empty(owner, user, cell)
		return "empty"
	add_log("[user.name] found [english_list(found)] in the cistern of cell [cell.number].")
	contraband_owner_caught(owner, user, cell)
	return "found"

/// Whether `thing` is prison contraband: pruno, a shiv, or a razor blade or yeast from the mail
/proc/outpost_prison_is_contraband(obj/item/thing)
	return istype(thing, /obj/item/reagent_containers/cup/glass/bottle/pruno) || istype(thing, /obj/item/knife/shiv) || istype(thing, /obj/item/outpost_prison_contraband)

/// Whether a search of `cell` costs mood now: once per OUTPOST_CONTRABAND_SEARCH_GAP. Starts the gap when it does.
/datum/outpost_prison/proc/contraband_search_costs(datum/outpost_prison_cell/cell)
	if(cell.searched_at && world.time - cell.searched_at < OUTPOST_CONTRABAND_SEARCH_GAP)
		return FALSE
	cell.searched_at = world.time
	return TRUE

/// Whether a cell's owner is there to take it: present, awake and not loose
/datum/outpost_prison/proc/contraband_owner_home(mob/living/basic/outpost_prisoner/owner)
	return !QDELETED(owner) && (owner in prisoners) && owner.stat == CONSCIOUS && owner.phase == PRISONER_PRESENT && owner.trouble != PRISONER_TROUBLE_LOOSE

/// Something was found in `owner`'s cell by `finder`: they deny it and lose a little mood
/datum/outpost_prison/proc/contraband_owner_caught(mob/living/basic/outpost_prisoner/owner, mob/living/finder, datum/outpost_prison_cell/cell)
	if(!contraband_owner_home(owner))
		return FALSE
	if(contraband_search_costs(cell))
		owner.adjust_mood(-OUTPOST_CONTRABAND_FOUND_MOOD)
	if(finder in view(OUTPOST_CONTRABAND_WATCH_RANGE, owner))
		owner.face_atom(finder)
		owner.say_context("shakedown_found")
	note_staff_event(finder, owner, "search_found")
	return TRUE

/// A search of `owner`'s cell found nothing: the owner and anyone watching take it badly. An empty cell costs nothing.
/datum/outpost_prison/proc/contraband_search_came_up_empty(mob/living/basic/outpost_prisoner/owner, mob/living/searcher, datum/outpost_prison_cell/cell)
	if(!contraband_owner_home(owner))
		return FALSE
	if(contraband_search_costs(cell))
		owner.adjust_mood(-OUTPOST_CONTRABAND_EMPTY_MOOD)
		for(var/mob/living/basic/outpost_prisoner/onlooker in view(OUTPOST_CONTRABAND_WATCH_RANGE, searcher))
			if(onlooker == owner || !(onlooker in prisoners) || onlooker.stat != CONSCIOUS || onlooker.phase != PRISONER_PRESENT)
				continue
			onlooker.adjust_mood(-OUTPOST_CONTRABAND_ONLOOKER_MOOD)
	if(searcher in view(OUTPOST_CONTRABAND_WATCH_RANGE, owner))
		owner.face_atom(searcher)
		owner.say_context("shakedown_empty")
	note_staff_event(searcher, owner, "search_empty")
	return TRUE

/// Something left a cell's toilet. The cell's pruno leaving it for someone's hands is a find.
/datum/outpost_prison/proc/contraband_on_cistern_exited(obj/structure/toilet/source, atom/movable/gone, direction)
	SIGNAL_HANDLER
	var/datum/outpost_prison_cell/cell = cell_at(get_turf(source))
	if(!cell || !gone || cell.stash_pruno_ref?.resolve() != gone)
		return
	cell.stash_pruno_ref = null
	var/mob/living/finder = gone.loc
	if(!istype(finder) || is_outpost_prisoner(finder))
		return
	INVOKE_ASYNC(src, PROC_REF(contraband_pruno_found), finder, cell)

/// `finder` pulled the cell's pruno out of the cistern
/datum/outpost_prison/proc/contraband_pruno_found(mob/living/finder, datum/outpost_prison_cell/cell)
	if(QDELETED(src) || QDELETED(cell) || QDELETED(finder))
		return
	add_log("[finder.name] found pruno in cell [cell.number].")
	contraband_owner_caught(cell.occupant, finder, cell)

// ===== THE PAT-DOWN =====

/// The pat-down choice for the talk menu: name -> image. Hands on the wall, or held still in cuffs.
/datum/outpost_prison/proc/contraband_talk_choices(mob/living/basic/outpost_prisoner/prisoner, mob/living/user)
	if(!prisoner || !user || !is_member(user))
		return list()
	return list((CONTRABAND_PATDOWN_CHOICE) = image(icon = 'voidcrew/icons/hud/radial.dmi', icon_state = "radial_search"))

/// Runs a talk menu choice of this package; TRUE if it was one. May sleep.
/datum/outpost_prison/proc/contraband_talk_act(mob/living/basic/outpost_prisoner/prisoner, mob/living/user, choice)
	if(choice != CONTRABAND_PATDOWN_CHOICE)
		return FALSE
	contraband_pat_down(prisoner, user)
	return TRUE

/**
 * "Search": a member pats a prisoner down for OUTPOST_CONTRABAND_SEARCH_TIME. It finds
 * what they carry from the mail; for nothing, they lose mood (once per OUTPOST_CONTRABAND_SEARCH_GAP)
 * and someone watching may speak up. Same gate as a talk, except that someone in cuffs has no say
 * in it: rioting, loose or sour, they hold still and are searched, unless someone is already
 * talking to them or working on their cuffs. Returns "found", "empty" or null. Sleeps.
 */
/datum/outpost_prison/proc/contraband_pat_down(mob/living/basic/outpost_prisoner/prisoner, mob/living/user)
	if(QDELETED(prisoner) || QDELETED(user) || !is_member(user) || !(prisoner in prisoners))
		return null
	if(prisoner.stat != CONSCIOUS || prisoner.phase != PRISONER_PRESENT)
		return null
	if(prisoner.cuffs)
		if(prisoner.talking || prisoner.cuff_work)
			prisoner.balloon_alert(user, "busy")
			return null
	else
		// Fighting, squaring up, climbing, lying beaten or already being talked to: not now
		if(prisoner.in_trouble())
			prisoner.balloon_alert(user, "busy")
			return null
		if(!prisoner.will_listen())
			prisoner.face_atom(user)
			prisoner.say_context("talk_refuse")
			prisoner.balloon_alert(user, "not listening")
			return null
	prisoner.talking = TRUE
	prisoner.end_activity()
	prisoner.stand_up()
	if(prisoner.cuffs)
		// Their hands are cuffed already; nothing for them to put on the wall
		prisoner.face_atom(user)
		prisoner.manual_emote("stands still to be searched.")
	else
		var/wall_dir
		for(var/direction in GLOB.cardinals)
			if(isclosedturf(get_step(prisoner, direction)))
				wall_dir = direction
				break
		if(wall_dir)
			prisoner.setDir(wall_dir)
			prisoner.manual_emote("puts [prisoner.p_their()] hands on the wall.")
		else
			prisoner.face_atom(user)
			prisoner.manual_emote("puts [prisoner.p_their()] hands up.")
	user.visible_message(span_notice("[user] pats [prisoner] down."), span_notice("You pat [prisoner] down."))
	var/finished = do_after(user, OUTPOST_CONTRABAND_SEARCH_TIME, target = prisoner)
	if(QDELETED(prisoner))
		return null
	prisoner.talking = FALSE
	if(!finished || QDELETED(user) || prisoner.stat != CONSCIOUS || prisoner.phase != PRISONER_PRESENT)
		return null
	prisoner.face_atom(user)
	var/obj/item/found = prisoner.carried_contraband
	if(found && found.loc == prisoner)
		prisoner.contraband_clear_carried()
		found.forceMove(get_turf(user))
		user.put_in_hands(found)
		to_chat(user, span_notice("You find [found] on [prisoner]."))
		add_log("[user.name] found [found.name] on [prisoner.real_name].")
		prisoner.say_context("patdown_found")
		note_staff_event(user, prisoner, "patdown_found")
		return "found"
	to_chat(user, span_notice("[prisoner.p_they(TRUE)] [prisoner.p_have()] nothing on [prisoner.p_them()]."))
	if(!prisoner.contraband_patted_at || world.time - prisoner.contraband_patted_at >= OUTPOST_CONTRABAND_SEARCH_GAP)
		prisoner.contraband_patted_at = world.time
		prisoner.adjust_mood(-OUTPOST_CONTRABAND_PATDOWN_MOOD)
	prisoner.say_context("patdown_empty")
	if(contraband_roll(OUTPOST_CONTRABAND_PATDOWN_ONLOOKER_CHANCE))
		var/list/onlookers = list()
		for(var/mob/living/basic/outpost_prisoner/onlooker in view(OUTPOST_CONTRABAND_ONLOOKER_RANGE, prisoner))
			if(onlooker != prisoner && (onlooker in prisoners) && onlooker.stat == CONSCIOUS && onlooker.phase == PRISONER_PRESENT && !onlooker.in_trouble())
				onlookers += onlooker
		if(length(onlookers))
			var/mob/living/basic/outpost_prisoner/speaker = pick(onlookers)
			speaker.face_atom(user)
			speaker.say_context("patdown_onlooker", prisoner)
	note_staff_event(user, prisoner, "patdown_empty")
	return "empty"

// ===== TROUBLE: TENSION, RIOTS, FIGHTS =====

/// Tension the wing's hidden shivs add: OUTPOST_CONTRABAND_SHIV_TENSION for each in an occupied cell, up to OUTPOST_CONTRABAND_TENSION_MAX
/datum/outpost_prison/proc/contraband_tension()
	var/total = 0
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(cell.stash_shiv && cell.occupant && counts_for_tension(cell.occupant))
			total += OUTPOST_CONTRABAND_SHIV_TENSION
	return min(total, OUTPOST_CONTRABAND_TENSION_MAX)

/// A few words for the restless log line when shivs are hidden in the wing, or null
/datum/outpost_prison/proc/contraband_cause()
	return contraband_tension() > 0 ? "word of a shiv" : null

/// How much higher `prisoner`'s riot line is (a shiv under their mattress, and some bounty prisoners: outpost_prison_bounty.dm)
/datum/outpost_prison/proc/riot_join_bonus(mob/living/basic/outpost_prisoner/prisoner)
	return (prisoner?.cell?.stash_shiv ? OUTPOST_CONTRABAND_RIOT_JOIN_BONUS : 0) + (prisoner ? prisoner.bounty_riot_bonus() : 0)

/**
 * A rioter draws the shiv from their cell's stash instead of a new one; TRUE if they did. Only
 * start_rioting() calls this: a stash never arms a threat or a fight (decision 8).
 */
/datum/outpost_prison/proc/draw_stashed_shiv(mob/living/basic/outpost_prisoner/prisoner)
	var/datum/outpost_prison_cell/home = prisoner?.cell
	if(!home?.stash_shiv || prisoner.has_shiv())
		return FALSE
	home.stash_shiv = FALSE
	prisoner.drop_held_item()
	var/obj/item/knife/shiv/shiv = new(prisoner)
	prisoner.held_item = shiv
	prisoner.update_melee()
	prisoner.update_appearance(UPDATE_OVERLAYS)
	prisoner.manual_emote("pulls out a shiv [prisoner.p_they()] had been saving.")
	return TRUE

/// Multiplier on the chance these two start a fight: either one drunk
/datum/outpost_prison/proc/contraband_fight_mult(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	if(one?.contraband_drunk() || two?.contraband_drunk())
		return OUTPOST_CONTRABAND_DRUNK_FIGHT_MULT
	return 1

/// Multiplier on the wing's chance of a spat: anyone drunk
/datum/outpost_prison/proc/contraband_spat_mult()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase == PRISONER_PRESENT && prisoner.stat == CONSCIOUS && prisoner.contraband_drunk())
			return OUTPOST_CONTRABAND_DRUNK_SPAT_MULT
	return 1

// ===== SPEECH AND EXAMINE =====

/// A drunk line `prisoner` wants to say now, as list(context, other), or null
/datum/outpost_prison/proc/contraband_extra_speech(mob/living/basic/outpost_prisoner/prisoner)
	if(prisoner?.contraband_drunk() && prob(50))
		return list("drunk", null)
	return null

/// The tells for examine: a hand kept in a pocket, a drunk's sway; or null
/datum/outpost_prison/proc/contraband_examine(mob/living/basic/outpost_prisoner/prisoner, mob/user)
	if(!prisoner || prisoner.stat == DEAD)
		return null
	var/list/tells = list()
	if(prisoner.carried_contraband)
		tells += "Keeps one hand in [prisoner.p_their()] pocket."
	if(prisoner.contraband_drunk())
		tells += "Sways a little, and smells of something sour and fruity."
	return length(tells) ? jointext(tells, " ") : null

// ===== COMINGS AND GOINGS =====

/datum/outpost_prison/proc/contraband_destroy()
	for(var/key in contraband_hooked)
		var/datum/weakref/known = contraband_hooked[key]
		var/obj/thing = known?.resolve()
		if(thing)
			UnregisterSignal(thing, list(COMSIG_ATOM_ATTACK_HAND, COMSIG_ATOM_ATTACK_HAND_SECONDARY, COMSIG_ATOM_EXITED))
	contraband_hooked.Cut()
	// Prisoners deleted with the prison never pass through forget()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		var/obj/item/thing = prisoner.carried_contraband
		prisoner.contraband_clear_carried()
		qdel(thing)

/// A new arrival: half the time they notice what the last occupant left, a little after they arrive
/datum/outpost_prison/proc/contraband_prisoner_admitted(mob/living/basic/outpost_prisoner/prisoner)
	var/datum/outpost_prison_cell/home = prisoner?.cell
	if(!home || (!home.stash_shiv && !contraband_pruno(home)))
		return
	if(!contraband_roll(OUTPOST_CONTRABAND_INHERIT_CHANCE))
		return
	addtimer(CALLBACK(prisoner, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, contraband_remark_inherited)), OUTPOST_CONTRABAND_INHERIT_DELAY)

/// A prisoner is leaving: what they carry goes with them. Their cell's stash stays for the next.
/datum/outpost_prison/proc/contraband_prisoner_leaving(mob/living/basic/outpost_prisoner/prisoner)
	var/obj/item/thing = prisoner.carried_contraband
	prisoner.contraband_clear_carried()
	qdel(thing)
	prisoner.contraband_drunk_left = 0

// ===== ADMIN =====

/// The admin panel's contraband block: {cells: [{number, shiv, pruno}], drunk: [ref], carrying: [ref]}
/datum/outpost_prison/proc/contraband_admin_payload()
	var/list/cell_rows = list()
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		var/obj/item/reagent_containers/cup/glass/bottle/pruno/bag = contraband_pruno(cell)
		cell_rows += list(list(
			"number" = cell.number,
			"shiv" = !!cell.stash_shiv,
			"pruno" = bag ? (outpost_prison_pruno_ready(bag) ? "ready" : "brewing") : "none",
		))
	var/list/drunk = list()
	var/list/carrying = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.contraband_drunk())
			drunk += REF(prisoner)
		if(prisoner.carried_contraband)
			carrying += REF(prisoner)
	return list("cells" = cell_rows, "drunk" = drunk, "carrying" = carrying)

/// prison_stash {cell, kind: shiv|pruno|clear}: a log line, list("error" = text), or null
/datum/outpost_prison/proc/contraband_admin_act(action, list/params, mob/user)
	if(action != "prison_stash")
		return null
	var/number = params?["cell"]
	if(istext(number))
		number = text2num(number)
	if(!isnum(number) || number != round(number))
		return list("error" = "Invalid cell.")
	var/datum/outpost_prison_cell/cell = cell_by_number(number)
	if(!cell)
		return list("error" = "There is no cell [number].")
	switch(params["kind"])
		if("shiv")
			if(cell.stash_shiv)
				return list("error" = "Cell [number] already has a shiv hidden.")
			cell.stash_shiv = TRUE
			return "hide a shiv under the mattress in prison cell [number]"
		if("pruno")
			if(contraband_pruno(cell))
				return list("error" = "Cell [number] already has pruno in its cistern.")
			var/obj/structure/toilet/toilet = contraband_cistern(cell)
			if(!toilet)
				return list("error" = "Cell [number] has no toilet.")
			if(!contraband_brew_into(cell, toilet))
				return list("error" = "Cell [number]'s cistern is full.")
			return "brew pruno in the cistern of prison cell [number]"
		if("clear")
			cell.stash_shiv = FALSE
			contraband_spill_pruno(cell)
			return "clear the stashes of prison cell [number]"
	return list("error" = "Invalid stash kind.")

// ===== ACTIVITIES =====

/// Sour and unwatched: sitting on the bed edge, scraping something sharp against the floor
/datum/prisoner_activity/make_shiv
	name = "sharpening something"
	weight = 0
	interruptible = FALSE
	var/datum/weakref/bed_ref
	/// Seconds spent at it, and to the next scrape
	var/worked = 0
	var/scrape_left = 0

/datum/prisoner_activity/make_shiv/setup()
	var/obj/structure/bed/bed = prisoner.cell?.bed()
	var/turf/bed_turf = bed ? get_turf(bed) : null
	if(!bed_turf || !prisoner.walkable?[bed_turf] || (bed_turf != prisoner.loc && prisoner.tile_taken(bed_turf)))
		return FALSE
	if(!claim(bed))
		return FALSE
	bed_ref = WEAKREF(bed)
	spot = bed_turf
	return TRUE

/datum/prisoner_activity/make_shiv/begin()
	started = TRUE
	ends_at = INFINITY
	var/obj/machinery/door/door = prisoner.cell?.door()
	prisoner.sit_on_edge(door ? get_cardinal_dir(prisoner, door) : SOUTH)
	prisoner.manual_emote("sharpens something against the floor.")
	scrape()

/datum/prisoner_activity/make_shiv/proc/scrape()
	scrape_left = OUTPOST_CONTRABAND_SCRAPE_GAP
	playsound(prisoner, 'sound/items/unsheath.ogg', 25, TRUE, -4)

/datum/prisoner_activity/make_shiv/tick(seconds)
	var/obj/structure/bed/bed = bed_ref?.resolve()
	var/datum/outpost_prison_cell/home = prisoner.cell
	if(!bed || prisoner.loc != bed.loc || !home || home.stash_shiv)
		return ACTIVITY_DONE
	var/datum/outpost_prison/prison = prisoner.prison
	var/mob/living/watcher = prison?.contraband_watcher(prisoner)
	if(watcher)
		prison.contraband_caught(prisoner, watcher, shiv = TRUE)
		return ACTIVITY_DONE
	worked += seconds
	if(worked >= OUTPOST_CONTRABAND_SHIV_TIME)
		prisoner.manual_emote("tucks something under the mattress.")
		home.stash_shiv = TRUE
		prisoner.contraband_shiv_sour = 0
		log_game("PLAYER OUTPOST PRISON: [prisoner.real_name] hid a shiv in cell [home.number] at '[prison?.outpost?.name]'")
		return ACTIVITY_DONE
	scrape_left -= seconds
	if(scrape_left <= 0)
		scrape()
	return ACTIVITY_CONTINUE

/// Grumbling and unwatched: a bag of fruit, sugar and water goes into the toilet tank
/datum/prisoner_activity/brew
	name = "fiddling with the toilet tank"
	weight = 0
	interruptible = FALSE
	var/datum/weakref/toilet_ref
	/// Seconds spent at it
	var/worked = 0

/datum/prisoner_activity/brew/setup()
	var/datum/outpost_prison/prison = prisoner.prison
	var/obj/structure/toilet/toilet = prison?.contraband_cistern(prisoner.cell)
	if(!toilet || prison.contraband_pruno(prisoner.cell) || !prison.contraband_cistern_room(toilet, outpost_prison_pruno_weight()))
		return FALSE
	var/turf/stand = prisoner.approach_turf(toilet)
	if(!stand || !claim(toilet))
		return FALSE
	toilet_ref = WEAKREF(toilet)
	spot = stand
	return TRUE

/datum/prisoner_activity/brew/begin()
	started = TRUE
	ends_at = INFINITY
	var/obj/structure/toilet/toilet = toilet_ref?.resolve()
	if(toilet)
		prisoner.face_atom(toilet)
		playsound(toilet, 'sound/effects/stonedoor_openclose.ogg', 25, TRUE)
	prisoner.manual_emote("fiddles with the toilet tank.")

/datum/prisoner_activity/brew/tick(seconds)
	var/obj/structure/toilet/toilet = toilet_ref?.resolve()
	var/datum/outpost_prison/prison = prisoner.prison
	if(!toilet || !prison || get_dist(prisoner, toilet) > 1 || prison.contraband_pruno(prisoner.cell))
		return ACTIVITY_DONE
	var/mob/living/watcher = prison.contraband_watcher(prisoner)
	if(watcher)
		prison.contraband_caught(prisoner, watcher, shiv = FALSE)
		return ACTIVITY_DONE
	worked += seconds
	if(worked < OUTPOST_CONTRABAND_BREW_TIME)
		return ACTIVITY_CONTINUE
	if(prison.contraband_brew_into(prisoner.cell, toilet))
		prisoner.contraband_brew_sour = 0
		playsound(toilet, 'sound/effects/stonedoor_openclose.ogg', 25, TRUE)
	return ACTIVITY_DONE

/// A swig from the pruno in their own cistern, once it has fermented
/datum/prisoner_activity/drink_pruno
	name = "drinking pruno"
	leisure = TRUE
	weight = OUTPOST_CONTRABAND_DRINK_WEIGHT
	interruptible = FALSE
	var/datum/weakref/toilet_ref
	/// Seconds spent at it
	var/worked = 0

/datum/prisoner_activity/drink_pruno/get_weight()
	// A content prisoner leaves it in the tank.
	if(prisoner.mood >= OUTPOST_CONTRABAND_DRINK_MOOD)
		return 0
	if(!outpost_prison_pruno_ready(prisoner.prison?.contraband_pruno(prisoner.cell)))
		return 0
	return ..()

/datum/prisoner_activity/drink_pruno/setup()
	var/obj/item/reagent_containers/cup/glass/bottle/pruno/bag = prisoner.prison?.contraband_pruno(prisoner.cell)
	if(!outpost_prison_pruno_ready(bag))
		return FALSE
	var/obj/structure/toilet/toilet = bag.loc
	var/turf/stand = prisoner.approach_turf(toilet)
	if(!stand || !claim(toilet))
		return FALSE
	toilet_ref = WEAKREF(toilet)
	spot = stand
	return TRUE

/datum/prisoner_activity/drink_pruno/begin()
	started = TRUE
	ends_at = INFINITY
	var/obj/structure/toilet/toilet = toilet_ref?.resolve()
	if(toilet)
		prisoner.face_atom(toilet)
		playsound(toilet, 'sound/effects/stonedoor_openclose.ogg', 25, TRUE)

/datum/prisoner_activity/drink_pruno/tick(seconds)
	var/obj/structure/toilet/toilet = toilet_ref?.resolve()
	if(!toilet || get_dist(prisoner, toilet) > 1)
		return ACTIVITY_DONE
	worked += seconds
	if(worked < OUTPOST_CONTRABAND_DRINK_TIME)
		return ACTIVITY_CONTINUE
	prisoner.prison?.contraband_drink(prisoner)
	return ACTIVITY_DONE

// ===== THE ITEMS =====

/// Contraband that came in the mail. Once found, it's an ordinary item worth nothing.
/obj/item/outpost_prison_contraband
	name = "contraband"
	w_class = WEIGHT_CLASS_TINY
	resistance_flags = FLAMMABLE

/obj/item/outpost_prison_contraband/razor_blade
	name = "razor blade"
	desc = "A thin steel blade, sharp along one edge and small enough to slip into an envelope."
	icon = 'icons/obj/service/bureaucracy.dmi'
	icon_state = "cutterblade"
	force = 2
	sharpness = SHARP_EDGED
	hitsound = 'sound/items/weapons/bladeslice.ogg'
	attack_verb_continuous = list("slashes", "nicks")
	attack_verb_simple = list("slash", "nick")
	resistance_flags = NONE

/obj/item/outpost_prison_contraband/yeast
	name = "packet of yeast"
	desc = "A paper sachet of dried baker's yeast. Nobody in a cell has much baking to do."
	icon = 'icons/obj/food/containers.dmi'
	icon_state = "condi_empty"

/**
 * The prison's pruno: tg's pruno bag, which ferments by itself in 30 seconds inside a structure.
 * tg's own smell message only reaches mobs with TRAIT_ANOSMIA, so this one tells everyone else
 * close by: the tell that a cistern holds a batch.
 */
/obj/item/reagent_containers/cup/glass/bottle/pruno/outpost_prison

/obj/item/reagent_containers/cup/glass/bottle/pruno/outpost_prison/do_fermentation()
	. = ..()
	var/turf/here = get_turf(src)
	if(!here)
		return
	var/atom/source = isturf(loc) ? src : loc
	for(var/mob/living/nearby in view(2, here))
		if(!HAS_TRAIT(nearby, TRAIT_ANOSMIA))
			to_chat(nearby, span_notice("A sour, fruity smell comes from [source]."))

#undef ACTIVITY_CONTINUE
#undef ACTIVITY_DONE
#undef CONTRABAND_PATDOWN_CHOICE
#undef CONTRABAND_PRUNO_TYPE

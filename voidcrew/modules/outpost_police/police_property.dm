/**
 * # Outpost police: property
 *
 * Owner: P12. Confiscation (the offending items), the evidence locker, the property lockers and the jail strip.
 * Spec 6.1, 6.3 and the locker half of 7.
 *
 * Nothing here copies, stores for sale or hands out a thing:
 * - A crime tool taken at an arrest goes into an evidence case, and from it into the station's evidence locker
 *   (evidence_locker.dm), which a police ID or an emag opens.
 * - A jailed prisoner's gear goes straight from their body into a real tg secure closet, never onto the cell
 *   floor, and comes back only through that closet.
 * - Stolen property (an item still listed in another prisoner's locker) goes back to that locker, never down
 *   the evidence locker.
 * - Things whose loss would break something outside the arrest stay on the person (outpost_police_untouchable()).
 *
 * The lockers are anchored outpost property that players can open (their owner, the registered ID, an emag) and
 * never lock. Only this file locks one.
 */

/// Multiplier on the waits in this file (search, strip). 1 in play; the tests turn it down.
GLOBAL_VAR_INIT(outpost_police_property_time_scale, 1)

// =========================================================================
// WHAT STAYS WITH ITS PERSON (abuse M21, M22)
// =========================================================================

/// Whether `part` is something the police never take or destroy: a live mob, an organ, a limb, an implant, or a type
/// whose loss breaks something outside the arrest (ship keys, mission items, bounty proof, paper)
/proc/outpost_police_protected_part(atom/movable/part)
	if(isliving(part) || isorgan(part) || isbodypart(part) || istype(part, /obj/item/implant))
		return TRUE
	return is_type_in_typecache(part, GLOB.human_npc_not_gear)

/// Whether `thing` is never taken from a person or put in a locker by force
/proc/outpost_police_untouchable(obj/item/thing)
	if(QDELETED(thing))
		return TRUE
	if(HAS_TRAIT(thing, TRAIT_NODROP) || (thing.item_flags & (ABSTRACT | DROPDEL)))
		return TRUE
	return outpost_police_protected_part(thing)

/// Whether `thing` holds a living mob anywhere inside it (a pet carrier, a body bag)
/proc/outpost_police_holds_mob(obj/item/thing)
	for(var/mob/living/inside in thing.get_all_contents_type(/mob/living))
		return TRUE
	return FALSE

/// The outermost things inside `container` whose loss would break something outside an arrest (ship keys, mission
/// items, bounty proof, paper): the strip leaves them on their owner (review S3)
/proc/outpost_police_keepsakes(obj/item/container)
	. = list()
	for(var/obj/item/part as anything in container.get_all_contents_type(/obj/item))
		if(part == container || QDELETED(part) || !is_type_in_typecache(part, GLOB.human_npc_not_gear))
			continue
		var/nested = FALSE
		for(var/atom/holder = part.loc; holder && holder != container; holder = holder.loc)
			if(is_type_in_typecache(holder, GLOB.human_npc_not_gear))
				nested = TRUE
				break
		if(!nested)
			. += part

/// Moves everything inside `doomed` that must not be destroyed onto `where`
/proc/outpost_police_salvage(obj/item/doomed, turf/where)
	for(var/atom/movable/part as anything in doomed.get_all_contents())
		if(part == doomed || QDELETED(part) || !outpost_police_protected_part(part))
			continue
		if(where)
			part.forceMove(where)

/// Whether `thing` is on `person` (worn, held, in a bag) or loose on the floor within two tiles of them (or `officer`)
/proc/outpost_police_in_reach(obj/item/thing, mob/living/person, mob/living/officer)
	if(QDELETED(thing) || QDELETED(person) || !isturf(person.loc))
		return FALSE
	var/atom/movable/top = get_atom_on_turf(thing)
	if(top == person)
		return TRUE
	if(top != thing || !isturf(thing.loc))
		return FALSE
	if(thing.z == person.z && get_dist(thing, person) <= 2)
		return TRUE
	if(officer && isturf(officer.loc) && thing.z == officer.z && get_dist(thing, officer) <= 2)
		return TRUE
	return FALSE

// =========================================================================
// THE PROPERTY LOCKER
// =========================================================================

/**
 * A prisoner's gear, locked to them (owner decision 7). A real secure closet: anchored outpost property, never
 * welded, nothing in it until the strip puts something there. It opens for its owner in person, for the ID card
 * registered at booking in any hand, and for an emag. Players can open it and never lock it, so it is never a
 * private safe. The goods stay listed here until their owner takes them, so a thief carrying them can be told
 * from the owner (and the goods sent back at an arrest).
 */
/obj/structure/closet/secure_closet/personal/outpost_police
	name = "property locker"
	desc = "A locker for a prisoner's things."
	anchored = TRUE
	anchorable = FALSE
	can_weld_shut = FALSE
	can_install_electronics = FALSE
	divable = FALSE
	paint_jobs = null
	delivery_icon = null
	storage_capacity = 60
	req_access = list()
	/// Weakref to the mind of the prisoner whose gear this holds
	var/datum/weakref/owner_mind
	/// Weakrefs to everything the strip put in (bags and what is inside them), until the owner takes it
	var/list/stored_items
	/// world.time its owner was let out, or 0 while they are still held (or never noticed leaving)
	var/released_at = 0
	/// A strip is under way: nobody else may take this locker
	var/assigning = FALSE
	/// Minds that were reported for robbing it: weakref -> world.time
	var/list/thieves
	/// Who first took each listed item out: item weakref -> mind weakref. Only they are the thief (abuse SF1).
	var/list/first_takers
	/// Weakref to the police this locker belongs to
	var/datum/weakref/police_ref

/obj/structure/closet/secure_closet/personal/outpost_police/Initialize(mapload)
	. = ..()
	// Nobody claims, renames or re-keys it with a card (abuse M18)
	access_choices = null
	AddElement(/datum/element/outpost_property)

/obj/structure/closet/secure_closet/personal/outpost_police/Destroy()
	for(var/datum/weakref/ref as anything in stored_items)
		var/obj/item/thing = ref?.resolve()
		if(thing)
			UnregisterSignal(thing, COMSIG_MOVABLE_MOVED)
	stored_items = null
	owner_mind = null
	police_ref = null
	thieves = null
	first_takers = null
	return ..()

// Nothing comes with it (abuse M18)
/obj/structure/closet/secure_closet/personal/outpost_police/PopulateContents()
	return

// A booking registers a card, and tg then offers a pen it never takes here (tool_interact())
/obj/structure/closet/secure_closet/personal/outpost_police/examine(mob/user)
	. = ..()
	. -= span_notice("It can be [EXAMINE_HINT("marked")] with a pen.")

/// No painting, renaming or re-wiring it (abuse M18)
/obj/structure/closet/secure_closet/personal/outpost_police/tool_interact(obj/item/weapon, mob/living/user)
	if(IS_WRITING_UTENSIL(weapon))
		return TRUE
	return ..()

/// The owner in person, or the registered ID card in any hand (abuse M26). Never anyone else, and a deleted card never makes it public.
/obj/structure/closet/secure_closet/personal/outpost_police/can_unlock(mob/living/user, obj/item/card/id/player_id, obj/item/card/id/registered_id)
	return is_authorised(user, player_id)

/// Players only ever unlock it (abuse M20): only a booking locks it
/obj/structure/closet/secure_closet/personal/outpost_police/togglelock(mob/living/user, silent)
	if(!locked)
		return
	return ..()

/// tg's own emag: the lock breaks open. The owner allows looting, so it is not blocked; a witness may report it.
/obj/structure/closet/secure_closet/personal/outpost_police/emag_act(mob/user, obj/item/card/emag/emag_card)
	. = ..()
	if(. && isliving(user))
		report_theft(user, emag_card)

/obj/structure/closet/secure_closet/personal/outpost_police/proc/get_police()
	return police_ref?.resolve()

/// The prisoner whose things these are, if they still exist
/obj/structure/closet/secure_closet/personal/outpost_police/proc/owner()
	return owner_mind?.resolve()

/// Whether `user` may take things from here: the owner, or whoever holds the registered ID
/obj/structure/closet/secure_closet/personal/outpost_police/proc/is_authorised(mob/living/user, obj/item/card/id/player_id)
	if(!user)
		return FALSE
	var/datum/mind/owning = owner()
	if(owning && user.mind == owning)
		return TRUE
	var/obj/item/card/id/registered = id_card?.resolve()
	if(!registered)
		return FALSE
	return player_id == registered || user.get_idcard() == registered

/// The things still listed here that exist
/obj/structure/closet/secure_closet/personal/outpost_police/proc/live_items()
	. = list()
	for(var/datum/weakref/ref as anything in stored_items)
		var/obj/item/thing = ref?.resolve()
		if(thing && !QDELETED(thing))
			. += thing
	if(length(.) != length(stored_items))
		stored_items = null
		for(var/obj/item/thing as anything in .)
			LAZYADD(stored_items, WEAKREF(thing))

/// Whether `thing` is listed here
/obj/structure/closet/secure_closet/personal/outpost_police/proc/holds(obj/item/thing)
	return !!(WEAKREF(thing) in stored_items)

/// Free for the next prisoner: shut, nobody's, nothing left of theirs, no strip under way
/obj/structure/closet/secure_closet/personal/outpost_police/proc/is_free()
	return !assigning && !opened && !owner() && !length(live_items())

/// Lists `thing` and what it holds as this locker's, and listens for them leaving
/obj/structure/closet/secure_closet/personal/outpost_police/proc/record(obj/item/thing)
	for(var/obj/item/part as anything in thing.get_all_contents_type(/obj/item))
		if(QDELETED(part) || isorgan(part) || isbodypart(part))
			continue
		var/datum/weakref/ref = WEAKREF(part)
		if(ref in stored_items)
			continue
		LAZYADD(stored_items, ref)
		UnregisterSignal(part, COMSIG_MOVABLE_MOVED)
		RegisterSignal(part, COMSIG_MOVABLE_MOVED, PROC_REF(on_stored_moved))

/// Stops listing `thing` and what it holds
/obj/structure/closet/secure_closet/personal/outpost_police/proc/forget(obj/item/thing)
	for(var/obj/item/part as anything in thing.get_all_contents_type(/obj/item))
		if(stored_items)
			stored_items -= WEAKREF(part)
		UnregisterSignal(part, COMSIG_MOVABLE_MOVED)
	if(!length(stored_items))
		stored_items = null

/// Something listed here moved. Inside, or on the spilled pile at the locker, is fine; in a mob's hands it is
/// either the owner collecting their things or someone robbing them.
/obj/structure/closet/secure_closet/personal/outpost_police/proc/on_stored_moved(obj/item/source, atom/old_loc, movement_dir, forced, list/old_locs)
	SIGNAL_HANDLER
	if(QDELETED(source) || QDELETED(src) || !source.loc)
		return
	var/atom/movable/top = get_atom_on_turf(source)
	if(top == src)
		for(var/obj/item/part as anything in source.get_all_contents_type(/obj/item))
			LAZYREMOVE(first_takers, WEAKREF(part)) // back in: whoever takes it next is the thief
		return
	if(!isliving(top))
		return
	// Officers carrying evidence are not thieves; the arrest sorts it out
	if(istype(top, /mob/living/carbon/human/npc/ambient_npc/outpost/police))
		return
	var/mob/living/taker = top
	if(is_authorised(taker))
		forget(source)
		addtimer(CALLBACK(src, PROC_REF(check_freed)), 1 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_DELETE_ME)
		return
	if(!taker.mind)
		return
	// Abuse SF1: goods handed or planted on someone after they left the locker are the first taker's theft, not theirs
	var/datum/weakref/item_ref = WEAKREF(source)
	var/datum/weakref/taker_ref = WEAKREF(taker.mind)
	var/datum/weakref/first = LAZYACCESS(first_takers, item_ref)
	if(first && first != taker_ref)
		return
	for(var/obj/item/part as anything in source.get_all_contents_type(/obj/item))
		if(!holds(part))
			continue
		var/datum/weakref/part_ref = WEAKREF(part)
		if(!LAZYACCESS(first_takers, part_ref))
			LAZYSET(first_takers, part_ref, taker_ref)
	report_theft(taker, source)

/// `thief` took from or broke open this locker. Reported once per person; the witness test is the police's.
/obj/structure/closet/secure_closet/personal/outpost_police/proc/report_theft(mob/living/thief, obj/item/source)
	if(!thief?.mind || is_authorised(thief))
		return
	var/datum/weakref/key = WEAKREF(thief.mind)
	if(LAZYACCESS(thieves, key))
		return
	LAZYSET(thieves, key, world.time)
	get_police()?.report_crime(thief, OUTPOST_CRIME_LOCKER_THEFT, null, source)

/// The tile in front, where things are put out
/obj/structure/closet/secure_closet/personal/outpost_police/proc/front_turf()
	var/turf/front = get_step(src, dir)
	if(isopenturf(front) && !front.density)
		return front
	return get_turf(src)

/// Puts out everything that is not listed here, mobs first (abuse M18)
/obj/structure/closet/secure_closet/personal/outpost_police/proc/eject_strangers()
	var/turf/front = front_turf()
	for(var/mob/living/stranger in contents)
		stranger.forceMove(front)
	for(var/atom/movable/other as anything in contents.Copy())
		if(!isitem(other) || !holds(other))
			other.forceMove(front)
	if(!opened)
		return
	var/turf/home = get_turf(src)
	for(var/mob/living/stranger in home)
		stranger.forceMove(front)
	for(var/atom/movable/loose as anything in home.contents.Copy())
		if(loose == src || isliving(loose) || iseffect(loose) || loose.anchored)
			continue
		if(isitem(loose) && holds(loose))
			continue
		loose.forceMove(front)

/// Shuts it, unbreaks the lock and locks it (abuse M19). Waits if someone stands in the doorway.
/obj/structure/closet/secure_closet/personal/outpost_police/proc/reset_lock()
	if(QDELETED(src) || assigning)
		return
	var/turf/home = get_turf(src)
	if(opened)
		if(locate(/mob/living) in home)
			addtimer(CALLBACK(src, PROC_REF(reset_lock)), 5 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_DELETE_ME)
			return
		if(!close())
			addtimer(CALLBACK(src, PROC_REF(reset_lock)), 5 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_DELETE_ME)
			return
	for(var/mob/living/stranger in contents)
		stranger.forceMove(front_turf())
	broken = FALSE
	lock()
	update_appearance()

/// Nobody's again: the registration and the owner are cleared, the lock is reset
/obj/structure/closet/secure_closet/personal/outpost_police/proc/free_up()
	owner_mind = null
	id_card = null
	released_at = 0
	thieves = null
	first_takers = null
	stored_items = null
	name = initial(name)
	desc = initial(desc)
	reset_lock()

/// Frees it when everything of its owner's has been collected (or has ceased to exist)
/obj/structure/closet/secure_closet/personal/outpost_police/proc/check_freed()
	if(QDELETED(src) || assigning || length(live_items()))
		return
	free_up()

/// Empties what the prisoner left onto the floor in front and frees it. Nothing is deleted (abuse J20).
/obj/structure/closet/secure_closet/personal/outpost_police/proc/evict()
	var/turf/front = front_turf()
	var/turf/home = get_turf(src)
	var/list/goods = live_items()
	for(var/obj/item/thing as anything in goods)
		if(thing.loc == src || thing.loc == home)
			thing.forceMove(front)
	for(var/obj/item/thing as anything in goods)
		forget(thing)
	free_up()

/// Takes it for `prisoner`'s strip: strangers out, shut, theirs. FALSE if it cannot be shut.
/obj/structure/closet/secure_closet/personal/outpost_police/proc/reserve_for(mob/living/prisoner)
	eject_strangers()
	if(opened && !close())
		return FALSE
	broken = FALSE
	owner_mind = WEAKREF(prisoner.mind)
	assigning = TRUE
	thieves = null
	first_takers = null
	released_at = 0
	return TRUE

/// The strip did not happen
/obj/structure/closet/secure_closet/personal/outpost_police/proc/release_reservation()
	assigning = FALSE
	if(!length(live_items()))
		free_up()

/// The strip is done: registered to `card`, locked
/obj/structure/closet/secure_closet/personal/outpost_police/proc/finish_assignment(obj/item/card/id/card)
	assigning = FALSE
	if(!length(live_items()))
		free_up()
		return
	if(card)
		id_card = WEAKREF(card)
	broken = FALSE
	lock()
	update_appearance()

/// Stolen goods come back: in, shut, locked again (abuse M19)
/obj/structure/closet/secure_closet/personal/outpost_police/proc/give_back(obj/item/thing)
	if(QDELETED(thing))
		return
	if(opened)
		thing.forceMove(get_turf(src))
		reset_lock()
		return
	thing.forceMove(src)
	broken = FALSE
	lock()
	update_appearance()

// =========================================================================
// THE EVIDENCE CASE AND THE ISSUED CLOTHES
// =========================================================================

/// The case an officer carries what they took in. Never locked to the officer: it drops with them if they die.
/obj/item/outpost_sealed_case/evidence
	name = "evidence case"
	desc = "A hard case with an evidence tag across the latch."
	w_class = WEIGHT_CLASS_NORMAL
	/// Weakref to the police that filled it
	var/datum/weakref/police_ref
	/// Weakref of an item inside -> who it was taken from, for the log
	var/list/taken_from

/// Takes `thing` off `holder` (or off the floor, or out of their bag) into the case
/obj/item/outpost_sealed_case/evidence/proc/add_evidence(obj/item/thing, mob/living/holder)
	if(thing.loc == holder)
		if(!holder.transferItemToLoc(thing, src, FALSE, TRUE, FALSE))
			return FALSE
	else
		thing.forceMove(src)
	w_class = max(w_class, thing.w_class)
	LAZYSET(taken_from, WEAKREF(thing), holder ? key_name(holder) : "the floor")
	return TRUE

/// Evidence never spills (abuse M24): whatever is still inside goes to the evidence locker, wherever the case is
/// deleted (an officer faded or collected with it on them, review S1); only with no locker at all is it deleted
/obj/item/outpost_sealed_case/evidence/Destroy()
	var/datum/outpost_police/police = police_ref?.resolve()
	if(police)
		police.evidence_empty_case(src, get_turf(src), police.get_evidence_locker())
	for(var/atom/movable/inside as anything in contents.Copy())
		qdel(inside)
	taken_from = null
	return ..()

/// What a jailed prisoner wears. Gone the moment it comes off (abuse M23).
/obj/item/clothing/under/rank/prisoner/outpost_police
	desc = "An orange jumpsuit from an outpost holding cell. Its suit sensors are stuck on."
	flags_1 = parent_type::flags_1 | NO_NEW_GAGS_PREVIEW_1 // same icon and colour as the base type
	item_flags = parent_type::item_flags | DROPDEL

/obj/item/clothing/shoes/sneakers/orange/outpost_police
	flags_1 = parent_type::flags_1 | NO_NEW_GAGS_PREVIEW_1 // same icon and colour as the base type
	item_flags = parent_type::item_flags | DROPDEL

// =========================================================================
// THE POLICE SIDE
// =========================================================================

/datum/outpost_police
	/// world.time get_evidence_locker() may next look over the station for a locker
	var/evidence_locker_search_at = 0

/// Resets and locks the station's lockers (called by link_interior())
/datum/outpost_police/proc/build_property(list/locker_list, obj/structure/closet/secure_closet/outpost_evidence/locker_for_evidence)
	UnregisterSignal(src, COMSIG_OUTPOST_POLICE_RELEASED)
	RegisterSignal(src, COMSIG_OUTPOST_POLICE_RELEASED, PROC_REF(property_on_released))
	for(var/obj/structure/closet/secure_closet/personal/outpost_police/locker as anything in locker_list)
		locker.police_ref = WEAKREF(src)
		locker.AddElement(/datum/element/outpost_property)
		// Not yet initialised (a pre-loaded interior): the type already starts shut, locked and nobody's
		if(locker.flags_1 & INITIALIZED_1)
			locker.free_up()
	if(length(locker_list) != OUTPOST_POLICE_LOCKERS)
		log_mapping("OUTPOST POLICE: [outpost] has [length(locker_list)] property lockers, not [OUTPOST_POLICE_LOCKERS].")
	if(!locker_for_evidence)
		log_mapping("OUTPOST POLICE: [outpost] has no evidence locker.")

/// `suspect` was let out of the cells: their locker's owner has been released from now
/datum/outpost_police/proc/property_on_released(datum/source, mob/living/suspect)
	SIGNAL_HANDLER
	if(!suspect?.mind)
		return
	for(var/obj/structure/closet/secure_closet/personal/outpost_police/locker as anything in lockers)
		if(!QDELETED(locker) && locker.owner() == suspect.mind)
			locker.released_at = world.time

/// For a later theft system: `thing` was stolen by `thief`. Unused in this build.
/datum/outpost_police/proc/mark_stolen(obj/item/thing, datum/mind/thief)
	return

/// Whether `who` is a prisoner in any cell right now
/datum/outpost_police/proc/property_held_in_cells(datum/mind/who)
	return !!cell_holding(who)

/// The locker holding `thing` among its listed goods, if any
/datum/outpost_police/proc/property_locker_holding(obj/item/thing)
	for(var/obj/structure/closet/secure_closet/personal/outpost_police/locker as anything in lockers)
		if(!QDELETED(locker) && locker.holds(thing))
			return locker
	return null

/// The locker for `prisoner`'s gear: one that is theirs already, a free one, or the one whose owner was let out
/// longest ago (emptied onto the floor in front). Null when all of them belong to people still in the cells.
/datum/outpost_police/proc/property_locker_for(mob/living/prisoner)
	var/datum/mind/mind = prisoner.mind
	for(var/obj/structure/closet/secure_closet/personal/outpost_police/locker as anything in lockers)
		if(!QDELETED(locker) && !locker.assigning && locker.owner() == mind)
			return locker
	for(var/obj/structure/closet/secure_closet/personal/outpost_police/locker as anything in lockers)
		if(!QDELETED(locker) && locker.is_free())
			return locker
	var/obj/structure/closet/secure_closet/personal/outpost_police/oldest
	for(var/obj/structure/closet/secure_closet/personal/outpost_police/locker as anything in lockers)
		if(QDELETED(locker) || locker.assigning)
			continue
		var/datum/mind/owning = locker.owner()
		if(owning && property_held_in_cells(owning))
			continue
		// An owner who left without a release signal counts from now
		if(!locker.released_at)
			locker.released_at = world.time
		if(!oldest || locker.released_at < oldest.released_at)
			oldest = locker
	oldest?.evict()
	return oldest

/// The lobby tile outside the door of the cell `prisoner` is in (the cell's own outside_turf), or the officer's own tile when there is none
/datum/outpost_police/proc/property_outside_turf(mob/living/prisoner, mob/living/officer)
	var/turf/inside = get_turf(prisoner)
	for(var/datum/outpost_police_cell/cell as anything in cells)
		if(!(inside in cell.tiles))
			continue
		// usable() looks for the outside tile again when it is missing or built over
		if(cell.usable())
			return cell.outside_turf
		break
	return get_turf(officer) || inside

/datum/outpost_police/proc/property_strip_check(mob/living/prisoner, mob/living/officer)
	return !QDELETED(prisoner) && !QDELETED(officer) && officer.Adjacent(prisoner)

/**
 * The jail strip: gear into a property locker, the prison jumpsuit on. Sleeps. TRUE if stripped, FALSE if no
 * locker was free (or the strip was interrupted). Everything comes off through tg's own unequip straight into
 * the locker, so nothing ever lies in the cell; the ID card, the cuffs, and what must never be taken stay on.
 */
/datum/outpost_police/proc/store_property(mob/living/carbon/prisoner, mob/living/officer)
	if(QDELETED(prisoner) || !prisoner.mind || !ishuman(prisoner))
		return FALSE
	var/mob/living/carbon/human/person = prisoner
	var/obj/structure/closet/secure_closet/personal/outpost_police/locker = property_locker_for(prisoner)
	if(!locker || !locker.reserve_for(prisoner))
		return FALSE
	var/delay = max(1, round(OUTPOST_POLICE_STRIP_TIME * GLOB.outpost_police_property_time_scale))
	if(istype(officer, /mob/living/carbon/human/npc/ambient_npc/outpost/police))
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/stripper = officer
		if(!stripper.buckled)
			stripper.face_atom(prisoner)
		stripper.police_say(POLICE_LINE_STRIP)
	if(officer && !do_after(officer, delay, prisoner, IGNORE_USER_LOC_CHANGE | IGNORE_TARGET_LOC_CHANGE | IGNORE_HELD_ITEM, extra_checks = CALLBACK(src, PROC_REF(property_strip_check), prisoner, officer), interaction_key = "outpost_police_strip"))
		locker.release_reservation()
		return FALSE
	if(QDELETED(prisoner) || QDELETED(locker))
		locker?.release_reservation()
		return FALSE

	// Unseal and retract any worn MODsuit so its parts fold into the control unit and strip cleanly into the locker
	for(var/obj/item/mod/control/mod_suit in prisoner.get_equipped_items(INCLUDE_POCKETS | INCLUDE_HELD))
		if(outpost_police_untouchable(mod_suit))
			continue
		if(mod_suit.active && !mod_suit.toggle_activate(officer || prisoner, force_deactivate = TRUE))
			continue
		for(var/obj/item/part as anything in mod_suit.get_parts())
			if(part.loc != mod_suit)
				mod_suit.retract(null, part, TRUE)

	// The ID card stays on them: lift it out of any PDA or wallet and off the slot, so removing the jumpsuit cannot drop it
	var/obj/item/card/id/card = prisoner.get_idcard(FALSE) || prisoner.get_idcard(TRUE)
	if(card)
		if(card.loc != prisoner)
			card.forceMove(prisoner)
		prisoner.temporarilyRemoveItemFromInventory(card, TRUE)

	var/list/gear = prisoner.get_equipped_items(INCLUDE_POCKETS | INCLUDE_HELD)
	list_clear_nulls(gear)
	if(card)
		gear -= card
	if(prisoner.handcuffed)
		gear -= prisoner.handcuffed
	if(prisoner.legcuffed)
		gear -= prisoner.legcuffed
	// tg drops pockets, suit storage and belt when the jumpsuit or suit comes off; what stays on them is put back after
	var/list/pocketed = list()
	for(var/obj/item/slotted as anything in list(person.l_store, person.r_store, person.s_store, person.belt))
		if(slotted && outpost_police_untouchable(slotted))
			pocketed[slotted] = person.get_slot_by_item(slotted)
	// Suit storage before the suit and the jumpsuit last, so tg never drops anything on the floor behind us
	var/list/ordered = list()
	var/list/outside = list()
	var/obj/item/jumpsuit
	for(var/obj/item/thing as anything in gear)
		if(outpost_police_untouchable(thing))
			continue
		if(outpost_police_holds_mob(thing))
			outside += thing
		else if(thing == person.w_uniform)
			jumpsuit = thing
		else if(thing == person.s_store)
			ordered.Insert(1, thing)
		else
			ordered += thing
	if(jumpsuit)
		ordered += jumpsuit

	var/stored = 0
	var/list/keepsakes = list()
	for(var/obj/item/thing as anything in ordered)
		if(QDELETED(thing))
			continue
		// A ship key or mission item in a bag stays with its owner (review S3): held on them until the clothes are on
		for(var/obj/item/keepsake as anything in outpost_police_keepsakes(thing))
			keepsake.forceMove(prisoner)
			keepsakes += keepsake
		if(thing.loc == prisoner)
			if(!prisoner.transferItemToLoc(thing, locker, FALSE, TRUE, FALSE))
				continue
		else if(isturf(thing.loc) && get_dist(thing, prisoner) <= 1)
			// Something tg dropped as a side effect of an earlier item: it goes in with the rest
			thing.forceMove(locker)
		else
			continue
		property_return_stolen(thing)
		if(property_locker_holding(thing))
			continue
		locker.record(thing)
		stored++
	var/turf/outside_turf = property_outside_turf(prisoner, officer)
	for(var/obj/item/thing as anything in outside)
		prisoner.transferItemToLoc(thing, outside_turf, FALSE, TRUE, FALSE)

	// The prison clothes (they delete themselves when taken off), then the ID back where it belongs
	prisoner.equip_to_slot_if_possible(new /obj/item/clothing/under/rank/prisoner/outpost_police(), ITEM_SLOT_ICLOTHING, TRUE, TRUE, TRUE, TRUE)
	prisoner.equip_to_slot_if_possible(new /obj/item/clothing/shoes/sneakers/orange/outpost_police(), ITEM_SLOT_FEET, TRUE, TRUE, TRUE, TRUE)
	if(card && !QDELETED(card) && !prisoner.equip_to_slot_if_possible(card, ITEM_SLOT_ID, FALSE, TRUE, TRUE, TRUE))
		prisoner.put_in_hands(card)
	for(var/obj/item/slotted as anything in pocketed)
		if(QDELETED(slotted) || slotted.loc == prisoner || !isturf(slotted.loc) || get_dist(slotted, prisoner) > 1)
			continue
		if(!prisoner.equip_to_slot_if_possible(slotted, pocketed[slotted], FALSE, TRUE, TRUE, TRUE))
			prisoner.put_in_hands(slotted)
	// The keepsakes: pockets, then hands; what does not fit goes in the locker with their other things
	for(var/obj/item/keepsake as anything in keepsakes)
		if(QDELETED(keepsake) || keepsake.loc != prisoner)
			continue
		if(prisoner.equip_to_slot_if_possible(keepsake, ITEM_SLOT_LPOCKET, FALSE, TRUE, TRUE, TRUE) || prisoner.equip_to_slot_if_possible(keepsake, ITEM_SLOT_RPOCKET, FALSE, TRUE, TRUE, TRUE))
			continue
		if(prisoner.put_in_hands(keepsake))
			continue
		keepsake.forceMove(locker)
		locker.record(keepsake)

	locker.finish_assignment(card)
	log_game("OUTPOST POLICE: [key_name(prisoner)] was stripped at [outpost]: [stored] items to a property locker.")
	return TRUE

/// Stores a non-disposable restraint removed right after `store_property()` so it never stays loose on the cell floor
/datum/outpost_police/proc/store_extra_property(mob/living/carbon/prisoner, obj/item/thing)
	if(QDELETED(prisoner) || !prisoner.mind || QDELETED(thing) || outpost_police_untouchable(thing))
		return FALSE
	var/obj/structure/closet/secure_closet/personal/outpost_police/locker = property_locker_for(prisoner)
	if(!locker)
		return FALSE
	var/obj/structure/closet/secure_closet/personal/outpost_police/victim = property_locker_holding(thing)
	if(victim)
		victim.give_back(thing)
		return TRUE
	if(thing.loc == prisoner)
		if(!prisoner.transferItemToLoc(thing, locker, FALSE, TRUE, FALSE))
			return FALSE
	else
		locker.give_back(thing)
	property_return_stolen(thing)
	if(!property_locker_holding(thing))
		locker.record(thing)
	return TRUE

/// Anything inside `container` that is listed in another prisoner's locker goes back there instead of into this one
/datum/outpost_police/proc/property_return_stolen(obj/item/container)
	for(var/obj/item/part as anything in container.get_all_contents_type(/obj/item))
		var/obj/structure/closet/secure_closet/personal/outpost_police/victim = property_locker_holding(part)
		if(victim)
			victim.give_back(part)

/// Whether the Search step may take `thing` off `suspect`
/datum/outpost_police/proc/evidence_can_take(obj/item/thing, mob/living/carbon/suspect, mob/living/officer)
	if(outpost_police_untouchable(thing) || outpost_police_holds_mob(thing) || !outpost_police_in_reach(thing, suspect, officer))
		return FALSE
	if(thing == suspect.handcuffed || thing == suspect.legcuffed)
		return FALSE
	// Their ID stays, and so does anything it is inside (a PDA)
	var/obj/item/card/id/card = suspect.get_idcard(FALSE) || suspect.get_idcard(TRUE)
	if(card && (thing == card || (card in thing.get_all_contents())))
		return FALSE
	return TRUE

/// What the Search step takes from `suspect` now: the crime tools on the warrant (or witnessed pending reports) and stolen property, in reach
/datum/outpost_police/proc/evidence_candidates(mob/living/carbon/suspect, mob/living/officer)
	var/list/take = list()
	var/datum/outpost_warrant/warrant = suspect.mind ? get_warrant(suspect.mind) : null
	if(warrant)
		for(var/datum/weakref/ref in warrant.evidence)
			var/obj/item/tool = ref.resolve()
			if(isitem(tool) && evidence_can_take(tool, suspect, officer))
				take |= tool
	// What this officer saw them use, while the report is still going in
	if(officer && length(pending_reports))
		var/datum/weakref/officer_ref = WEAKREF(officer)
		for(var/datum/outpost_pending_report/report as anything in pending_reports)
			if(QDELETED(report) || report.offender?.resolve() != suspect || !(officer_ref in report.witnesses))
				continue
			var/obj/item/main_tool = report.source?.resolve()
			if(isitem(main_tool) && evidence_can_take(main_tool, suspect, officer))
				take |= main_tool
			for(var/datum/weakref/folded_ref as anything in report.folded_sources)
				var/obj/item/folded_tool = folded_ref?.resolve()
				if(isitem(folded_tool) && evidence_can_take(folded_tool, suspect, officer))
					take |= folded_tool
	var/datum/weakref/suspect_mind_ref = suspect.mind ? WEAKREF(suspect.mind) : null
	for(var/obj/structure/closet/secure_closet/personal/outpost_police/locker as anything in lockers)
		if(QDELETED(locker) || (locker.owner() && locker.owner() == suspect.mind))
			continue
		var/turf/locker_turf = get_turf(locker)
		for(var/obj/item/stolen as anything in locker.live_items())
			var/atom/movable/holder = get_atom_on_turf(stolen)
			var/dropped_by_thief = suspect_mind_ref && stolen.loc != locker_turf && LAZYACCESS(locker.first_takers, WEAKREF(stolen)) == suspect_mind_ref
			if((holder == suspect || dropped_by_thief) && evidence_can_take(stolen, suspect, officer))
				take |= stolen
	return take

/datum/outpost_police/proc/property_search_check(mob/living/carbon/suspect, mob/living/officer)
	if(QDELETED(suspect) || QDELETED(officer))
		return FALSE
	if(officer.Adjacent(suspect))
		return TRUE
	// Someone downed in soft crit may crawl a tile during a pat-down: the officer steps beside them rather than breaking off
	if(police_suspect_down(suspect) && isturf(officer.loc) && isturf(suspect.loc) && officer.z == suspect.z && get_dist(officer, suspect) == 2 && !HAS_TRAIT(officer, TRAIT_INCAPACITATED))
		var/turf/towards = get_step_towards(officer, suspect)
		if(towards)
			officer.Move(towards, get_dir(officer, towards))
		return officer.Adjacent(suspect)
	return FALSE

/**
 * The Search step: takes the crime tools on `suspect`'s warrant, and any property still listed in another
 * prisoner's locker, off them or off the floor within two tiles into an evidence case in `officer`'s hand.
 * Sleeps. Returns the case, or null when there was nothing to take or the search was interrupted.
 */
/datum/outpost_police/proc/confiscate(mob/living/carbon/suspect, mob/living/officer, list/status_out = null)
	if(QDELETED(suspect) || QDELETED(officer) || !property_search_check(suspect, officer))
		return null
	var/list/take = evidence_candidates(suspect, officer)
	if(!length(take))
		if(islist(status_out))
			status_out["completed"] = TRUE
		return null
	officer.face_atom(suspect)
	officer.visible_message(
		span_notice("[officer] pats down [suspect]."),
		span_notice("You pat down [suspect]."),
	)
	var/delay = max(1, round(min(length(take) * OUTPOST_POLICE_SEARCH_ITEM, OUTPOST_POLICE_SEARCH_MAX) * GLOB.outpost_police_property_time_scale))
	if(!do_after(officer, delay, suspect, IGNORE_USER_LOC_CHANGE | IGNORE_TARGET_LOC_CHANGE | IGNORE_HELD_ITEM, extra_checks = CALLBACK(src, PROC_REF(property_search_check), suspect, officer), interaction_key = "outpost_police_search"))
		return null
	if(QDELETED(suspect) || QDELETED(officer))
		return null
	// They may have moved things while the officer was looking
	take = evidence_candidates(suspect, officer)
	if(!length(take))
		if(islist(status_out))
			status_out["completed"] = TRUE
		return null
	var/obj/item/outpost_sealed_case/evidence/case = new(get_turf(officer))
	case.police_ref = WEAKREF(src)
	var/turf/floor = get_turf(suspect)
	for(var/obj/item/thing as anything in take)
		if(QDELETED(thing))
			continue
		// A ship key or the like inside a tool being taken stays with the suspect
		outpost_police_salvage(thing, floor)
		case.add_evidence(thing, suspect)
	// The pat-down ran to the end, whatever it could take (act_search() does not search again)
	if(islist(status_out))
		status_out["completed"] = TRUE
	if(!length(case.contents))
		qdel(case)
		return null
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/cop = officer
	var/carried = istype(cop) ? cop.police_carry(case) : officer.put_in_hands(case)
	if(!carried)
		// No hand free for it (two cases already): straight to the evidence locker, never left on the floor
		evidence_empty_case(case, floor, get_evidence_locker())
		qdel(case)
		return null
	return case

/**
 * What a case holds: stolen property back into its locker, anything that must not be taken onto `spill`, the
 * rest into `store` (the evidence locker), which always takes it (review S2). Only with no evidence locker at the
 * outpost at all (a mapping error) is a crime tool deleted, as nothing taken may be left lying about. Returns how
 * many items were stored or deleted. The case itself is left to the caller.
 */
/datum/outpost_police/proc/evidence_empty_case(obj/item/outpost_sealed_case/evidence/case, turf/spill, obj/structure/closet/secure_closet/outpost_evidence/store)
	var/destroyed = 0
	for(var/obj/item/thing as anything in case.contents.Copy())
		if(QDELETED(thing))
			continue
		var/obj/structure/closet/secure_closet/personal/outpost_police/victim = property_locker_holding(thing)
		if(victim)
			victim.give_back(thing)
			continue
		if(outpost_police_untouchable(thing) || outpost_police_holds_mob(thing))
			if(spill)
				thing.forceMove(spill)
			continue
		outpost_police_salvage(thing, spill)
		var/from = LAZYACCESS(case.taken_from, WEAKREF(thing)) || "the floor"
		destroyed++
		if(store?.take_evidence(thing))
			log_game("OUTPOST POLICE: [thing] ([thing.type]) put in the evidence locker at [outpost]; taken from [from].")
			continue
		log_game("OUTPOST POLICE: [thing] ([thing.type]) destroyed at [outpost] with no evidence locker to hold it; taken from [from].")
		qdel(thing)
	return destroyed

/**
 * At the evidence locker: whatever evidence cases `officer` carries are emptied. Stolen property goes back in
 * its property locker, crime tools into the evidence locker, and the case goes last (abuse M24).
 */
/datum/outpost_police/proc/dispose_evidence(mob/living/officer)
	if(QDELETED(officer))
		return
	var/obj/structure/closet/secure_closet/outpost_evidence/store = get_evidence_locker()
	var/turf/spill = get_turf(officer)
	var/stored = 0
	for(var/obj/item/outpost_sealed_case/evidence/case in officer.get_all_contents())
		stored += evidence_empty_case(case, spill, store)
		qdel(case)
	if(stored && store)
		playsound(store, 'sound/machines/closet/closet_close.ogg', 30, TRUE)

/**
 * The station's evidence locker: the one the interior scan found, or the nearest one inside the outpost's
 * template (a locker placed or replaced later). Null if the outpost has none.
 */
/datum/outpost_police/proc/get_evidence_locker()
	if(!QDELETED(evidence_locker))
		return evidence_locker
	evidence_locker = null
	// One look over the station a minute at most: an outpost mapped without one is not searched on every arrest
	if(world.time < evidence_locker_search_at)
		return null
	evidence_locker_search_at = world.time + 1 MINUTES
	var/turf/corner = outpost?.template_bottom_left
	if(!corner || !outpost.outpost_template)
		return null
	var/turf/far = locate(corner.x + outpost.outpost_template.width - 1, corner.y + outpost.outpost_template.height - 1, corner.z)
	if(!far)
		return null
	var/turf/near = desk_turf || corner
	var/best_dist = INFINITY
	for(var/turf/spot as anything in block(corner, far))
		var/obj/structure/closet/secure_closet/outpost_evidence/locker = locate() in spot
		if(QDELETED(locker))
			continue
		var/dist = get_dist(spot, near)
		if(dist < best_dist)
			best_dist = dist
			evidence_locker = locker
	return evidence_locker

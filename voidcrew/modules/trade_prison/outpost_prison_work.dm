/**
 * # Outpost lockup: inmate work
 *
 * Held player inmates can work time off their sentence by doing real jobs in the wing
 * (design.md section 7, abuse rows 4 and 5):
 * - mop mess spawned by the wing's own mess code: 10 s (player-made decals are unmarked -> 0 s)
 * - wash a load of dirty prison-issue uniforms: 30 s
 * - deliver a wing letter to its addressee prisoner: 20 s
 * - dress or close a real wound on a prisoner with the wing's stocked dressings: 30 s
 * - hand an on-duty guard an item created by the contraband code: 60 s once per item
 *   (items spawned or crafted elsewhere are unmarked -> 0 s)
 *
 * Total time worked off never exceeds a third of `total_seconds` (round(total_seconds / 3)).
 * A guard on duty within sight remarks "That's time off." at most once every 20 seconds.
 */

/datum/outpost_prison
	/// REF(decal) -> weakref to a mess decal spawned by the wing's own mess code
	var/list/marked_mess_refs = list()
	/// REF(atom) -> weakref to the living mob that started cleaning that decal or floor tile
	var/list/mess_cleaners = list()
	/// REF(turf) -> weakref to a floor tile hooked for mop/cleaner pre-clean tracking
	var/list/hooked_clean_turfs = list()
	/// REF(item) -> weakref to an item created by the wing's contraband or mail code
	var/list/marked_contraband_refs = list()
	/// Weakrefs to contraband items confiscated off inmates so they stay out of play until wing deletion
	var/list/confiscated_contraband_refs = list()
	/// Proof key -> TRUE so no mess, wash load, letter, wound or contraband item ever credits twice
	var/list/credited_work_proofs = list()

// =========================================================================
// LIFECYCLE
// =========================================================================

/datum/outpost_prison/proc/work_setup()
	var/list/weights = GLOB.outpost_prison_mess_weights
	for(var/turf/tile as anything in cell_block)
		if(!isopenturf(tile))
			continue
		for(var/obj/effect/decal/cleanable/decal in tile)
			if(weights[decal.type] > 0)
				mark_wing_mess(decal)

/datum/outpost_prison/proc/work_destroy()
	for(var/key in marked_mess_refs)
		var/datum/weakref/ref = marked_mess_refs[key]
		var/atom/decal = ref?.resolve()
		if(decal)
			UnregisterSignal(decal, list(COMSIG_ATOM_PRE_CLEAN, COMSIG_QDELETING))
	marked_mess_refs.Cut()
	for(var/key in hooked_clean_turfs)
		var/datum/weakref/ref = hooked_clean_turfs[key]
		var/turf/tile = ref?.resolve()
		if(tile)
			UnregisterSignal(tile, list(COMSIG_ATOM_PRE_CLEAN, COMSIG_QDELETING))
	hooked_clean_turfs.Cut()
	mess_cleaners.Cut()
	marked_contraband_refs.Cut()
	for(var/datum/weakref/ref as anything in confiscated_contraband_refs)
		var/obj/item/confiscated = ref?.resolve()
		if(confiscated && isnull(confiscated.loc))
			qdel(confiscated)
	confiscated_contraband_refs.Cut()
	credited_work_proofs.Cut()

// =========================================================================
// TIME-OFF CREDIT
// =========================================================================

/// Seconds a work `kind` is worth before the one-third sentence cap
/proc/outpost_prison_work_seconds(kind)
	switch(kind)
		if(OUTPOST_PRISON_WORK_MOP)
			return OUTPOST_PRISON_WORK_MOP_SECONDS
		if(OUTPOST_PRISON_WORK_WASH)
			return OUTPOST_PRISON_WORK_WASH_SECONDS
		if(OUTPOST_PRISON_WORK_LETTER)
			return OUTPOST_PRISON_WORK_LETTER_SECONDS
		if(OUTPOST_PRISON_WORK_WOUND)
			return OUTPOST_PRISON_WORK_WOUND_SECONDS
		if(OUTPOST_PRISON_WORK_CONTRABAND)
			return OUTPOST_PRISON_WORK_CONTRABAND_SECONDS
	return 0

/// Normalizes `proof` (text key or datum) into a deduplication string, or null
/proc/outpost_prison_work_proof_key(kind, proof)
	if(isnull(proof))
		return null
	if(istext(proof))
		return length(proof) ? "[kind]:[proof]" : null
	if(isdatum(proof))
		return "[kind]:[REF(proof)]"
	return null

/**
 * Credits `inmate` with time off for `kind`, guarded by `proof` so the same piece of work never pays
 * twice and capped at round(total_seconds / 3) across the sentence. Returns the effective seconds
 * knocked off (0 when ineligible, duplicate or already at cap).
 */
/datum/outpost_prison/proc/note_work(mob/living/inmate, kind, proof = null)
	if(!isliving(inmate) || QDELETED(inmate))
		return 0
	var/datum/prison_sentence/sentence = sentence_for(inmate)
	if(!sentence || sentence.released || sentence.escaped)
		return 0
	var/amount = outpost_prison_work_seconds(kind)
	if(amount <= 0)
		return 0
	var/proof_key = outpost_prison_work_proof_key(kind, proof)
	if(proof_key)
		if(credited_work_proofs[proof_key])
			return 0
		credited_work_proofs[proof_key] = TRUE
	var/cap = round(sentence.total_seconds / 3)
	var/before = sentence.effective_worked_off()
	sentence.seconds_worked_off = min(cap, sentence.seconds_worked_off + amount)
	var/added = sentence.effective_worked_off() - before
	if(added <= 0)
		return 0
	tally_lockup_worked_off(src, inmate, kind, added)
	remark_on_work(inmate)
	update_lockup_boards()
	if(sentence.remaining_seconds() <= 0)
		INVOKE_ASYNC(src, PROC_REF(release_inmate), sentence.mind, TRUE)
	return added

/// An on-duty guard in sight of `inmate` remarks on the work, at most once per OUTPOST_PRISON_WORK_SAY_GAP
/datum/outpost_prison/proc/remark_on_work(mob/living/inmate)
	if(QDELETED(inmate) || !COOLDOWN_FINISHED(src, work_say_cooldown))
		return FALSE
	for(var/mob/living/carbon/human/npc/outpost_prison_guard/guard in view(7, inmate))
		if(guard.prison != src || !guard.on_duty())
			continue
		COOLDOWN_START(src, work_say_cooldown, OUTPOST_PRISON_WORK_SAY_GAP)
		guard.face_atom(inmate)
		INVOKE_ASYNC(guard, TYPE_PROC_REF(/atom/movable, say), "That's time off.")
		return TRUE
	return FALSE

// =========================================================================
// 1. MOPPING WING MESS (abuse 4: unmarked decals credit nothing)
// =========================================================================

/// Spawns a mess decal of `mess_type` on `where` and marks it as wing-made mess
/datum/outpost_prison/proc/spawn_wing_mess(mess_type, turf/where)
	if(!ispath(mess_type, /obj/effect/decal/cleanable) || !isturf(where))
		return null
	var/obj/effect/decal/cleanable/made = new mess_type(where)
	// Mergeable cleanables qdel the newcomer on Initialize() and keep the existing decal on the tile
	if(QDELETED(made))
		made = locate(mess_type) in where
	if(made && !QDELETED(made))
		mark_wing_mess(made)
	return made

/// Marks `decal` as wing-made mess and hooks cleaner tracking on both the decal and its floor tile
/datum/outpost_prison/proc/mark_wing_mess(obj/effect/decal/cleanable/decal)
	if(!istype(decal) || QDELETED(decal))
		return FALSE
	var/key = REF(decal)
	var/datum/weakref/existing = marked_mess_refs[key]
	if(existing?.resolve() == decal)
		return TRUE
	marked_mess_refs[key] = WEAKREF(decal)
	RegisterSignal(decal, COMSIG_ATOM_PRE_CLEAN, PROC_REF(on_mess_pre_clean), override = TRUE)
	RegisterSignal(decal, COMSIG_QDELETING, PROC_REF(on_marked_mess_deleted), override = TRUE)
	var/turf/tile = get_turf(decal)
	if(tile)
		var/tile_key = REF(tile)
		var/datum/weakref/known_tile = hooked_clean_turfs[tile_key]
		if(known_tile?.resolve() != tile)
			hooked_clean_turfs[tile_key] = WEAKREF(tile)
			RegisterSignal(tile, COMSIG_ATOM_PRE_CLEAN, PROC_REF(on_mess_pre_clean), override = TRUE)
			RegisterSignal(tile, COMSIG_QDELETING, PROC_REF(on_clean_turf_deleted), override = TRUE)
	return TRUE

/// Whether `decal` was marked by the wing's own mess code
/datum/outpost_prison/proc/is_wing_mess(obj/effect/decal/cleanable/decal)
	if(!istype(decal) || QDELETED(decal))
		return FALSE
	var/datum/weakref/known = marked_mess_refs[REF(decal)]
	return known?.resolve() == decal

/datum/outpost_prison/proc/on_mess_pre_clean(atom/source, mob/living/cleaner)
	SIGNAL_HANDLER
	if(isliving(cleaner))
		mess_cleaners[REF(source)] = WEAKREF(cleaner)
	return NONE

/datum/outpost_prison/proc/on_clean_turf_deleted(turf/source)
	SIGNAL_HANDLER
	var/key = REF(source)
	hooked_clean_turfs -= key
	mess_cleaners -= key

/datum/outpost_prison/proc/on_marked_mess_deleted(obj/effect/decal/cleanable/source)
	SIGNAL_HANDLER
	var/key = REF(source)
	marked_mess_refs -= key
	var/datum/weakref/cleaner_ref
	if(HAS_TRAIT(source, TRAIT_CURRENTLY_CLEANING))
		cleaner_ref = mess_cleaners[key]
	else
		var/turf/tile = get_turf(source)
		if(tile && HAS_TRAIT(tile, TRAIT_CURRENTLY_CLEANING))
			cleaner_ref = mess_cleaners[REF(tile)]
	mess_cleaners -= key
	var/mob/living/cleaner = cleaner_ref?.resolve()
	if(cleaner && is_inmate(cleaner))
		note_work(cleaner, OUTPOST_PRISON_WORK_MOP, key)

// =========================================================================
// 2. WASHING DIRTY PRISON UNIFORMS
// =========================================================================

/// Called from /obj/item/clothing/under/rank/prisoner/outpost/machine_wash() when a dirty uniform is washed
/datum/outpost_prison/proc/on_uniform_washed(mob/user, obj/item/clothing/under/rank/prisoner/outpost/uniform, obj/machinery/washing_machine/washer)
	if(!isliving(user) || !is_inmate(user) || QDELETED(uniform))
		return 0
	var/load_key = washer ? "[REF(washer)]:[world.time]" : "[REF(uniform)]:[world.time]"
	return note_work(user, OUTPOST_PRISON_WORK_WASH, load_key)

// =========================================================================
// 3. DRESSING OR CLOSING PRISONER WOUNDS
// =========================================================================

/// Stocked wing medical gauze: credits an inmate who bandages an unbandaged real wound on a prisoner
/obj/item/stack/medical/gauze/outpost_prison
	merge_type = /obj/item/stack/medical/gauze/outpost_prison

/obj/item/stack/medical/gauze/outpost_prison/try_heal(mob/living/patient, mob/living/user, healed_zone, silent, auto_change_zone, continuous)
	var/obj/item/bodypart/limb = patient?.get_bodypart(healed_zone)
	var/wound_key
	if(limb && !limb.current_gauze && is_outpost_prisoner(patient))
		for(var/datum/wound/wound as anything in limb.wounds)
			wound_key = REF(wound)
			break
	var/amount_before = QDELETED(src) ? 0 : get_amount()
	. = ..()
	var/used = QDELETED(src) || get_amount() < amount_before
	if(used && wound_key && is_outpost_prisoner(patient))
		get_outpost_prison(patient)?.on_prisoner_wound_dressed(user, patient, wound_key)

/// Stocked wing sutures: credits an inmate when suturing closes a bleeding wound on a prisoner
/obj/item/stack/medical/suture/outpost_prison
	merge_type = /obj/item/stack/medical/suture/outpost_prison

/obj/item/stack/medical/suture/outpost_prison/heal_carbon(mob/living/carbon/patient, mob/living/user, healed_zone)
	var/obj/item/bodypart/affecting = patient?.get_bodypart(healed_zone)
	var/datum/wound/bleeding_wound
	if(affecting && is_outpost_prisoner(patient))
		for(var/datum/wound/wound as anything in affecting.wounds)
			if(wound.blood_flow > 0)
				bleeding_wound = wound
				break
	var/wound_key = bleeding_wound ? REF(bleeding_wound) : null
	. = ..()
	if(. && wound_key && is_outpost_prisoner(patient) && (QDELETED(bleeding_wound) || bleeding_wound.blood_flow <= 0))
		get_outpost_prison(patient)?.on_prisoner_wound_dressed(user, patient, wound_key)

/// Credits `user` once per prisoner wound dressed or closed with the wing's stocked supplies
/datum/outpost_prison/proc/on_prisoner_wound_dressed(mob/user, mob/living/carbon/human/npc/outpost_prisoner/patient, wound_key)
	if(!isliving(user) || !is_inmate(user) || QDELETED(patient) || !(patient in prisoners) || !istext(wound_key))
		return 0
	return note_work(user, OUTPOST_PRISON_WORK_WOUND, wound_key)

// =========================================================================
// 4. HANDING IN CONTRABAND (abuse 5: unmarked items credit nothing)
// =========================================================================

/// Marks `thing` as contraband created by this wing's contraband or mail code
/datum/outpost_prison/proc/mark_wing_contraband(obj/item/thing)
	if(!istype(thing) || QDELETED(thing))
		return FALSE
	marked_contraband_refs[REF(thing)] = WEAKREF(thing)
	return TRUE

/// Whether `thing` was created by this wing's contraband or mail code
/datum/outpost_prison/proc/is_wing_contraband(obj/item/thing)
	if(!istype(thing) || QDELETED(thing))
		return FALSE
	var/datum/weakref/known = marked_contraband_refs[REF(thing)]
	return known?.resolve() == thing

/**
 * `inmate` hands `thing` (prison contraband) to an on-duty `guard`. The guard confiscates it out of
 * play; only an item created by this wing's contraband/mail code and never handed in before credits
 * OUTPOST_PRISON_WORK_CONTRABAND_SECONDS (abuse 5). Returns TRUE if the guard took the item.
 */
/datum/outpost_prison/proc/hand_in_contraband(mob/living/inmate, obj/item/thing, mob/living/guard)
	if(QDELETED(inmate) || QDELETED(thing) || QDELETED(guard) || !is_inmate(inmate) || !outpost_prison_is_contraband(thing))
		return FALSE
	if(thing.loc == inmate && !inmate.temporarilyRemoveItemFromInventory(thing))
		return FALSE
	var/was_marked = is_wing_contraband(thing)
	thing.forceMove(null)
	confiscated_contraband_refs += WEAKREF(thing)
	inmate.visible_message(
		span_notice("[inmate] hands [thing] over to [guard]."),
		span_notice("You hand [thing] over to [guard]."),
	)
	if(was_marked)
		note_work(inmate, OUTPOST_PRISON_WORK_CONTRABAND, thing)
	return TRUE

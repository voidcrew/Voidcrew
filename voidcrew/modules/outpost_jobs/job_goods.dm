/**
 * # Outpost jobs: goods and job people
 *
 * Owner: P2. The goods base (a mission item: never confiscated, never destroyed, never gear, refused by cryo,
 * deleted when its job ends) and the setup every job person gets (spec 4.7). Job packages subtype the goods and call
 * these.
 *
 * Job people and the fixers are not part of the ambient crowd's 8-person cap (L24): while the ambient subsystem
 * counts an outpost for its cap (arrive_next(), settle_outpost()), living_npcs() leaves them out, and count_role()
 * puts a fixer back for his own role's count. The fixer's role is tried first, in a pass that ignores the cap.
 * Everywhere else (ducking from a fight, the convoy, the shootout, crowding a tile) they are townspeople like any
 * other.
 */

/// The trait source of a job person's containment ban, lifted while they are dead so the morgue can bag the body
#define FIXER_JOB_PERSON_TRAIT "fixer_job_person"

// =========================================================================
// THE GOODS
// =========================================================================

/// A fixer job's goods (the case, the ledger, the evidence bag, the proof of a hit). Job packages subtype it.
/obj/item/mission_recovery/fixer_goods
	name = "parcel"
	desc = "A small parcel, taped shut."
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF | FREEZE_PROOF
	/// The job it belongs to
	var/datum/weakref/job_ref
	/// In the middle of being equipped: deleting it now would leave it in a hand, so it goes a moment later
	var/handling = FALSE

/obj/item/mission_recovery/fixer_goods/Destroy()
	var/datum/mission/fixer_job/job = job_ref?.resolve()
	if(job && job.goods_ref?.resolve() == src)
		job.goods_ref = null
	job_ref = null
	return ..()

/// The mission shell's lines about contracts are not for a fixer's goods: it is only what it looks like
/obj/item/mission_recovery/fixer_goods/examine(mob/user)
	. = ..()
	var/datum/mission/mission = mission_ref?.resolve()
	if(mission)
		. -= span_notice("Tagged for contract: <b>[mission.name]</b>.")
		if(mission.servant)
			. -= span_notice("Filed to the [mission.servant.name].")
	. -= span_warning("The contract this was tagged for has expired.")

/// Binds this to `job`: it is the job's goods, and an outsider's hand on it spoils the job
/obj/item/mission_recovery/fixer_goods/proc/bind_job(datum/mission/fixer_job/job)
	if(QDELETED(job) || QDELETED(src))
		return
	job_ref = WEAKREF(job)
	mission_ref = WEAKREF(job)
	binding_serial = job.binding_serial
	job.goods_ref = WEAKREF(src)
	job.track(src, scene = FALSE)
	RegisterSignal(src, COMSIG_ITEM_EQUIPPED, PROC_REF(on_fixer_goods_equipped), override = TRUE)

/// The hands rule for goods (spec 4.3): a player off the roster who takes them up (off the floor, out of a bag, off a
/// body, or handed them) spoils the job
/obj/item/mission_recovery/fixer_goods/proc/on_fixer_goods_equipped(datum/source, mob/user, slot)
	SIGNAL_HANDLER
	var/datum/mission/fixer_job/job = job_ref?.resolve()
	if(QDELETED(job) || job.failed || job.completed || !job.active)
		return
	if(!fixer_job_is_player(user) || job.on_roster(user.mind))
		return
	handling = TRUE
	job.spoil(user)
	handling = FALSE

// =========================================================================
// JOB PEOPLE
// =========================================================================

/mob/living/carbon/human/npc/ambient_npc
	/// The fixer job this person was brought for (fixer_job_npc_setup()), or null
	var/datum/weakref/fixer_job_ref

/**
 * A job person at `job`'s outpost: one of its townspeople (set_place(), so the police treat a hit on them as a crime
 * against a civilian, L9), refused by closets, crates, bags and pods while alive (ban_from_containment()), and a job
 * atom the scene reading counts. Teleports, polymorph and type changes are already refused by every ambient NPC
 * (ambient_npc.dm Initialize). Not one of the crowd the outpost's cap counts (L24).
 */
/proc/fixer_job_npc_setup(mob/living/carbon/human/npc/ambient_npc/npc, datum/mission/fixer_job/job)
	if(QDELETED(npc) || QDELETED(job))
		return
	npc.fixer_job_ref = WEAKREF(job)
	var/datum/ambient_place/outpost/place = job.job_outpost ? SSambient_npcs.outpost_place(job.job_outpost) : null
	if(place)
		npc.set_place(place)
	npc.ban_from_containment()
	ADD_TRAIT(npc, TRAIT_NO_CONTAINMENT, FIXER_JOB_PERSON_TRAIT)
	ADD_TRAIT(npc, TRAIT_NO_STORAGE_INSERT, FIXER_JOB_PERSON_TRAIT)
	npc.RegisterSignal(npc, COMSIG_LIVING_DEATH, TYPE_PROC_REF(/mob/living/carbon/human/npc/ambient_npc, fixer_job_person_died), override = TRUE)
	npc.RegisterSignal(npc, COMSIG_LIVING_REVIVE, TYPE_PROC_REF(/mob/living/carbon/human/npc/ambient_npc, fixer_job_person_revived), override = TRUE)
	job.track(npc)

/// Dead, a job person is a body like any other: the morgue crew may bag it
/mob/living/carbon/human/npc/ambient_npc/proc/fixer_job_person_died(datum/source, gibbed)
	SIGNAL_HANDLER
	REMOVE_TRAIT(src, TRAIT_NO_CONTAINMENT, INNATE_TRAIT)
	REMOVE_TRAIT(src, TRAIT_NO_STORAGE_INSERT, INNATE_TRAIT)
	REMOVE_TRAIT(src, TRAIT_NO_CONTAINMENT, FIXER_JOB_PERSON_TRAIT)
	REMOVE_TRAIT(src, TRAIT_NO_STORAGE_INSERT, FIXER_JOB_PERSON_TRAIT)
	UnregisterSignal(src, COMSIG_MOUSEDROP_ONTO)

/mob/living/carbon/human/npc/ambient_npc/proc/fixer_job_person_revived(datum/source, full_heal_flags)
	SIGNAL_HANDLER
	ban_from_containment()
	ADD_TRAIT(src, TRAIT_NO_CONTAINMENT, FIXER_JOB_PERSON_TRAIT)
	ADD_TRAIT(src, TRAIT_NO_STORAGE_INSERT, FIXER_JOB_PERSON_TRAIT)

/// Whether `npc` stands outside the ambient crowd's cap (L24): a fixer, or a person a fixer job brought
/proc/fixer_crowd_exempt(mob/living/carbon/human/npc/ambient_npc/npc)
	return istype(npc, /mob/living/carbon/human/npc/ambient_npc/outpost/fixer) || !!npc?.fixer_job_ref

// ----- the cap (L24): the one rule for the fixer and every job person -----

/datum/ambient_place/outpost
	/// Set while the ambient subsystem counts this outpost against its cap: living_npcs() then leaves out the fixer
	/// and job people
	var/fixer_cap_count = FALSE

/datum/ambient_place/outpost/living_npcs()
	. = ..()
	if(!fixer_cap_count)
		return
	for(var/mob/living/carbon/human/npc/ambient_npc/npc as anything in .)
		if(fixer_crowd_exempt(npc))
			. -= npc

// A fixer still fills his own role while the cap is being counted, or a second one would come
/datum/ambient_place/outpost/count_role(role_type)
	. = ..()
	if(!fixer_cap_count)
		return
	for(var/mob/living/carbon/human/npc/ambient_npc/npc in npcs)
		if(npc.role == role_type && fixer_crowd_exempt(npc) && !QDELETED(npc) && npc.stat != DEAD && !npc.fading)
			.++

// The cap is not the floor: someone settling or stepping off the lift still keeps off a fixer's or job person's tile
/datum/ambient_place/outpost/crowd_count(turf/tile, mob/living/carbon/human/npc/ambient_npc/asker, atom/ignore)
	if(!fixer_cap_count)
		return ..()
	fixer_cap_count = FALSE
	. = ..()
	fixer_cap_count = TRUE

/// `roles` (or every outpost role) split into list(fixer roles, the crowd's roles)
/datum/controller/subsystem/ambient_npcs/proc/fixer_split_roles(list/roles)
	var/list/fixers = list()
	var/list/crowd = list()
	for(var/datum/ambient_outpost_role/role as anything in (roles || get_outpost_roles()))
		if(istype(role, /datum/ambient_outpost_role/fixer))
			fixers += role
		else
			crowd += role
	return list(fixers, crowd)

/// A fixer who is due comes off the lift first, whatever the crowd; then anyone else as before, under the cap
/datum/controller/subsystem/ambient_npcs/arrive_next(datum/ambient_place/outpost/place, list/roles)
	var/obj/structure/overmap/trader_outpost/outpost = place?.outpost()
	if(!outpost)
		return ..()
	var/list/split = fixer_split_roles(roles)
	var/was_counting = place.fixer_cap_count
	place.fixer_cap_count = TRUE
	for(var/datum/ambient_outpost_role/role as anything in split[1])
		if(. || !role.npc_type || !role.applies_to(outpost) || place.role_next_at[role.type] > world.time || place.open_slots(role) <= 0)
			continue
		var/turf/arrival = lift_arrival_turf(outpost)
		if(!arrival)
			break
		place.role_next_at[role.type] = world.time + rand(role.gap_low, role.gap_high)
		. = role.arrive(place, arrival)
	if(!.)
		. = ..(place, split[2])
	if(!QDELETED(place))
		place.fixer_cap_count = was_counting

/// The fixer is settled in a pass of his own before the crowd's, so a full concourse never keeps him away
/datum/controller/subsystem/ambient_npcs/settle_outpost(datum/ambient_place/outpost/place, list/roles, budget = AMBIENT_OUTPOST_SETTLE_PER_FIRE)
	var/obj/structure/overmap/trader_outpost/outpost = place?.outpost()
	if(!outpost || budget <= 0 || !place.needs_settling || place.occupied)
		return ..()
	var/list/split = fixer_split_roles(roles)
	var/was_counting = place.fixer_cap_count
	place.fixer_cap_count = TRUE
	var/made = 0
	for(var/datum/ambient_outpost_role/role as anything in split[1])
		if(made >= budget || !role.npc_type || !role.applies_to(outpost))
			continue
		if(place.open_slots(role) > 0 && role.settle(place))
			made++
	if(made < budget)
		made += ..(place, split[2], budget - made)
	if(!QDELETED(place))
		place.fixer_cap_count = was_counting
	return made

#undef FIXER_JOB_PERSON_TRAIT

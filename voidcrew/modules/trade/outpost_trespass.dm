/**
 * # Armed trespass at trader outposts
 *
 * Past a trader outpost's checkpoint (outpost_checkpoint.dm), a weapon is only carried openly with a
 * weapons permit bought from the checkpoint guard. Anyone else is an armed trespasser when they are:
 * - seen with a gun drawn (held in hand for OUTPOST_ARMED_SIGHTING_GRACE on the outpost's sweep),
 * - heard firing one, or
 * - caught going through a forced checkpoint door.
 * A gun kept holstered or smuggled in a bag is not noticed until it comes out.
 *
 * An armed trespasser is personal (by mind, never their crew): the outpost's turrets treat them as
 * hostile until OUTPOST_TRESPASS_HOSTILE_DURATION after they were last seen armed inside, and every
 * trader, the permit desk and the checkpoint refuse them until OUTPOST_TRESPASS_BAR_DURATION after
 * it. Attacks still go through the ordinary aggression rules (outpost.dm).
 *
 * Goods bought or paid out past the checkpoint come sealed when they hold a gun, so nobody is
 * flagged for carrying home what they just bought.
 */

/obj/structure/overmap/trader_outpost
	/// The interior's scan chambers (outpost_checkpoint.dm), keyed by checkpoint_id
	var/list/datum/outpost_checkpoint/checkpoints = list()
	/// Weapons permits: mind -> world.time it runs out
	var/list/weapon_permits = list()
	/// Permit holders already told their permit ran out: mind -> TRUE
	var/list/permit_lapse_told = list()
	/// Armed trespassers: mind -> world.time they were last seen armed past the checkpoint
	var/list/armed_trespassers = list()
	/// Refused service after armed trespass: mind -> world.time the bar lifts
	var/list/trespass_bars = list()
	/// Someone currently holding a gun past the checkpoint: mind -> world.time first seen doing it
	var/list/armed_sightings = list()
	/// Looping timer for armed_sweep()
	var/armed_sweep_timer
	/// The tile the public network pad goes on, if the map marks one (outpost_network.dm)
	var/turf/network_pad_spot

/// Called from the outpost's Destroy()
/obj/structure/overmap/trader_outpost/proc/clear_checkpoint_state()
	if(armed_sweep_timer)
		deltimer(armed_sweep_timer)
		armed_sweep_timer = null
	QDEL_LIST_ASSOC_VAL(checkpoints)
	weapon_permits.Cut()
	permit_lapse_told.Cut()
	armed_trespassers.Cut()
	trespass_bars.Cut()
	armed_sightings.Cut()
	network_pad_spot = null

/**
 * Builds a scan chamber for every checkpoint_id found in the interior. `doors` and `arches` hold only
 * this concourse's parts, so ids never reach across outposts.
 */
/obj/structure/overmap/trader_outpost/proc/build_checkpoints(list/doors, list/arches)
	var/list/doors_by_id = list()
	var/list/arches_by_id = list()
	for(var/obj/machinery/door/airlock/outpost/checkpoint/door as anything in doors)
		if(door.checkpoint_id)
			LAZYADD(doors_by_id[door.checkpoint_id], door)
	for(var/obj/machinery/outpost_checkpoint_scanner/arch as anything in arches)
		if(arch.checkpoint_id)
			LAZYADD(arches_by_id[arch.checkpoint_id], arch)
	for(var/checkpoint_id in doors_by_id)
		if(checkpoints[checkpoint_id])
			continue
		var/datum/outpost_checkpoint/checkpoint = new(src, checkpoint_id)
		if(!checkpoint.assemble(doors_by_id[checkpoint_id], arches_by_id[checkpoint_id]))
			qdel(checkpoint)
			continue
		checkpoints[checkpoint_id] = checkpoint
	for(var/mob/living/basic/outpost_trader/checkpoint_guard/guard in traders)
		var/datum/outpost_checkpoint/post = checkpoints[guard.checkpoint_id]
		if(post)
			post.guard = guard
			guard.checkpoint = post

/// Whether `place` is past this outpost's checkpoint: its concourse, but not the checkpoint lobby, a scan chamber or the hangars
/obj/structure/overmap/trader_outpost/proc/is_secured_turf(turf/place)
	if(!place || !template_bottom_left || !outpost_template)
		return FALSE
	if(place.z != template_bottom_left.z || place.x < template_bottom_left.x || place.y < template_bottom_left.y)
		return FALSE
	if(place.x >= template_bottom_left.x + outpost_template.width || place.y >= template_bottom_left.y + outpost_template.height)
		return FALSE
	var/area/place_area = place.loc
	return istype(place_area, /area/voidcrew/trader_outpost) && !istype(place_area, /area/voidcrew/trader_outpost/checkpoint)

// ===== PERMITS =====

/// Whether `holder` carries arms here legally, allowing `grace` past the permit's end
/obj/structure/overmap/trader_outpost/proc/has_weapons_permit(mob/living/holder, grace = 0)
	var/datum/mind/holder_mind = holder?.mind
	if(!holder_mind)
		return FALSE
	var/runs_out = weapon_permits[holder_mind]
	return runs_out && world.time < runs_out + grace

/// Issues (or renews) `buyer`'s permit here. Returns the world.time it runs out, or null.
/obj/structure/overmap/trader_outpost/proc/grant_weapons_permit(mob/living/buyer)
	if(!buyer?.mind)
		return null
	weapon_permits[buyer.mind] = world.time + OUTPOST_WEAPONS_PERMIT_DURATION
	permit_lapse_told -= buyer.mind
	log_game("OUTPOST PERMIT: [key_name(buyer)] bought a weapons permit at [name].")
	return weapon_permits[buyer.mind]

// ===== TRESPASS =====

/// Whether the turrets treat `offender_mind` as hostile for armed trespass
/obj/structure/overmap/trader_outpost/proc/is_armed_trespasser(datum/mind/offender_mind)
	var/last_seen = offender_mind && armed_trespassers[offender_mind]
	return last_seen && world.time < last_seen + OUTPOST_TRESPASS_HOSTILE_DURATION

/// Whether `offender_mind` is still refused service for armed trespass
/obj/structure/overmap/trader_outpost/proc/is_trespass_barred(datum/mind/offender_mind)
	var/lifts_at = offender_mind && trespass_bars[offender_mind]
	if(!lifts_at)
		return FALSE
	if(world.time >= lifts_at)
		trespass_bars -= offender_mind
		armed_trespassers -= offender_mind
		return FALSE
	return TRUE

/**
 * `offender` was seen armed past the checkpoint without a permit (or came through a forced door).
 * Starts or extends both clocks and voids any permit. Returns TRUE if they were not already hostile.
 * Never sleeps: it runs from signal handlers.
 */
/obj/structure/overmap/trader_outpost/proc/flag_trespasser(mob/living/offender)
	var/datum/mind/offender_mind = offender?.mind
	if(!offender_mind)
		return FALSE
	var/newly_hostile = !is_armed_trespasser(offender_mind)
	armed_trespassers[offender_mind] = world.time
	trespass_bars[offender_mind] = max(trespass_bars[offender_mind], world.time + OUTPOST_TRESPASS_BAR_DURATION)
	weapon_permits -= offender_mind
	permit_lapse_told -= offender_mind
	armed_sightings -= offender_mind
	if(newly_hostile)
		log_game("OUTPOST TRESPASS: [key_name(offender)] was marked as an armed trespasser at [name] ([AREACOORD(offender)]).")
		to_chat(offender, span_userdanger("The outpost's turrets turn toward you."))
	return newly_hostile

/// Whether `visitor` has a weapon out: in hand, or mounted on the mech they sit in
/proc/outpost_weapon_drawn(mob/living/visitor)
	for(var/obj/item/held in visitor.held_items)
		if(outpost_checkpoint_weapon(held))
			return TRUE
	if(istype(visitor.loc, /obj/vehicle/sealed/mecha))
		var/obj/vehicle/sealed/mecha/mech = visitor.loc
		for(var/obj/item/mecha_parts/mecha_equipment/equipment as anything in mech.flat_equipment)
			if(outpost_checkpoint_weapon(equipment))
				return TRUE
	return FALSE

/obj/structure/overmap/trader_outpost/proc/start_armed_sweep()
	if(armed_sweep_timer)
		return
	armed_sweep_timer = addtimer(CALLBACK(src, PROC_REF(armed_sweep)), OUTPOST_ARMED_SWEEP_INTERVAL, TIMER_STOPPABLE | TIMER_LOOP | TIMER_DELETE_ME)

/**
 * Looks over everyone past the checkpoint for a drawn weapon, and tells permit holders whose permit
 * has run out. A gun has to stay out for OUTPOST_ARMED_SIGHTING_GRACE; anyone restrained or out cold
 * is not judged for what is in their hands. `candidates` defaults to every living player.
 */
/obj/structure/overmap/trader_outpost/proc/armed_sweep(list/candidates = GLOB.alive_player_list)
	if(!template_bottom_left)
		return
	for(var/datum/mind/holder_mind as anything in weapon_permits.Copy())
		var/runs_out = weapon_permits[holder_mind]
		if(world.time < runs_out)
			continue
		if(!permit_lapse_told[holder_mind])
			permit_lapse_told[holder_mind] = TRUE
			if(holder_mind.current)
				to_chat(holder_mind.current, span_warning("Your weapons permit at [name] has run out."))
		if(world.time >= runs_out + OUTPOST_WEAPONS_PERMIT_GRACE)
			weapon_permits -= holder_mind
			permit_lapse_told -= holder_mind
	var/list/still_armed = list()
	for(var/mob/living/visitor as anything in candidates)
		var/datum/mind/visitor_mind = visitor.mind
		if(!visitor_mind || visitor.stat != CONSCIOUS || HAS_TRAIT(visitor, TRAIT_HANDS_BLOCKED))
			continue
		var/turf/where = get_turf(visitor)
		if(!where || where.z != template_bottom_left.z || !is_secured_turf(where))
			continue
		if(!outpost_weapon_drawn(visitor) || has_weapons_permit(visitor, OUTPOST_WEAPONS_PERMIT_GRACE))
			continue
		var/first_seen = armed_sightings[visitor_mind] || world.time
		still_armed[visitor_mind] = first_seen
		// A gun still out on the next sweep flags (or keeps flagging) them
		if(world.time - first_seen >= OUTPOST_ARMED_SIGHTING_GRACE)
			flag_trespasser(visitor)
			still_armed -= visitor_mind
	armed_sightings = still_armed

// ===== SEALED GOODS =====

/// Whether `thing` is a weapon or carries one anywhere inside it
/proc/outpost_holds_weapon(atom/movable/thing)
	for(var/atom/movable/content as anything in thing.get_all_contents())
		if(outpost_checkpoint_weapon(content))
			return TRUE
	return FALSE

/**
 * Goods handed over past the checkpoint come sealed when they are or hold a weapon: an item goes in
 * a sealed case, a cache crate gets a seal on its lid. Returns what should be handed over (the case,
 * or `goods` untouched). Anywhere else, `goods` passes through as it is.
 */
/proc/outpost_seal_goods(atom/movable/goods)
	if(QDELETED(goods))
		return goods
	var/turf/where = get_turf(goods)
	var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(where)
	if(!outpost?.is_secured_turf(where))
		return goods
	if(istype(goods, /obj/structure/closet))
		// Cache crates roll their contents when first opened, so the lid is sealed whatever is inside
		if(istype(goods, /obj/structure/closet/crate/zone_loot) || outpost_holds_weapon(goods))
			goods.AddComponent(/datum/component/outpost_sale_seal)
		return goods
	if(!isitem(goods) || !outpost_holds_weapon(goods))
		return goods
	var/obj/item/outpost_sealed_case/case = new(goods.loc)
	case.seal_in(goods)
	return case

/**
 * A case with the outpost's seal across the latch, holding goods bought past the checkpoint.
 * It opens anywhere outside the checkpoint: the lobby, a hangar, a ship.
 */
/obj/item/outpost_sealed_case
	name = "sealed case"
	desc = "A hard case with an outpost's seal across the latch."
	icon = 'icons/obj/storage/case.dmi'
	icon_state = "lockbox+l"
	inhand_icon_state = "lockbox"
	lefthand_file = 'icons/mob/inhands/equipment/briefcase_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/briefcase_righthand.dmi'
	w_class = WEIGHT_CLASS_BULKY
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/obj/item/outpost_sealed_case/Destroy()
	var/turf/spill = get_turf(src)
	for(var/atom/movable/inside as anything in contents)
		if(spill)
			inside.forceMove(spill)
		else
			qdel(inside)
	return ..()

/obj/item/outpost_sealed_case/proc/seal_in(atom/movable/goods)
	goods.forceMove(src)
	var/obj/item/sealed = goods
	if(istype(sealed))
		w_class = max(sealed.w_class, WEIGHT_CLASS_NORMAL)
	name = "sealed case ([goods.name])"

/obj/item/outpost_sealed_case/examine(mob/user)
	. = ..()
	for(var/atom/movable/inside as anything in contents)
		. += span_notice("The label reads: [inside.name].")

/obj/item/outpost_sealed_case/attack_self(mob/user)
	. = ..()
	if(.)
		return
	var/turf/where = get_turf(src)
	var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(where)
	if(outpost?.is_secured_turf(where))
		balloon_alert(user, "sealed!")
		return TRUE
	playsound(src, 'sound/machines/locktoggle.ogg', 40, TRUE)
	var/list/goods = contents.Copy()
	user.temporarilyRemoveItemFromInventory(src)
	for(var/atom/movable/inside as anything in goods)
		inside.forceMove(where)
		if(isitem(inside))
			user.put_in_hands(inside)
	to_chat(user, span_notice("You break the seal on [src]."))
	qdel(src)
	return TRUE

/// A crate's lid sealed by an outpost: it will not open past that outpost's checkpoint. Gone once it has opened.
/datum/component/outpost_sale_seal

/datum/component/outpost_sale_seal/Initialize()
	if(!istype(parent, /obj/structure/closet))
		return COMPONENT_INCOMPATIBLE

/datum/component/outpost_sale_seal/RegisterWithParent()
	RegisterSignal(parent, COMSIG_CLOSET_PRE_OPEN, PROC_REF(on_pre_open))
	RegisterSignal(parent, COMSIG_ATOM_EXAMINE, PROC_REF(on_examine))

/datum/component/outpost_sale_seal/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_CLOSET_PRE_OPEN, COMSIG_ATOM_EXAMINE))

/datum/component/outpost_sale_seal/proc/on_pre_open(obj/structure/closet/source, mob/living/user, force)
	SIGNAL_HANDLER
	var/turf/where = get_turf(source)
	var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(where)
	if(outpost?.is_secured_turf(where))
		if(user)
			source.balloon_alert(user, "sealed!")
		return BLOCK_OPEN
	qdel(src)
	return NONE

/datum/component/outpost_sale_seal/proc/on_examine(atom/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	examine_list += span_notice("An outpost's seal runs across the lid.")

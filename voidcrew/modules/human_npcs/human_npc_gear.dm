// Human NPC gear lock (owner decision D3): everything a human NPC wears or holds stays on its body
// and never becomes loot. Its designed death drops (human_npc.dm, npc_drop_death_loot()) are the
// only things a player gets from killing one.
//
// How it holds, using tg's own inventory paths rather than special cases per route:
// * A drop that would put the item anywhere but on a human NPC is refused (COMSIG_ITEM_PRE_UNEQUIP):
//   disarm shoves, a held item dropped on a knockdown, gib item drops, a stray transferItemToLoc().
//   The NPC's own moves inside its inventory (magazine into its gun, gun into its holster, a tank
//   into its suit storage) still work, because they end on the NPC.
// * Locked items carry TRAIT_NO_STRIP: tg's strip menu shows their slots as empty and won't take them.
//   The menu still opens, so what isn't gear (a captain's ship key in his pocket) can be taken off a
//   cuffed or downed NPC as off a person.
// * Anything that forces the item out of the body anyway (an arm cut off still holding the gun, a
//   head knocked off with the helmet on, species changes, admin undress) lands outside the NPC, and
//   the item is deleted on the next tick (COMSIG_MOVABLE_MOVED). The wait lets tg code that moves an
//   item twice in one call finish: a tactical reload drops the old magazine on the floor and then
//   puts it back in the NPC's hand.
// * Locked items can't be sold (COMSIG_ITEM_PRE_EXPORT) and carry no materials, so an NPC corpse put
//   through the cargo shuttle or an emagged recycler yields nothing for its kit.
// * When the body is deleted (corpse cleanup, gibbing, a site unloading) the gear goes with it,
//   since /atom/movable/Destroy() deletes contents.
// * A player who ends up in control of an NPC body (a brain transplant) loses its gear at once
//   (human_npc.dm, Login()).
//
// Organs and body parts are the body, not gear: they come off and can be harvested the way a
// player's do (cyberware is the exception: it burns out to scrap, human_npc.dm). Ammunition casings
// are not locked either, so spent brass stays on the floor.
//
// The exceptions, explicit and tested:
// * GLOB.human_npc_not_gear: items whose loss would break something outside the NPC (a ship key, a
//   contract's recovery item, bounty proof, a paper someone has to read). Never locked; they drop at
//   the NPC's feet when it dies.
// * GLOB.human_npc_consumable_gear: things an NPC uses up (grenades, barrier grenades, bottles, syringe
//   darts, medipens, pills, bandages and other medical stacks, thrown spears, stars and bolas). They
//   may leave its body the way a person's would: thrown, fired, dropped or knocked out of its hand.
//   They still never become loot: in anyone's hands or bags but a human NPC's they are deleted, and
//   loose ones go when the NPC that carried them does.
// * NPCs with npc_gear_locked = FALSE lock nothing at all (owner ruling OC-11: prisoners' jumpsuits,
//   contraband and shivs are ordinary items, so shakedowns, confiscation and uniform swaps work). Their
//   guards keep the lock.

/// Items an NPC carries that aren't its gear: never locked, dropped when it dies. Their loss would
/// break something outside the NPC (the cryo pod refuses to delete the first two for the same reason).
GLOBAL_LIST_INIT(human_npc_not_gear, typecacheof(list(
	/obj/item/ship_key,
	/obj/item/mission_recovery,
	/obj/item/bounty_proof,
	/obj/item/paper,
)))

/// Items an NPC uses up: they leave its body like a person's would, but never become loot.
GLOBAL_LIST_INIT(human_npc_consumable_gear, typecacheof(list(
	/obj/item/grenade,
	/obj/item/reagent_containers/cup/glass/bottle,
	/obj/item/reagent_containers/syringe,
	/obj/item/reagent_containers/hypospray/medipen,
	/obj/item/reagent_containers/applicator/pill,
	/obj/item/stack/medical,
	/obj/item/spear,
	/obj/item/throwing_star,
	/obj/item/restraints/legcuffs/bola,
)))

/// Trait source for the gear lock's traits, shared by the element and the consumable component.
#define HUMAN_NPC_GEAR_TRAIT_SOURCE "human_npc_gear_lock"

/// Locks an item to the human NPC body that carries it. Safe to call again on a locked item.
/datum/element/human_npc_gear
	element_flags = ELEMENT_DETACH_ON_HOST_DESTROY

/datum/element/human_npc_gear/Attach(datum/target)
	. = ..()
	if(!isitem(target))
		return ELEMENT_INCOMPATIBLE
	var/obj/item/gear = target
	gear.add_traits(list(TRAIT_HUMAN_NPC_GEAR, TRAIT_NO_STRIP), HUMAN_NPC_GEAR_TRAIT_SOURCE)
	RegisterSignal(gear, COMSIG_ITEM_PRE_UNEQUIP, PROC_REF(on_pre_unequip))
	RegisterSignal(gear, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(gear, COMSIG_ITEM_PRE_EXPORT, PROC_REF(on_pre_export))
	human_npc_gear_strip_materials(gear)

/datum/element/human_npc_gear/Detach(datum/source)
	UnregisterSignal(source, list(COMSIG_ITEM_PRE_UNEQUIP, COMSIG_MOVABLE_MOVED, COMSIG_ITEM_PRE_EXPORT))
	source.remove_traits(list(TRAIT_HUMAN_NPC_GEAR, TRAIT_NO_STRIP), HUMAN_NPC_GEAR_TRAIT_SOURCE)
	return ..()

/// Refuses any drop or hand-over that would leave the NPC's body. Forced moves are let through and
/// caught by on_moved().
/datum/element/human_npc_gear/proc/on_pre_unequip(obj/item/source, force, atom/newloc, no_move, invdrop, silent)
	SIGNAL_HANDLER
	if(force || isnull(newloc) || human_npc_holding(newloc))
		return NONE
	return COMPONENT_ITEM_BLOCK_UNEQUIP

/datum/element/human_npc_gear/proc/on_moved(obj/item/source, atom/old_loc, dir, forced, list/old_locs)
	SIGNAL_HANDLER
	human_npc_gear_check(source)

/datum/element/human_npc_gear/proc/on_pre_export(obj/item/source)
	SIGNAL_HANDLER
	return COMPONENT_STOP_EXPORT

/**
 * Something an NPC uses up (GLOB.human_npc_consumable_gear). It leaves the body like anyone's would:
 * thrown, fired from a dart gun, dropped, knocked from a hand. Lying loose or in flight it stays; in
 * anyone's hands or bags but a human NPC's it is deleted; loose, it goes when its NPC does.
 */
/datum/component/human_npc_consumable
	/// The NPC it was issued to
	var/mob/living/carbon/human/npc/owner

/datum/component/human_npc_consumable/Initialize(mob/living/carbon/human/npc/owner)
	if(!isitem(parent) || !ishumannpc(owner))
		return COMPONENT_INCOMPATIBLE
	src.owner = owner
	RegisterSignal(owner, COMSIG_QDELETING, PROC_REF(on_owner_deleted))
	human_npc_gear_strip_materials(parent)

/datum/component/human_npc_consumable/RegisterWithParent()
	var/obj/item/item = parent
	item.add_traits(list(TRAIT_HUMAN_NPC_CONSUMABLE, TRAIT_NO_STRIP), HUMAN_NPC_GEAR_TRAIT_SOURCE)
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(parent, COMSIG_ITEM_PRE_EXPORT, PROC_REF(on_pre_export))

/datum/component/human_npc_consumable/UnregisterFromParent()
	var/obj/item/item = parent
	item.remove_traits(list(TRAIT_HUMAN_NPC_CONSUMABLE, TRAIT_NO_STRIP), HUMAN_NPC_GEAR_TRAIT_SOURCE)
	UnregisterSignal(parent, list(COMSIG_MOVABLE_MOVED, COMSIG_ITEM_PRE_EXPORT))

/datum/component/human_npc_consumable/Destroy(force)
	if(owner)
		UnregisterSignal(owner, COMSIG_QDELETING)
	owner = null
	return ..()

/datum/component/human_npc_consumable/proc/on_moved(obj/item/source, atom/old_loc, dir, forced, list/old_locs)
	SIGNAL_HANDLER
	human_npc_gear_check(source)

/datum/component/human_npc_consumable/proc/on_pre_export(obj/item/source)
	SIGNAL_HANDLER
	return COMPONENT_STOP_EXPORT

/// Its NPC is gone: a loose one goes too. One still on the NPC is deleted with it anyway.
/datum/component/human_npc_consumable/proc/on_owner_deleted(datum/source)
	SIGNAL_HANDLER
	var/obj/item/item = parent
	UnregisterSignal(owner, COMSIG_QDELETING)
	owner = null
	if(!QDELETED(item) && !human_npc_holding(item))
		qdel(item)

/// The human NPC that `place` is, or is carried by at any depth (a gun in its hand, a magazine in a
/// pouch on its belt, its body in a bag). Null when the chain ends on a turf or in nullspace first.
/proc/human_npc_holding(atom/place)
	while(place && !isturf(place))
		if(ishumannpc(place))
			return place
		place = place.loc
	return null

/// Whether `item` may be where it is: on a human NPC, or for a consumable, also loose or in flight.
/proc/human_npc_gear_allowed_at(obj/item/item)
	if(human_npc_holding(item.loc))
		return TRUE
	if(!HAS_TRAIT(item, TRAIT_HUMAN_NPC_CONSUMABLE))
		return FALSE
	return isturf(item.loc) || istype(item.loc, /obj/projectile)

/// After a move: locked gear that ended up somewhere it may not be is deleted on the next tick, unless
/// it is back where it may be by then.
/proc/human_npc_gear_check(obj/item/item)
	if(QDELING(item) || human_npc_gear_allowed_at(item) || HAS_TRAIT(item, TRAIT_HUMAN_NPC_GEAR_LOST))
		return
	ADD_TRAIT(item, TRAIT_HUMAN_NPC_GEAR_LOST, HUMAN_NPC_GEAR_TRAIT_SOURCE)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(human_npc_gear_settle), item), 0)

/// A locked item that went somewhere it may not be last tick: deleted, unless it is back by now.
/proc/human_npc_gear_settle(obj/item/gear)
	if(QDELETED(gear))
		return
	REMOVE_TRAIT(gear, TRAIT_HUMAN_NPC_GEAR_LOST, HUMAN_NPC_GEAR_TRAIT_SOURCE)
	if(human_npc_gear_allowed_at(gear))
		return
	qdel(gear)

/// Locked gear keeps no salvage value. Material effects (a plasteel helmet's colour and armour) live in
/// custom_materials, so only plain items lose theirs.
/proc/human_npc_gear_strip_materials(obj/item/gear)
	if(length(gear.custom_materials) && !(gear.material_flags & MATERIAL_EFFECTS))
		gear.set_custom_materials(null)

/// Whether `item` is locked to a human NPC's body. For tests and admin tools.
/proc/human_npc_gear_locked(obj/item/item)
	return !QDELETED(item) && HAS_TRAIT(item, TRAIT_HUMAN_NPC_GEAR)

/// Whether `item` is a consumable issued to a human NPC. For tests and admin tools.
/proc/human_npc_gear_consumable(obj/item/item)
	return !QDELETED(item) && HAS_TRAIT(item, TRAIT_HUMAN_NPC_CONSUMABLE)

/**
 * Locks `item` to this NPC's body, or issues it as a consumable, by the lists above. Items that aren't
 * gear, body parts, organs, ammunition casings and abstract items are left alone, and so is everything
 * on an NPC whose gear isn't locked (npc_gear_locked). Use it for anything handed to an NPC after it
 * spawned. Returns TRUE if the item is now locked or issued.
 */
/mob/living/carbon/human/npc/proc/npc_lock_item(obj/item/item)
	if(!npc_gear_locked || QDELETED(item) || isbodypart(item) || isorgan(item) || isammocasing(item) || (item.item_flags & ABSTRACT))
		return FALSE
	if(is_type_in_typecache(item, GLOB.human_npc_not_gear))
		return FALSE
	if(HAS_TRAIT(item, TRAIT_HUMAN_NPC_GEAR) || HAS_TRAIT(item, TRAIT_HUMAN_NPC_CONSUMABLE))
		return TRUE
	if(is_type_in_typecache(item, GLOB.human_npc_consumable_gear))
		item.AddComponent(/datum/component/human_npc_consumable, src)
	else
		item.AddElement(/datum/element/human_npc_gear)
	return TRUE

/// Locks everything the NPC carries: worn, held, in pockets and bags, implants and skillchips.
/mob/living/carbon/human/npc/proc/npc_lock_all_gear()
	for(var/obj/item/item as anything in get_all_contents_type(/obj/item))
		npc_lock_item(item)

/// Deletes every locked or issued item the NPC carries. Used when a player takes over the body.
/mob/living/carbon/human/npc/proc/npc_delete_locked_gear()
	for(var/obj/item/item as anything in get_all_contents_type(/obj/item))
		if(QDELETED(item))
			continue
		if(HAS_TRAIT(item, TRAIT_HUMAN_NPC_GEAR) || HAS_TRAIT(item, TRAIT_HUMAN_NPC_CONSUMABLE))
			qdel(item)

/// Drops what it carries that isn't gear (GLOB.human_npc_not_gear) at its feet, as anyone's would be
/// found on them. Called when it dies, since nobody can search an NPC's pockets.
/mob/living/carbon/human/npc/proc/npc_drop_not_gear()
	var/atom/drop_spot = drop_location()
	if(isnull(drop_spot))
		return
	for(var/obj/item/item as anything in get_all_contents_type(/obj/item))
		if(QDELETED(item) || !is_type_in_typecache(item, GLOB.human_npc_not_gear))
			continue
		if(item.loc == src)
			dropItemToGround(item, force = TRUE)
		else
			item.forceMove(drop_spot)

#undef HUMAN_NPC_GEAR_TRAIT_SOURCE

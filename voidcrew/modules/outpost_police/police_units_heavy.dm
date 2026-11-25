/**
 * # Outpost police: heavy weapons officers
 *
 * Owner decision 62: at five stars a team of two heavy weapons officers (POLICE_UNIT_ARMOUR) joins the response, after
 * the marshal (police_dispatch.dm, dispatch_next_kind()). Each carries one of three anti-armour weapons, by
 * rotation, so the outpost shows all three over a fight: an ion rifle, a rocket launcher or a grenade launcher. Each
 * also carries the zone's ordinary sidearm (the miniature energy gun every officer has) for people on foot.
 *
 * Everything goes through the real tg weapons, the same as a player's: the rounds, the rifle's cell, the reload by
 * hand from the pack, the blast and the EMP. What is theirs alone is when they pull the trigger:
 * - The heavy weapon is only for a mech they fight at lethal force (someone aboard is wanted that hard), in the same
 *   sector as the officer: never from a hangar berth into the concourse through a lift, never at a docked ship.
 *   Anyone on foot gets the sidearm, like any lethal officer. A rocket or shell is never fired at someone on foot.
 * - Clear blast: no shot while anyone the officer would not shoot (townsfolk, traders, officers, crews, a player who
 *   is not wanted at lethal force) is inside the round's real blast radius around the target, under the line of
 *   fire, or a few tiles past the target where a miss would land; nor while any of those tiles is a ship's (an
 *   /area/shuttle). The radius is read from the round: the ion bolt's emp_radius, and outpost_blast_radius below for
 *   rockets and shells. With no clear shot they hold fire and step aside, or back out of their own blast.
 * - The same test runs again on the trigger itself (heavy_try_fire()), so no planning path can fire it otherwise.
 * - A dry launcher with nothing left to load falls back to the sidearm (police_force.dm, set_force()).
 * Their gear is locked to the body like every officer's; their spare rockets and shells are issued as consumables
 * (human_npc_gear.dm), so one knocked loose is deleted in a player's hands and goes when its officer does.
 */

/// The three anti-armour guns a heavy weapons officer may carry
GLOBAL_LIST_INIT(outpost_police_heavy_guns, typecacheof(list(
	/obj/item/gun/energy/ionrifle,
	/obj/item/gun/ballistic/rocketlauncher,
	/obj/item/gun/ballistic/revolver/grenadelauncher,
)))

/// Their rounds: locked to them as consumables, never loot
GLOBAL_LIST_INIT(outpost_police_heavy_ammo, typecacheof(list(
	/obj/item/ammo_casing/rocket,
	/obj/item/ammo_casing/a40mm,
)))

// =========================================================================
// BLAST RADIUS
// =========================================================================

/**
 * How far a round's blast reaches, in tiles: the larger of its explosion's impact and flame ranges (the flash is left
 * out: it blinds, it does not wound). tg hard-codes these in the round's on_hit()/do_boom(), so the values here
 * mirror those calls, and voidcrew_outpost_police_heavy_radius measures the real explosion to keep them honest.
 * Subtypes with their own do_boom() are not measured; the police carry only the base rounds.
 */
/obj/projectile
	var/outpost_blast_radius = 0

/// code/modules/projectiles/projectile/special/rocket.dm, do_boom(): heavy 1, light 2, flame 3
/obj/projectile/bullet/rocket
	outpost_blast_radius = 3

/// code/modules/projectiles/projectile/bullets/grenade.dm, on_hit(): light 2, flame 3
/obj/projectile/bullet/a40mm
	outpost_blast_radius = 3

/// The blast radius of `projectile_type`: an ion bolt's EMP radius, or its outpost_blast_radius; 0 for a plain round
/proc/outpost_police_blast_radius(projectile_type)
	if(!ispath(projectile_type, /obj/projectile))
		return 0
	if(ispath(projectile_type, /obj/projectile/ion))
		var/obj/projectile/ion/bolt = projectile_type
		return max(0, initial(bolt.emp_radius))
	var/obj/projectile/round = projectile_type
	return max(0, initial(round.outpost_blast_radius))

/// The blast radius of the next shot from `gun`: its selected energy shot, or its chambered or magazine round
/proc/outpost_police_gun_blast_radius(obj/item/gun/gun)
	var/projectile_type
	if(istype(gun, /obj/item/gun/energy))
		var/obj/item/gun/energy/energy_gun = gun
		var/obj/item/ammo_casing/energy/shot = energy_gun.ammo_type[energy_gun.select]
		projectile_type = ispath(shot) ? initial(shot.projectile_type) : shot.projectile_type
	else if(istype(gun, /obj/item/gun/ballistic))
		var/obj/item/gun/ballistic/ballistic_gun = gun
		var/obj/item/ammo_casing/round = ballistic_gun.chambered
		if(round?.loaded_projectile)
			projectile_type = round.loaded_projectile.type
		else if(ballistic_gun.magazine)
			var/obj/item/ammo_casing/casing_type = ballistic_gun.magazine.ammo_type
			projectile_type = ispath(casing_type) ? initial(casing_type.projectile_type) : null
	return outpost_police_blast_radius(projectile_type)

// =========================================================================
// KIT
// =========================================================================

/// tg's flameless Dardo with an ordinary firing pin: no backblast to burn whoever stands behind the officer
/obj/item/gun/ballistic/rocketlauncher/nobackblast/outpost_police
	pin = /obj/item/firing_pin

/datum/outpost_police_profile
	/// POLICE_HEAVY_* -> /datum/outfit type for the heavy weapons officers
	var/list/heavy_outfits = list(
		/datum/outfit/outpost_police/armour/halcyon/ion,
		/datum/outfit/outpost_police/armour/halcyon/rocket,
		/datum/outfit/outpost_police/armour/halcyon/grenade,
	)

/datum/outpost_police_profile/quartermain
	heavy_outfits = list(
		/datum/outfit/outpost_police/armour/quartermain/ion,
		/datum/outfit/outpost_police/armour/quartermain/rocket,
		/datum/outfit/outpost_police/armour/quartermain/grenade,
	)

/datum/outpost_police_profile/undertow
	heavy_outfits = list(
		/datum/outfit/outpost_police/armour/undertow/ion,
		/datum/outfit/outpost_police/armour/undertow/rocket,
		/datum/outfit/outpost_police/armour/undertow/grenade,
	)

// ----- outfits -----
// Built from clothing that already exists (npc-outfit skill), each worn look checked on a mannequin. Heavier than
// the tactical officer's: full ballistic plate, a sealed helmet, a gas mask and flash-proof eyewear (abuse M5), the
// usual belt with baton, cuffs and the miniature energy sidearm. The ion rifle rides on the back; a launcher rides in
// the armour's suit storage with its spare rounds in a pack.

/datum/outfit/outpost_police/armour
	name = "Outpost Police: heavy weapons officer"
	suit = /obj/item/clothing/suit/armor/bulletproof
	mask = /obj/item/clothing/mask/gas/sechailer
	glasses = /obj/item/clothing/glasses/sunglasses

/// Halcyon: navy, under a blue Nanotrasen SWAT helmet
/datum/outfit/outpost_police/armour/halcyon
	name = "Outpost Police: Halcyon heavy weapons officer"
	head = /obj/item/clothing/head/helmet/swat/nanotrasen

/datum/outfit/outpost_police/armour/halcyon/ion
	name = "Outpost Police: Halcyon heavy weapons officer (ion rifle)"
	back = /obj/item/gun/energy/ionrifle

/datum/outfit/outpost_police/armour/halcyon/rocket
	name = "Outpost Police: Halcyon heavy weapons officer (rocket launcher)"
	suit_store = /obj/item/gun/ballistic/rocketlauncher/nobackblast/outpost_police
	back = /obj/item/storage/backpack/security
	backpack_contents = list(/obj/item/ammo_casing/rocket = OUTPOST_POLICE_HEAVY_ROCKETS)

/datum/outfit/outpost_police/armour/halcyon/grenade
	name = "Outpost Police: Halcyon heavy weapons officer (grenade launcher)"
	suit_store = /obj/item/gun/ballistic/revolver/grenadelauncher/unrestricted
	back = /obj/item/storage/backpack/security
	backpack_contents = list(/obj/item/ammo_casing/a40mm = OUTPOST_POLICE_HEAVY_SHELLS)

/// Quartermain: corporate grey, in the grey MK.I SWAT suit under a bulletproof helmet
/datum/outfit/outpost_police/armour/quartermain
	name = "Outpost Police: Quartermain heavy weapons officer"
	uniform = /obj/item/clothing/under/rank/security/officer/grey
	suit = /obj/item/clothing/suit/armor/swat
	head = /obj/item/clothing/head/helmet/alt

/datum/outfit/outpost_police/armour/quartermain/ion
	name = "Outpost Police: Quartermain heavy weapons officer (ion rifle)"
	back = /obj/item/gun/energy/ionrifle

/datum/outfit/outpost_police/armour/quartermain/rocket
	name = "Outpost Police: Quartermain heavy weapons officer (rocket launcher)"
	suit_store = /obj/item/gun/ballistic/rocketlauncher/nobackblast/outpost_police
	back = /obj/item/storage/backpack/security
	backpack_contents = list(/obj/item/ammo_casing/rocket = OUTPOST_POLICE_HEAVY_ROCKETS)

/datum/outfit/outpost_police/armour/quartermain/grenade
	name = "Outpost Police: Quartermain heavy weapons officer (grenade launcher)"
	suit_store = /obj/item/gun/ballistic/revolver/grenadelauncher/unrestricted
	back = /obj/item/storage/backpack/security
	backpack_contents = list(/obj/item/ammo_casing/a40mm = OUTPOST_POLICE_HEAVY_SHELLS)

/// The Undertow: black, under the red-striped SWAT helmet
/datum/outfit/outpost_police/armour/undertow
	name = "Outpost Police: Undertow heavy weapons officer"
	uniform = /obj/item/clothing/under/syndicate
	head = /obj/item/clothing/head/helmet/swat

/datum/outfit/outpost_police/armour/undertow/ion
	name = "Outpost Police: Undertow heavy weapons officer (ion rifle)"
	back = /obj/item/gun/energy/ionrifle

/datum/outfit/outpost_police/armour/undertow/rocket
	name = "Outpost Police: Undertow heavy weapons officer (rocket launcher)"
	suit_store = /obj/item/gun/ballistic/rocketlauncher/nobackblast/outpost_police
	back = /obj/item/storage/backpack/security
	backpack_contents = list(/obj/item/ammo_casing/rocket = OUTPOST_POLICE_HEAVY_ROCKETS)

/datum/outfit/outpost_police/armour/undertow/grenade
	name = "Outpost Police: Undertow heavy weapons officer (grenade launcher)"
	suit_store = /obj/item/gun/ballistic/revolver/grenadelauncher/unrestricted
	back = /obj/item/storage/backpack/security
	backpack_contents = list(/obj/item/ammo_casing/a40mm = OUTPOST_POLICE_HEAVY_SHELLS)

// =========================================================================
// THE BODIES
// =========================================================================

/// The ion rifle. The outfit set here is Halcyon's; Initialize() swaps in the zone's.
/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour
	unit_kind = POLICE_UNIT_ARMOUR
	outfit = /datum/outfit/outpost_police/armour/halcyon/ion
	/// POLICE_HEAVY_*: which of the profile's heavy_outfits they wear
	var/heavy_loadout = POLICE_HEAVY_ION

/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/rocket
	outfit = /datum/outfit/outpost_police/armour/halcyon/rocket
	heavy_loadout = POLICE_HEAVY_ROCKET

/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/grenade
	outfit = /datum/outfit/outpost_police/armour/halcyon/grenade
	heavy_loadout = POLICE_HEAVY_GRENADE

/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/Initialize(mapload, datum/human_npc_order/order)
	var/datum/outpost_police_profile/kit = kit_profile()
	var/heavy_outfit = LAZYACCESS(kit.heavy_outfits, heavy_loadout)
	if(ispath(heavy_outfit, /datum/outfit))
		outfit = heavy_outfit
	. = ..()
	RegisterSignal(src, COMSIG_MOB_TRYING_TO_FIRE_GUN, PROC_REF(heavy_try_fire))

/// The dispatch order of their loadouts: an outpost's heavy weapons officers come in this rotation
/datum/outpost_police
	/// POLICE_HEAVY_* the next heavy weapons officer brings
	var/dispatch_heavy_next = POLICE_HEAVY_ION

/// The type of the next heavy weapons officer, turning the rotation
/datum/outpost_police/proc/dispatch_heavy_type()
	var/loadout = dispatch_heavy_next
	dispatch_heavy_next = (loadout % 3) + 1
	switch(loadout)
		if(POLICE_HEAVY_ROCKET)
			return /mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/rocket
		if(POLICE_HEAVY_GRENADE)
			return /mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/grenade
	return /mob/living/carbon/human/npc/ambient_npc/outpost/police/armour

// ----- the rounds are theirs alone -----

/// Their spare rockets and shells are consumables (human_npc_gear.dm): fired or dropped like a person's, never loot
/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/npc_lock_item(obj/item/item)
	if(npc_gear_locked && !QDELETED(item) && isammocasing(item) && is_type_in_typecache(item, GLOB.outpost_police_heavy_ammo))
		if(!HAS_TRAIT(item, TRAIT_HUMAN_NPC_CONSUMABLE))
			item.AddComponent(/datum/component/human_npc_consumable, src)
		return TRUE
	return ..()

// ----- which weapon -----

/// Their anti-armour gun, or null once it is gone
/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/proc/get_heavy()
	for(var/obj/item/gun/gun in get_all_contents())
		if(is_type_in_typecache(gun, GLOB.outpost_police_heavy_guns))
			return gun
	return null

/// The sidearm is the energy gun that is not the ion rifle
/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/get_sidearm()
	var/obj/item/heavy = get_heavy()
	for(var/obj/item/gun/energy/gun in get_all_contents())
		if(gun != heavy)
			return gun
	return null

/// The heavy weapon is their long gun only while their target is a mech they may use it on; otherwise they have none
/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/get_longgun()
	var/obj/item/gun/heavy = get_heavy()
	if(heavy && police_heavy_target_ok(ai_controller?.blackboard[BB_BASIC_MOB_CURRENT_TARGET]))
		return heavy
	return null

/**
 * Whether the heavy weapon is for `target`: a mech this officer fights at lethal force, in their own sector (the
 * concourse and the lobby share a floor). Never across a lift, never from outside.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/proc/police_heavy_target_ok(atom/target)
	if(!police || !ismecha(target) || QDELETED(target))
		return FALSE
	if(force_for(target) < POLICE_FORCE_LETHAL)
		return FALSE
	var/my_sector = police.sector_of(get_turf(src))
	var/their_sector = police.sector_of(get_turf(target))
	if(my_sector == POLICE_SECTOR_OUTSIDE || their_sector == POLICE_SECTOR_OUTSIDE)
		return FALSE
	return my_sector == their_sector || police.dispatch_same_floor(my_sector, their_sector)

/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/police_heavy_barred(atom/target)
	var/obj/item/gun/heavy = get_heavy()
	return heavy && get_longgun() != heavy

/// The heavy weapon held for anyone but a mech it may be used on is not a gun they may fire
/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/police_loaded_gun_for(level)
	var/obj/item/gun/ready = ..()
	if(ready && is_type_in_typecache(ready, GLOB.outpost_police_heavy_guns) && get_longgun() != ready)
		return null
	return ready

/// The heavy weapon goes away whenever it is not the gun for the target
/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/set_force(level)
	var/obj/item/gun/heavy = get_heavy()
	if(heavy && is_holding(heavy) && (level < POLICE_FORCE_LETHAL || get_longgun() != heavy))
		police_put_away(heavy)
	return ..()

/// At lethal force the weapon follows the target: the heavy weapon out for a mech, the sidearm for anyone else
/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/sync_force(level)
	if(level == force && level >= POLICE_FORCE_LETHAL && !HAS_TRAIT(src, TRAIT_HANDS_BLOCKED) && !LAZYLEN(do_afters))
		var/obj/item/gun/heavy = get_heavy()
		var/obj/item/gun/wanted = get_longgun()
		if(wanted && !is_holding(wanted) && police_can_handle_gun(wanted) && (wanted.can_shoot() || (human_npc_can_reload(src, wanted) && world.time >= ai_controller?.blackboard[BB_HUMAN_NPC_ARMING_RETRY_AT])))
			set_force(level)
			return
		if(heavy && is_holding(heavy) && !wanted)
			set_force(level)
			return
	return ..()

// ----- clear blast -----

/// With the heavy weapon in hand, a clear blast first; then the line as for any shot (check_body_block's short look is the line only)
/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/bystander_in_line(atom/target, within = 0, turf/from_turf)
	if(!within)
		var/obj/item/gun/heavy = get_heavy()
		if(heavy && is_holding(heavy))
			var/atom/blocker = police_heavy_blocker(target, heavy, from_turf)
			if(blocker)
				return blocker
	return ..()

/**
 * What spoils a shot of `heavy` at `target`, or null if it is clear: this officer inside the blast; a ship's tile, a
 * wall or a fixture under the line (a round that hits it bursts there); anyone they would not shoot inside the blast
 * around the target, under the line, or on the few tiles past it where a miss flies on (and around where it would
 * burst on a wall there).
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/proc/police_heavy_blocker(atom/target, obj/item/gun/heavy, turf/from_turf)
	var/turf/from = from_turf || get_turf(src)
	var/turf/impact = get_turf(target)
	if(!from || !impact)
		return impact || src
	var/radius = outpost_police_gun_blast_radius(heavy)
	if(get_dist(from, impact) <= radius)
		return src
	var/atom/blocker = police_heavy_area_blocker(impact, radius, target)
	if(blocker)
		return blocker
	for(var/turf/line_turf as anything in outpost_police_shot_line(from, impact))
		if(line_turf == from || line_turf == impact)
			continue
		if(istype(line_turf.loc, /area/shuttle) || line_turf.is_blocked_turf(exclude_mobs = TRUE))
			return line_turf
		for(var/mob/living/other in line_turf)
			if(other != src && other.stat != DEAD && !police_would_shoot(other, POLICE_FORCE_LETHAL))
				return other
	// A miss flies on past the target
	var/distance = max(1, get_dist(from, impact))
	var/turf/far = locate(clamp(impact.x + round((impact.x - from.x) * OUTPOST_POLICE_HEAVY_OVERSHOOT / distance), 1, world.maxx), clamp(impact.y + round((impact.y - from.y) * OUTPOST_POLICE_HEAVY_OVERSHOOT / distance), 1, world.maxy), impact.z)
	for(var/turf/past_turf as anything in outpost_police_shot_line(impact, far))
		if(past_turf == impact)
			continue
		if(istype(past_turf.loc, /area/shuttle))
			return past_turf
		if(past_turf.is_blocked_turf(exclude_mobs = TRUE))
			return police_heavy_area_blocker(past_turf, radius, target)
		for(var/mob/living/other in past_turf)
			if(other.stat != DEAD && other.body_position != LYING_DOWN && !police_would_shoot(other, POLICE_FORCE_LETHAL))
				return other
	return null

/// Within `radius` of `center`: a ship's tile, or anyone alive this officer would not shoot (in a mech, locker or bag too)
/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/proc/police_heavy_area_blocker(turf/center, radius, atom/target)
	for(var/turf/tile as anything in RANGE_TURFS(radius, center))
		if(istype(tile.loc, /area/shuttle))
			return tile
		for(var/mob/living/other in tile.get_all_contents())
			if(other == src)
				return src
			if(other.stat == DEAD || police_would_shoot(other, POLICE_FORCE_LETHAL))
				continue
			return other
	return null

/// Out of their own blast before anything else: a step back from the target; otherwise a step aside, as any officer
/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/police_reposition(atom/target)
	var/obj/item/gun/heavy = get_heavy()
	if(heavy && is_holding(heavy) && get_dist(src, target) <= outpost_police_gun_blast_radius(heavy))
		step_away(src, target)
		return
	return ..()

/**
 * The trigger itself (COMSIG_MOB_TRYING_TO_FIRE_GUN): the heavy weapon fires only at a mech it may be used on, with
 * a clear blast. Whatever planned the shot, nothing else gets through.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/armour/proc/heavy_try_fire(datum/source, obj/item/gun/gun, atom/target, flag, params)
	SIGNAL_HANDLER
	if(mind || client || !is_type_in_typecache(gun, GLOB.outpost_police_heavy_guns))
		return NONE
	if(!police_heavy_target_ok(target) || police_heavy_blocker(target, gun))
		return COMPONENT_CANCEL_GUN_FIRE
	return NONE

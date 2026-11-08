/**
 * # Quickhack kit
 *
 * What one source of quickhacks can do, and how its menu reads. The hacks
 * themselves ([/datum/machine_quickhack], [/datum/machine_masshack]) are
 * stateless singletons shared by everyone; a kit is the per-source half: which
 * of them this source carries, how far it reaches, how long a hack uploads
 * before it lands, and how its cooldowns scale.
 *
 * Two sources use it today:
 * - The Machine Communion boon ([/datum/quickhack_kit/communion], in
 *   voidcrew/modules/antag_ruins/ascension_mech.dm): every original hack, no
 *   upload, cooldowns as written, tooltips with the hack's details. Its click
 *   ability keeps its own range checks; the kit only supplies the hack list
 *   and the menu slices, so the boon plays exactly as it did before the hacks
 *   moved here.
 * - Cyberdecks (voidcrew/modules/cyberware/ware_line_deck.dm): a fixed list per
 *   model, a short range with line of sight, a visible upload, and a cooldown
 *   multiplier. Each deck builds its kit from its own organ vars.
 *
 * Boon-only hacks: Cut the Safeties (the emag effect) and Wake the Machines
 * never run from a kit that has not set [allow_boon_only]. A deck that lists
 * one by mistake simply does not get it.
 */
/datum/quickhack_kit
	/// Quickhack types this source carries, subtypes of [/datum/machine_quickhack].
	/// Menus list them in definition order, not the order here.
	var/list/quickhack_types = list()
	/// Room hack types this source carries, subtypes of [/datum/machine_masshack].
	var/list/masshack_types = list()
	/// Tiles a quickhack reaches.
	var/hack_range = 7
	/// How long a hack uploads before it lands. Zero lands at once.
	var/upload_time = 0
	/// Multiplier on every hack's own cooldown.
	var/cooldown_mult = 1
	/// Whether a quickhack also needs a clear line from the user to its target.
	var/needs_sight = TRUE
	/// Whether a menu slice's tooltip carries the hack's description and
	/// cooldown. Off, a slice shows only the hack's name.
	var/detailed_menu = FALSE
	/// Whether this source may carry the boon-only hacks. Only the boon sets it.
	var/allow_boon_only = FALSE

/datum/quickhack_kit/New(list/quickhack_types, list/masshack_types, hack_range, upload_time, cooldown_mult)
	. = ..()
	if(islist(quickhack_types))
		src.quickhack_types = quickhack_types.Copy()
	if(islist(masshack_types))
		src.masshack_types = masshack_types.Copy()
	if(!isnull(hack_range))
		src.hack_range = hack_range
	if(!isnull(upload_time))
		src.upload_time = upload_time
	if(!isnull(cooldown_mult))
		src.cooldown_mult = cooldown_mult

/// The hacks no kit gets unless it sets [allow_boon_only]: the emag effect and
/// the machines that fight for you.
/datum/quickhack_kit/proc/is_boon_only(hack_type)
	var/static/list/boon_only = list(
		/datum/machine_quickhack/safeties,
		/datum/machine_masshack/wake,
	)
	return (hack_type in boon_only)

/// Whether this kit carries the hack of this type.
/datum/quickhack_kit/proc/carries(hack_type)
	if(!ispath(hack_type) || (!allow_boon_only && is_boon_only(hack_type)))
		return FALSE
	return (hack_type in quickhack_types) || (hack_type in masshack_types)

/// Every quickhack singleton this kit carries, in definition order.
/datum/quickhack_kit/proc/get_quickhacks()
	RETURN_TYPE(/list)
	. = list()
	for(var/datum/machine_quickhack/hack as anything in get_machine_quickhacks())
		if(carries(hack.type) && (hack.type in quickhack_types))
			. += hack

/// Every room hack singleton this kit carries, in definition order.
/datum/quickhack_kit/proc/get_masshacks()
	RETURN_TYPE(/list)
	. = list()
	for(var/datum/machine_masshack/hack as anything in get_machine_masshacks())
		if(carries(hack.type) && (hack.type in masshack_types))
			. += hack

/// The carried quickhack of this exact type, or null.
/datum/quickhack_kit/proc/find_quickhack(hack_type)
	for(var/datum/machine_quickhack/hack as anything in get_quickhacks())
		if(hack.type == hack_type)
			return hack
	return null

/// The carried room hack of this exact type, or null.
/datum/quickhack_kit/proc/find_masshack(hack_type)
	for(var/datum/machine_masshack/hack as anything in get_masshacks())
		if(hack.type == hack_type)
			return hack
	return null

/// Carried quickhacks this target would accept right now.
/datum/quickhack_kit/proc/applicable_quickhacks(atom/target, mob/living/user)
	RETURN_TYPE(/list)
	. = list()
	if(QDELETED(target) || !isliving(user))
		return
	for(var/datum/machine_quickhack/hack as anything in get_quickhacks())
		if(hack.valid_for(target, user))
			. += hack

/// Carried room hacks that have something to work on from this spot.
/datum/quickhack_kit/proc/applicable_masshacks(mob/living/user, turf/center)
	RETURN_TYPE(/list)
	. = list()
	if(isnull(center) || !isliving(user))
		return
	for(var/datum/machine_masshack/hack as anything in get_masshacks())
		if(hack.available(user, center))
			. += hack

/// Whether the target is close enough, on the same level and, if this kit
/// needs it, in a clear line from the user.
/datum/quickhack_kit/proc/in_reach(mob/living/user, atom/target)
	var/turf/source_turf = get_turf(user)
	var/turf/target_turf = get_turf(target)
	if(isnull(source_turf) || isnull(target_turf) || source_turf.z != target_turf.z)
		return FALSE
	if(get_dist(source_turf, target_turf) > hack_range)
		return FALSE
	return !needs_sight || can_see(source_turf, target_turf, hack_range)

/// The cooldown this hack costs from this kit.
/datum/quickhack_kit/proc/hack_cooldown(datum/hack)
	var/base = 0
	if(istype(hack, /datum/machine_quickhack))
		var/datum/machine_quickhack/quick = hack
		base = quick.cooldown
	else if(istype(hack, /datum/machine_masshack))
		var/datum/machine_masshack/room = hack
		base = room.cooldown
	return round(base * cooldown_mult)

/// One radial slice for a hack. With [detailed_menu] off it carries the name
/// alone; on, the tooltip reads exactly as the boon's always has.
/datum/quickhack_kit/proc/menu_option(datum/hack)
	var/datum/radial_menu_choice/option = new()
	if(istype(hack, /datum/machine_quickhack))
		var/datum/machine_quickhack/quick = hack
		option.image = image(icon = quick.radial_icon, icon_state = quick.radial_icon_state)
		option.name = quick.name
		if(detailed_menu)
			option.info = "[quick.desc] ([round(hack_cooldown(quick) / 10)] second cooldown.)"
	else if(istype(hack, /datum/machine_masshack))
		var/datum/machine_masshack/room = hack
		option.image = image(icon = room.radial_icon, icon_state = room.radial_icon_state)
		option.name = room.name
		if(detailed_menu)
			option.info = "[room.desc] ([round(hack_cooldown(room) / 600)] minute cooldown.)"
	return option

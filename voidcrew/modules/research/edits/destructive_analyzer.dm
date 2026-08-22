/**
 * Ammunition reverse-engineering.
 *
 * Destroying a real cartridge, magazine or ammo box in a destructive analyzer teaches the
 * linked techweb the lathe design that builds that exact item, so a crew that finds ammo in
 * the field can fabricate more of it aboard instead of flying back to a ruin printer.
 *
 * Rules:
 * - The sample is consumed. The analyzer destroys it either way, so this rides on the normal
 *   deconstruction and costs nothing extra.
 * - It is strictly per-type. A .45 magazine teaches the .45 magazine and the .45 casing it
 *   happens to be loaded with, and nothing else. There is no "unlock all ammo" step.
 * - Only designs that a techweb-linked lathe can actually print (PROTOLATHE / AWAY_LATHE) are
 *   reachable, and only through the ship's own techweb - nothing here touches the global
 *   autolathe techweb.
 * - Designs that live in a hidden or BEPIS-experimental research node (upstream's Illegal
 *   Technology node, the Donk flechette) are excluded: contraband tech is not something you
 *   get by dropping a magazine in a box. Explicit ordnance exclusions are listed below.
 * - Lookup is by exact typepath, so a spent casing teaches nothing - the sample has to be a
 *   live round or a real magazine, not floor litter.
 * - Ammunition with no design datum at all teaches nothing. voidcrew/modules/research/designs/
 *   ammo_designs.dm adds designs for the calibers crews actually carry, and each blueprint
 *   gun's own ammo design lives with the gun in voidcrew/modules/weapons_bench/.
 */

/// Ammunition that is never reverse-engineerable no matter what design exists for it.
/// Explosive ordnance and energy "casings", which are gun internals rather than ammunition.
GLOBAL_LIST_INIT(ammo_reverse_engineering_blacklist, typecacheof(list(
	/obj/item/ammo_box/a40mm,
	/obj/item/ammo_casing/a40mm,
	/obj/item/ammo_casing/energy,
	/obj/item/ammo_casing/rocket,
	/obj/item/ammo_casing/shotgun/frag12,
	/obj/item/ammo_casing/shotgun/meteorslug,
	/obj/item/ammo_casing/shotgun/pulseslug,
)))

/**
 * Adds every ammunition typepath [thing] is evidence of into [sample_types].
 *
 * A casing is evidence of itself. A magazine or ammo box is evidence of itself plus whatever
 * rounds it is holding - stored_ammo entries are lazily loaded, so they can be typepaths or
 * instances and both have to be handled.
 */
/proc/collect_ammo_sample_types(atom/movable/thing, list/sample_types)
	if(istype(thing, /obj/item/ammo_casing))
		sample_types[thing.type] = TRUE
		return
	if(!istype(thing, /obj/item/ammo_box))
		return
	var/obj/item/ammo_box/box = thing
	sample_types[box.type] = TRUE
	for(var/stored_round in box.stored_ammo)
		if(ispath(stored_round, /obj/item/ammo_casing))
			sample_types[stored_round] = TRUE
		else if(istype(stored_round, /obj/item/ammo_casing))
			var/obj/item/ammo_casing/loaded = stored_round
			sample_types[loaded.type] = TRUE

/// Whether [design] is something a destructive analyzer is allowed to hand out.
/proc/can_reverse_engineer_ammo_design(datum/design/design)
	if(!ispath(design.build_path, /obj/item/ammo_casing) && !ispath(design.build_path, /obj/item/ammo_box))
		return FALSE
	// Has to be printable somewhere the ship's own techweb feeds. Autolathes read a global
	// autounlocking techweb, so an autolathe-only design would be unlocked into a void.
	if(!(design.build_type & (PROTOLATHE | AWAY_LATHE)))
		return FALSE
	if(is_type_in_typecache(design.build_path, GLOB.ammo_reverse_engineering_blacklist))
		return FALSE
	for(var/node_id in design.unlocked_by)
		var/datum/techweb_node/node = SSresearch.techweb_node_by_id(node_id)
		if(node.hidden || node.experimental || node.illegal_mech_node)
			return FALSE
	return TRUE

/**
 * Every design [web] would learn by destructively analyzing [sample], including its contents.
 * Returns a list of design datums, already filtered against what [web] knows.
 */
/proc/get_reverse_engineerable_ammo_designs(obj/item/sample, datum/techweb/web)
	var/list/designs = list()
	if(QDELETED(sample) || isnull(web))
		return designs
	var/list/sample_types = list()
	for(var/atom/movable/thing as anything in sample.get_all_contents())
		collect_ammo_sample_types(thing, sample_types)
	for(var/sample_type in sample_types)
		for(var/datum/design/design as anything in SSresearch.item_to_design[sample_type])
			if(web.researched_designs[design.id])
				continue
			if(!can_reverse_engineer_ammo_design(design))
				continue
			designs |= design
	return designs

/obj/machinery/rnd/destructive_analyzer/examine(mob/user)
	. = ..()
	if(!in_range(user, src) && !isobserver(user))
		return
	. += span_notice("Ammunition can be reverse-engineered: destroying a cartridge, magazine or ammo box teaches the linked research server how to fabricate it.")

/obj/machinery/rnd/destructive_analyzer/ui_data(mob/user)
	. = ..()
	var/list/reverse_engineerable = list()
	for(var/datum/design/design as anything in get_reverse_engineerable_ammo_designs(loaded_item, stored_research))
		reverse_engineerable += design.name
	.["reverse_engineerable"] = reverse_engineerable

/obj/machinery/rnd/destructive_analyzer/destroy_item(gain_research_points = FALSE)
	// Grab this before the parent qdels the sample and nulls loaded_item.
	var/list/datum/design/learning = get_reverse_engineerable_ammo_designs(loaded_item, stored_research)
	. = ..()
	if(!. || !length(learning))
		return
	var/list/learned = list()
	for(var/datum/design/design as anything in learning)
		if(!stored_research.add_design(design, custom = TRUE))
			continue
		learned += design.name
		log_research("[design.name] ([design.id]) was reverse-engineered from a sample in [src] at [AREACOORD(src)].")
		SSblackbox.record_feedback("tally", "ammo_reverse_engineered", 1, design.id)
	if(!length(learned))
		return
	say("Ammunition reverse-engineered. [english_list(learned)] fabrication is now available on linked lathes.")
	playsound(src, 'sound/machines/beep/twobeep_high.ogg', 50, TRUE)

/**
 * # Verdigris wards: the four layer gates
 *
 * The raid's structure in one object. Each ward stands in one defense layer,
 * holds that layer's id-matched poddoors shut, and sweeps the layer on a slow
 * cadence for surviving garrison. When the last of the dead in its hall stops
 * moving, the ward guts out and the doors roll back. There is no console, no
 * hack, no welder: clearing the layer IS the key, which is what makes the lair
 * a four-stage fight instead of a corridor sprint to the boss.
 *
 * Door control goes through the site (lich_site.dm set_ward_doors) on mapped
 * poddoor ids, exactly like the colosseum drives its arena gates, so a mapper
 * can wire extra buttons to the same ids and everything stays coherent.
 *
 * These are machines rather than structures purely for the free SSmachines
 * processing hook; they use no power and cannot be broken (the whole lair is
 * built out of indestructible turfs, and a ward that could be smashed would be
 * a ward that could be skipped).
 */

/// Factions a ward counts as garrison, listed rather than excluded. Ilthuun and
/// everything he raises carry FACTION_LICH; the lair's mapped spawners fill the
/// halls with skeletons (FACTION_SKELETON), zombies (FACTION_HOSTILE) and
/// constructs (FACTION_CULT). Counting by an allowlist means a crew pet, a
/// borrowed bot or anything else a raiding party drags in cannot be the reason a
/// hall reads as "not yet cleared", that failure mode is invisible from inside
/// the lair and there is no console, no hack and no welder to undo it.
GLOBAL_LIST_INIT(lich_ward_garrison_factions, list(
	FACTION_LICH,
	FACTION_SKELETON,
	FACTION_CULT,
	FACTION_HOSTILE,
))

/obj/machinery/lich_ward
	name = "verdigris ward"
	desc = "A shard of green crystal grown through a knot of finger-bones, turning slowly a hand's width off the deck. It hums, and while it hums the doors behind it will not move."
	icon = 'icons/obj/antags/cult/structures.dmi'
	icon_state = "pylon"
	color = LICH_GREEN
	density = TRUE
	anchored = TRUE
	max_integrity = 500
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF
	use_power = NO_POWER_USE
	idle_power_usage = 0
	light_range = 3
	light_power = 1.4
	light_color = LICH_GREEN

	/// Mapped poddoor id this ward holds shut. Set per subtype.
	var/ward_id
	/// Area typepath of the layer this ward is watching. Set per subtype;
	/// falls back to whatever area the ward is standing in.
	var/layer_area
	/// Layer name for player-facing messages.
	var/layer_name = "hall"
	/// TRUE once the layer was cleared and the doors were rolled back.
	var/unsealed = FALSE
	/// Weakref to the overmap site, set by its link_interior().
	var/datum/weakref/site_ref
	/// world.time of the next garrison sweep. Seeded with a startup grace so a
	/// ward can never read its hall as empty before the hall's mobs have run
	/// their own Initialize (SSatoms has no ordering guarantee between them).
	var/next_scan = 0

/obj/machinery/lich_ward/Initialize(mapload)
	. = ..()
	next_scan = world.time + LICH_WARD_STARTUP_GRACE

/obj/machinery/lich_ward/Destroy()
	site_ref = null
	return ..()

/// Adopts this ward into a site. Called by the site's link_interior() right
/// after the template loads; also re-seals the gate, so a poddoor that a mapper
/// left open can't hand raiders a free layer.
/obj/machinery/lich_ward/proc/link_site(obj/structure/overmap/space_ruin/lich_lair/site)
	if(QDELETED(site))
		return
	site_ref = WEAKREF(site)
	if(!unsealed)
		site.set_ward_doors(ward_id, FALSE)

/obj/machinery/lich_ward/examine(mob/user)
	. = ..()
	if(unsealed)
		. += span_notice("The crystal is dark and still. Whatever it was holding shut is open now.")
	else
		. += span_boldwarning("It is humming. The [layer_name] is not clear. Something in here is still standing.")
	var/obj/structure/overmap/space_ruin/lich_lair/site = site_ref?.resolve()
	if(!site)
		return
	var/sealed = site.sealed_ward_count()
	if(sealed)
		. += span_boldwarning("[sealed] ward[sealed == 1 ? "" : "s"] still humming somewhere in the Verdigris.")
	else
		. += span_boldnotice("Nothing is humming any more. Every seal in the Verdigris is dark.")

/obj/machinery/lich_ward/attack_hand(mob/user, list/modifiers)
	. = ..()
	if(.)
		return
	if(unsealed)
		balloon_alert(user, "already dark")
		return TRUE
	to_chat(user, span_warning("Your hand passes through the crystal's glow and comes back cold. The hum doesn't falter. You aren't going to open this by hand."))
	playsound(src, 'sound/effects/magic/curse.ogg', 40, TRUE)
	return TRUE

/obj/machinery/lich_ward/update_icon_state()
	icon_state = unsealed ? "pylon_off" : "pylon"
	return ..()

/obj/machinery/lich_ward/process()
	if(unsealed)
		return PROCESS_KILL
	if(world.time < next_scan)
		return
	next_scan = world.time + LICH_WARD_SCAN_INTERVAL
	if(garrison_remaining())
		return
	unseal()
	return PROCESS_KILL

/// The area instance this ward is watching. Layer areas inherit UNIQUE_AREA
/// from /area/ruin/space, so the typepath resolves straight to the one live
/// instance; a ward with no layer_area set watches wherever it was mapped.
/obj/machinery/lich_ward/proc/get_layer_area()
	var/area/watched = layer_area ? GLOB.areas_by_type[layer_area] : null
	return watched || get_area(src)

/**
 * How many of Ilthuun's dead are still standing in this ward's layer.
 *
 * Walks GLOB.mob_living_list rather than the layer's turfs: the living list is
 * short and the turf list is not, and this runs every LICH_WARD_SCAN_INTERVAL
 * on a permanently loaded interior. Players never count (a raider standing in
 * the hall must not hold their own gate shut), nor does anything dead, nor
 * anything outside the garrison factions above.
 */
/obj/machinery/lich_ward/proc/garrison_remaining()
	var/area/watched = get_layer_area()
	if(!watched)
		return 0
	. = 0
	for(var/mob/living/candidate as anything in GLOB.mob_living_list)
		if(QDELETED(candidate) || candidate.stat == DEAD)
			continue
		if(candidate.client || candidate.mind) // players and player-controlled mobs are raiders, not garrison
			continue
		if(!faction_check(candidate.faction, GLOB.lich_ward_garrison_factions))
			continue
		if(get_area(candidate) != watched)
			continue
		.++

/// Layer cleared: kill the hum, roll the doors back, and tell everyone how much
/// further there is to go.
/obj/machinery/lich_ward/proc/unseal()
	if(unsealed)
		return
	unsealed = TRUE
	set_light_on(FALSE)
	update_appearance()

	var/obj/structure/overmap/space_ruin/lich_lair/site = site_ref?.resolve()
	site?.set_ward_doors(ward_id, TRUE)

	playsound(src, 'sound/effects/magic/summon_magic.ogg', 65, TRUE)
	visible_message(span_boldwarning("The ward's hum drops out of the air and the green goes out of the crystal. Somewhere ahead, heavy doors roll back."))

	var/sealed = site?.sealed_ward_count()
	if(isnull(sealed))
		return
	if(sealed > 0)
		visible_message(span_boldwarning("[sealed] ward[sealed == 1 ? "" : "s"] still humming deeper in the Verdigris."))
	else
		visible_message(span_boldnotice("Nothing is humming any more. Every seal in the Verdigris is dark."))
	log_game("LICH: ward '[ward_id]' unsealed ([layer_name] cleared); [sealed] ward(s) remaining.")

// ===== THE FOUR LAYERS =====
//
// One ward per defense layer, in the order a boarding party meets them.
//
// MAPPING CONTRACT: the poddoors tagged with a ward's id are the doors leading
// OUT of that ward's own layer. So "lich_ward_atrium" is the gate at the far end
// of the atrium (atrium -> ossuary), and "lich_ward_sanctum" is the gate at the
// far end of the sanctum: the reliquary, which only opens once Ilthuun himself
// is dead, because he is standing in the layer that ward is watching. Three
// wards gate progress; the fourth gates the payout.

/// Layer 1: the breach hall the docking tube opens onto.
/obj/machinery/lich_ward/atrium
	name = "verdigris ward of the atrium"
	ward_id = LICH_WARD_ATRIUM
	layer_area = /area/ruin/space/has_grav/powered/lich_lair/atrium
	layer_name = "atrium"

/// Layer 2: the stacked bone galleries.
/obj/machinery/lich_ward/ossuary
	name = "verdigris ward of the ossuary"
	ward_id = LICH_WARD_OSSUARY
	layer_area = /area/ruin/space/has_grav/powered/lich_lair/ossuary
	layer_name = "ossuary"

/// Layer 3: the warrens his risen dead are quarried out of. Its gate is the
/// sanctum door, clear the warrens and the boss fight starts.
/obj/machinery/lich_ward/warrens
	name = "verdigris ward of the warrens"
	ward_id = LICH_WARD_WARRENS
	layer_area = /area/ruin/space/has_grav/powered/lich_lair/warrens
	layer_name = "warrens"

/// Layer 4: the sanctum itself, and the last hum in the lair. Ilthuun stands in
/// the layer this ward is watching, so it cannot gutter out until he does,
/// which is exactly the point: it seals the reliquary his garb is kept in.
/obj/machinery/lich_ward/sanctum
	name = "verdigris ward of the sanctum"
	desc = "The largest of the wards. It hums lower than the others, low enough that you feel it in your teeth before you hear it."
	ward_id = LICH_WARD_SANCTUM
	layer_area = /area/ruin/space/has_grav/powered/lich_lair/sanctum
	layer_name = "sanctum"
	light_range = 4

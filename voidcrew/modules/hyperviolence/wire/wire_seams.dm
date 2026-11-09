// Widowline x hyperviolence: the hooks the wire needs in the gore parts, chained here rather than edited
// into them. Everything a wire sever changes about blood and stumps is in this file:
// - A clean cut (TRAIT_HV_CLEAN_CUT, held only while a wire's damage is being applied) throws no flying
//   hitsplatter, no heavy-hit or crit spray and no puff off a wound it reopens, puts no blood on the floor or on
//   the wielder at the hit. The wounds and the blood lost are tg's as ever. A limb it takes
//   off bleeds when it slides off (wire_sever_fx.dm); otherwise the wound bleeds as any does.
// - tg's own wound roll never tears a limb off mid wire cut; the wire takes that limb off clean after.
// - A limb taken by the wire sprays nothing when it leaves (hv_sever_spray); the wire lays its own streak.
// - A wire stump can be held back for the beat the severed arm is still drawn on, and can be seared shut.
// - hv_wire_take_part(): tg's dismemberment without the throw and the fan of blood.

/mob/living
	/// While not null, a limb coming off throws no spray of its own (blood/blood_spray.dm). Set around a wire sever.
	var/hv_sever_spray
	/// A limb tg's wound roll would have torn off during a wire cut. The wire takes it off clean once the hit is done.
	var/obj/item/bodypart/hv_wire_owed_sever

/mob/living/carbon
	/// Body zone -> world.time its stump may be drawn. A wire cut holds the stump back while the limb still shows. Lazy.
	var/list/hv_stump_reveal_at
	/// Body zones whose stump a hot wire seared shut. Lazy.
	var/list/hv_stump_burnt

// ---- Clean cuts ----

/mob/living/carbon/spray_blood(splatter_direction, splatter_strength = 3)
	if(HAS_TRAIT(src, TRAIT_HV_CLEAN_CUT))
		return
	return ..()

/mob/living/hv_blood_on_damaged(datum/source, damage_dealt, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, attacking_item, wound_clothing)
	SIGNAL_HANDLER
	if(HAS_TRAIT(src, TRAIT_HV_CLEAN_CUT))
		return
	return ..()

/mob/living/add_splatter_floor(turf/splatter_turf, small_drip = FALSE)
	if(HAS_TRAIT(src, TRAIT_HV_CLEAN_CUT))
		return null
	return ..()

// tg's puff of blood off a wound that is hit again (an open puncture), and the heavy spray of a crit landing.
/mob/living/create_splatter(splatter_dir = pick(GLOB.cardinals))
	if(HAS_TRAIT(src, TRAIT_HV_CLEAN_CUT))
		return
	return ..()

/mob/living/hv_blood_throw(spray_dir, strength = 3)
	if(HAS_TRAIT(src, TRAIT_HV_CLEAN_CUT))
		return FALSE
	return ..()

// tg's hit puts blood on the floor and on whoever stands next to the body at the moment of the blow. The wire is a
// pace away and cuts clean: the blood comes after (wire_sever_fx.dm), and the wire carries its own (wire_held.dm).
/mob/living/attack_effects(damage_done, hit_zone, armor_block, obj/item/attacking_item, mob/living/attacker)
	if(HAS_TRAIT(src, TRAIT_HV_CLEAN_CUT) && istype(attacking_item, /obj/item/melee/cyberware_monowire))
		// The hit's message still reads before what follows it (hit_lines.dm).
		hv_flush_hit()
		return FALSE
	return ..()

/mob/living/carbon/hv_blood_on_limb_removed(datum/source, obj/item/bodypart/removed_limb, special, dismembered)
	SIGNAL_HANDLER
	if(!isnull(hv_sever_spray))
		return
	return ..()

// tg tears an arm or leg off when its wound roll says so, flinging it with a fan of blood. Mid wire cut it
// stays on for now and the wire takes it off clean once the hit is resolved (hv_wire_settle_owed_sever()).
/datum/wound/loss/apply_dismember(obj/item/bodypart/dismembered_part, wounding_type = WOUND_SLASH, outright = FALSE, attack_direction)
	var/mob/living/carbon/cut = dismembered_part?.owner
	if(cut && HAS_TRAIT(cut, TRAIT_HV_CLEAN_CUT) && (dismembered_part.body_zone in GLOB.hv_wire_sever_zones) && dismembered_part.can_dismember())
		cut.hv_wire_owed_sever = dismembered_part
		qdel(src)
		return FALSE
	return ..()

/// The limbs a wire takes off. The head is the garrote's; the chest never comes off.
GLOBAL_LIST_INIT(hv_wire_sever_zones, list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))

/**
 * The short spray of a clean cut: a few drops thrown from src toward spray_dir, landing within a tile or so in a
 * narrow fan. No streak along the floor; the shared spray (hv_blood_throw()) lays a straight line, a wire's never
 * does. `tiles` sets how far the furthest drops reach. From the stump of `zone` if given, shorter, and never straight
 * away from the viewer: drops thrown that way would read as leaving the head. Returns TRUE if anything was sprayed.
 */
/mob/living/proc/hv_wire_spray(spray_dir, tiles = 2, zone)
	if(QDELETED(src) || !isturf(loc) || can_bleed(BLOOD_COVER_TURFS) != BLEED_SPLATTER)
		return FALSE
	tiles = clamp(round(tiles), 1, 2)
	if(!spray_dir)
		spray_dir = pick(GLOB.alldirs)
	hv_blood_spray_until = world.time + 0.4 SECONDS
	hv_blood_spray_strength = max(hv_blood_spray_strength, tiles)
	if(!zone)
		var/list/reach = tiles > 1 ? list(10, 16, 22, 30, 38) : list(8, 12, 16, 20)
		wire_blood_burst(loc, pixel_x, pixel_y - 2, wire_blood_color(src), get_blood_dna_list(), 6, dir2angle(spray_dir), 45, reach)
		return TRUE
	// From the stump: drops only, no splat; a clean cut. Short, so they land by the body, on the floor round the feet
	// of a body standing.
	var/list/stump = wire_zone_point(src, zone)
	var/lying = body_position == LYING_DOWN
	var/floor_y = lying ? stump[2] : -10
	// A limb on the far side of a body side on: its stump is behind the body, and so are the drops leaving it.
	var/behind = !lying && wire_limb_far(zone, dir)
	if(!(spray_dir & NORTH))
		hv_wire_drops(stump, floor_y, 6, dir2angle(spray_dir), 50, tiles > 1 ? 22 : 14, behind)
		return TRUE
	// Away from the viewer: out to the sides instead, short, landing on the floor beside the feet.
	if(!lying)
		floor_y = -13
	if(spray_dir & (EAST | WEST))
		hv_wire_drops(stump, floor_y, 6, (spray_dir & EAST) ? 90 : 270, 20, 16, behind)
		return TRUE
	hv_wire_drops(stump, floor_y, 3, 95, 15, 16, behind)
	hv_wire_drops(stump, floor_y, 3, 265, 15, 16, behind)
	return TRUE

/**
 * `count` drops thrown from `from` (x, y pixels off the middle of src's tile) on `bearing` (degrees from north), give
 * or take `spread`, each landing as a drop on the floor up to `reach` pixels from (from x, `floor_y`). Spread evenly
 * over the cone and over the reach, each with a little give, and dealt out at random so that no two neighbours in
 * the cone are also neighbours in reach: they land as a scatter, not a line. They leave a beat apart. `behind` draws
 * them all behind the bodies they pass.
 */
/mob/living/proc/hv_wire_drops(list/from, floor_y, count, bearing, spread, reach, behind = FALSE)
	var/blood_color = wire_blood_color(src)
	var/list/blood_dna = get_blood_dna_list()
	var/list/reaches = list()
	for(var/i in 1 to count)
		reaches += round(reach * (0.3 + 0.7 * i / count))
	shuffle_inplace(reaches)
	var/slice = count > 1 ? 2 * spread / count : 0
	for(var/i in 1 to count)
		var/angle = bearing - spread + slice * (i - 0.5) + rand(-slice, slice) / 2
		var/distance = reaches[i] + rand(-3, 3)
		var/land_x = from[1] + round(sin(angle) * distance) + rand(-3, 3)
		var/land_y = floor_y + round(cos(angle) * distance) + rand(-3, 3)
		var/flight = round(1.5 + distance / 14, 0.5)
		// Never all at once: a burst of drops leaving one point at once reads as a red star on the stump.
		var/delay = pick(0.05, 0.1, 0.15, 0.2) SECONDS
		new /obj/effect/temp_visual/wire_blood_drop(loc, list(from[1], from[2], land_x, land_y, 2 + rand(0, 4), flight, delay, behind || cos(angle) > 0.3), blood_color, blood_dna)

// ---- Stumps: held back, and seared ----

/mob/living/carbon/hv_update_gore_overlays()
	// A limb back on forgets how its stump was cut.
	for(var/zone in hv_stump_burnt?.Copy())
		if(get_bodypart(zone))
			LAZYREMOVE(hv_stump_burnt, zone)
	// A held-back stump whose time has come shows now, whatever else changed.
	for(var/zone in hv_stump_reveal_at?.Copy())
		if(get_bodypart(zone) || world.time >= hv_stump_reveal_at[zone])
			LAZYREMOVE(hv_stump_reveal_at, zone)
			hv_gore_key = null
	return ..()

/mob/living/carbon/hv_build_gore_images(list/stumps, skull, blood_color)
	var/list/shown = stumps
	if(LAZYLEN(hv_stump_reveal_at) && length(stumps))
		shown = stumps.Copy()
		for(var/zone in hv_stump_reveal_at)
			if(world.time < hv_stump_reveal_at[zone])
				shown -= zone
	. = ..(shown, skull, blood_color)
	if(!LAZYLEN(hv_stump_burnt))
		return
	for(var/image/gore_image as anything in .)
		for(var/zone in hv_stump_burnt)
			if(gore_image.icon_state == "stump_[zone]_blood")
				gore_image.color = WIRE_BURNT_STUMP_COLOR
				gore_image.alpha = 255
			else if(gore_image.icon_state == "stump_[zone]_bone")
				gore_image.color = WIRE_BURNT_BONE_COLOR

/// Draws a stump a wire cut held back, now that the limb has left the body.
/mob/living/carbon/proc/hv_reveal_stump(zone)
	LAZYREMOVE(hv_stump_reveal_at, zone)
	hv_gore_key = null
	hv_update_gore_overlays()

// ---- Taking a limb off ----

/**
 * Takes `part` off its owner as tg's dismember() does (the chest takes a share of the limb's damage, a scream,
 * the mood and memory, blood lost) but drops it where the body stands instead of flinging it, and throws no
 * spray: a wire's cut is clean. `bleed_mult` scales the blood lost; `splatter` leaves a drip under the body.
 * Returns the part, or null if it can't come off.
 */
/proc/hv_wire_take_part(obj/item/bodypart/part, wounding_type = WOUND_SLASH, bleed_mult = 1, splatter = TRUE)
	var/mob/living/carbon/victim = part?.owner
	if(!victim || !part.can_dismember() || HAS_TRAIT(victim, TRAIT_GODMODE))
		return null
	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	if(chest && chest != part)
		chest.receive_damage(clamp(part.brute_dam / 2 * chest.body_damage_coeff, 15, 50), clamp(part.burn_dam / 2 * chest.body_damage_coeff, 0, 50), wound_bonus = CANT_WOUND)
	if(victim.stat != DEAD)
		INVOKE_ASYNC(victim, TYPE_PROC_REF(/mob, emote), "scream")
	playsound(get_turf(victim), 'sound/effects/dismember.ogg', 80, TRUE)
	victim.add_mood_event("dismembered_[part.body_zone]", /datum/mood_event/dismembered, part)
	victim.add_mob_memory(/datum/memory/was_dismembered, lost_limb = part)
	LAZYSET(victim.body_zone_dismembered_by, part.body_zone, wounding_type)
	var/bleeds = part.can_bleed()
	var/turf/spot = get_turf(victim)
	var/old_value = victim.hv_sever_spray
	victim.hv_sever_spray = 0
	part.drop_limb(FALSE, TRUE)
	victim.hv_sever_spray = old_value
	victim.update_equipment_speed_mods()
	if(bleeds && !QDELETED(victim))
		// tg bleeds a limb loss twice, once each side of the drop
		victim.bleed(round(rand(20, 40) * bleed_mult))
		victim.bleed(round(rand(20, 40) * bleed_mult))
		if(splatter && isturf(spot) && victim.can_bleed(BLOOD_COVER_TURFS) == BLEED_SPLATTER)
			new /obj/effect/decal/cleanable/blood/drip(spot, victim.get_static_viruses(), victim.get_blood_dna_list())
	return part

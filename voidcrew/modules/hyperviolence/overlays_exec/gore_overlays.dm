// Hyperviolence: stump and skull-wound overlays on human bodies.
//
// Art: icons/gore_overlays.dmi holds the stump and headshot states of CM-SS13's
// icons/mob/humans/dam_human.dmi (cmss13-devs/cmss13 @ e9b299d266c2be727403751c3474e085803b5934),
// made by the CM-SS13 team and licensed CC BY-SA 3.0. Each state comes as a bone layer and a
// greyscale blood layer that is tinted to the mob's blood colour, after CM's
// update_headshot_overlay() (AGPL-3.0, rewritten here for tg's body code). CM's body sprites share
// tg's base, so the art lines up with tg humans without pixel changes.
//
// How it hooks in: tg redraws a carbon's damage overlays (update_damage_overlays) whenever a limb
// comes off or goes back on and whenever a limb's damage state changes, so that is where these are
// rebuilt. They are drawn outside overlays_standing, because a new overlay index would renumber
// every tg layer, on fractional layers between the existing ones (see voidcrew/_DEFINES/hyperviolence.dm).
// - A missing head, arm or leg shows a stump. A limb torn off in the last few minutes leaves a wet
//   stump that bleeds through clothing; after that, or after a clean surgical removal, it reads as
//   healed over and clothing covers it. The neck stump always shows above the collar.
// - A heavy brute hit to the head opens a skull wound: light, medium or heavy by the head's brute
//   damage. It shrinks as the head heals and closes when the damage is mostly gone.

/mob/living/carbon
	/// Hyperviolence: the stump and skull-wound images currently drawn on us.
	var/list/hv_gore_overlays
	/// Hyperviolence: what hv_gore_overlays was built from, so an unchanged update skips the rebuild.
	var/hv_gore_key
	/// Hyperviolence: body zone -> world.time that limb was torn off, for wet stumps. Lazy.
	var/list/hv_stump_torn_at

/mob/living/carbon/update_damage_overlays()
	. = ..()
	hv_update_gore_overlays()

/mob/living/carbon/regenerate_icons()
	// regenerate_icons ends up in update_damage_overlays; forget the key so the gore is redrawn too.
	hv_gore_key = null
	return ..()

/// Whether this bodypart is meat on a human-shaped body, the only kind the gore art fits.
/obj/item/bodypart/proc/hv_shows_gore()
	if(!(biological_state & BIO_FLESH) || (bodytype & BODYTYPE_ALIEN))
		return FALSE
	return (bodyshape & BODYSHAPE_HUMANOID) && !(bodyshape & BODYSHAPE_MONKEY)

/// Whether a stump torn off at `zone` is still wet.
/mob/living/carbon/proc/hv_stump_is_fresh(zone)
	var/torn_at = LAZYACCESS(hv_stump_torn_at, zone)
	return !isnull(torn_at) && world.time < torn_at + HV_STUMP_FRESH_TIME

/// Notes that the limb at `zone` was just torn off, so its stump starts out wet.
/mob/living/carbon/proc/hv_note_torn_off(zone)
	LAZYSET(hv_stump_torn_at, zone, world.time)
	// Redraw once it has dried. Overriding keeps one timer per mob; every earlier stump is older.
	addtimer(CALLBACK(src, PROC_REF(hv_update_gore_overlays)), HV_STUMP_FRESH_TIME + 1, TIMER_UNIQUE|TIMER_OVERRIDE)

/// Rebuilds the stump and skull-wound overlays if anything they show has changed.
/mob/living/carbon/proc/hv_update_gore_overlays()
	var/static/list/stump_zones = list(BODY_ZONE_HEAD, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
	var/list/stumps // zone -> TRUE if the stump is wet
	var/skull = 0
	var/burn_hole = FALSE
	var/obj/item/bodypart/chest = get_bodypart(BODY_ZONE_CHEST)
	if(ishuman(src) && chest?.hv_shows_gore())
		for(var/zone in stump_zones)
			var/obj/item/bodypart/part = get_bodypart(zone)
			if(isnull(part))
				LAZYSET(stumps, zone, hv_stump_is_fresh(zone))
				continue
			LAZYREMOVE(hv_stump_torn_at, zone)
			if(zone == BODY_ZONE_HEAD && part.hv_shows_gore())
				var/obj/item/bodypart/head/head = part
				skull = head.hv_skull_wound
				burn_hole = head.hv_burn_hole

	var/new_key
	var/blood_color
	if(stumps || skull || burn_hole)
		if(can_bleed())
			blood_color = get_bloodtype()?.get_damage_color(src) || BLOOD_COLOR_RED
		var/height = HUMAN_HEIGHT_MEDIUM
		if(ishuman(src))
			var/mob/living/carbon/human/as_human = src
			height = as_human.mob_height
		new_key = "[skull][burn_hole ? "b" : ""]"
		for(var/zone in stumps)
			new_key += "|[zone][stumps[zone] ? "+" : "-"]"
		new_key += "|[islist(blood_color) ? jointext(blood_color, ",") : blood_color]|[height]"

	if(new_key == hv_gore_key && (new_key || !hv_gore_overlays))
		return
	hv_gore_key = new_key
	if(hv_gore_overlays)
		cut_overlay(hv_gore_overlays)
		hv_gore_overlays = null
	if(isnull(new_key))
		return
	hv_gore_overlays = hv_build_gore_images(stumps, skull, blood_color)
	// A burn hole shows only while no skull wound is drawn over the same spot.
	if(burn_hole && !skull)
		var/list/hole = hv_gore_image_pair(HV_BURN_HOLE_STATE, HV_SKULL_WOUND_LAYER, HV_BURN_HOLE_COLOR)
		if(ishuman(src))
			var/mob/living/carbon/human/as_human = src
			if(as_human.mob_height != HUMAN_HEIGHT_MEDIUM)
				for(var/image/gore_image as anything in hole)
					as_human.apply_height_filters(gore_image)
		hv_gore_overlays += hole
	add_overlay(hv_gore_overlays)

/// Builds the overlay images for `stumps` (zone -> wet) and a skull wound of level `skull`.
/mob/living/carbon/proc/hv_build_gore_images(list/stumps, skull, blood_color)
	var/list/images = list()
	for(var/zone in stumps)
		var/wet = stumps[zone]
		// A wet stump bleeds through the jumpsuit; a healed one sits under it. The neck always shows.
		var/stump_layer = (wet || zone == BODY_ZONE_HEAD) ? HV_STUMP_FRESH_LAYER : HV_STUMP_LAYER
		images += hv_gore_image_pair("stump_[zone]", stump_layer, blood_color, wet ? 255 : HV_STUMP_OLD_ALPHA)
	if(skull)
		images += hv_gore_image_pair(hv_skull_wound_state(skull), HV_SKULL_WOUND_LAYER, blood_color)
	if(ishuman(src))
		var/mob/living/carbon/human/as_human = src
		if(as_human.mob_height != HUMAN_HEIGHT_MEDIUM)
			for(var/image/gore_image as anything in images)
				as_human.apply_height_filters(gore_image)
	return images

/// The skull-wound icon state prefix for a wound level of 1 to 3.
/proc/hv_skull_wound_state(level)
	var/static/list/states = list("light_headshot", "medium_headshot", "heavy_headshot")
	return states[clamp(level, 1, length(states))]

/// The blood and bone images of one gore state. No blood colour (a body that can't bleed) draws bone only.
/proc/hv_gore_image_pair(state, gore_layer, blood_color, blood_alpha = 255, gore_dir)
	var/list/pair = list()
	if(blood_color)
		var/image/blood = image(HV_GORE_ICON, "[state]_blood", -gore_layer)
		blood.appearance_flags = RESET_COLOR
		blood.color = blood_color
		blood.alpha = blood_alpha
		pair += blood
	pair += image(HV_GORE_ICON, "[state]_bone", -gore_layer)
	if(gore_dir)
		for(var/image/gore_image as anything in pair)
			gore_image.dir = gore_dir
	return pair

/// Icon states currently drawn by the gore overlays, for tests and debugging.
/mob/living/carbon/proc/hv_gore_states()
	var/list/states = list()
	for(var/image/gore_image as anything in hv_gore_overlays)
		states += gore_image.icon_state
	return states

// ---- Torn-off limbs ----

/obj/item/bodypart/drop_limb(special, dismembered, move_to_floor = TRUE)
	// Before the parent: it redraws the owner, and the stump should already read as wet.
	if(dismembered && !special && iscarbon(owner))
		var/mob/living/carbon/torn_from = owner
		torn_from.hv_note_torn_off(body_zone)
	return ..()

// ---- Skull wounds ----

/obj/item/bodypart/head
	/// Hyperviolence: opened by one heavy brute hit; while open the head shows a skull wound.
	var/hv_skull_open = FALSE
	/// Hyperviolence: the skull wound shown now, 0 (none) to 3 (heavy).
	var/hv_skull_wound = 0
	/// Hyperviolence: a laser execution burnt a hole through this skull. Heals shut with the burns.
	var/hv_burn_hole = FALSE

/obj/item/bodypart/head/receive_damage(brute = 0, burn = 0, blocked = 0, updating_health = TRUE, forced = FALSE, required_bodytype = null, wound_bonus = 0, exposed_wound_bonus = 0, sharpness = NONE, attack_direction = null, damage_source, wound_clothing = TRUE)
	var/brute_before = brute_dam
	. = ..()
	if(hv_skull_open || brute_dam - brute_before < HV_SKULL_OPEN_HIT || !hv_shows_gore())
		return
	hv_skull_open = TRUE
	// TRUE tells the caller to redraw damage overlays, which redraws the skull wound with them.
	if(hv_update_skull_wound())
		return TRUE

/obj/item/bodypart/head/update_bodypart_damage_state()
	. = ..()
	if(hv_burn_hole && burn_dam < HV_SKULL_LIGHT_BRUTE)
		hv_burn_hole = FALSE
		. = TRUE
	if(hv_update_skull_wound())
		return TRUE

/// Opens a skull wound if this head can show one, and redraws its owner.
/obj/item/bodypart/head/proc/hv_open_skull()
	if(!hv_shows_gore())
		return FALSE
	hv_skull_open = TRUE
	if(hv_update_skull_wound())
		owner?.update_damage_overlays()
	return TRUE

/// Sets hv_skull_wound from the head's brute damage. Returns TRUE if it changed.
/obj/item/bodypart/head/proc/hv_update_skull_wound()
	var/new_level = 0
	if(hv_skull_open)
		if(brute_dam >= HV_SKULL_HEAVY_BRUTE)
			new_level = 3
		else if(brute_dam >= HV_SKULL_MEDIUM_BRUTE)
			new_level = 2
		else if(brute_dam >= HV_SKULL_LIGHT_BRUTE)
			new_level = 1
		else
			hv_skull_open = FALSE // healed shut
	if(new_level == hv_skull_wound)
		return FALSE
	hv_skull_wound = new_level
	return TRUE

/obj/item/bodypart/head/get_limb_icon(dropped, mob/living/carbon/update_on)
	. = ..()
	// On a body the mob draws the wound (hv_update_gore_overlays); a severed head carries its own.
	if(!dropped || !islist(.))
		return
	if(!hv_skull_wound)
		if(hv_burn_hole)
			. += hv_gore_image_pair(HV_BURN_HOLE_STATE, HV_SKULL_WOUND_LAYER, HV_BURN_HOLE_COLOR, gore_dir = SOUTH)
		return
	var/blood_color = get_color_from_blood_list(blood_dna_info)
	. += hv_gore_image_pair(hv_skull_wound_state(hv_skull_wound), HV_SKULL_WOUND_LAYER, blood_color, gore_dir = SOUTH)

/**
 * # Exotic battery
 *
 * Holds what a harvester draws off an alien artifact: a copy of one effect and up to
 * ARTIFACT_BATTERY_CAPACITY charge. It does nothing on its own; a utilizer runs it.
 *
 * Rewritten from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/obj/particle_battery.dm.
 * Art: Nova's machinery.dmi particles_battery states (CC BY-SA 3.0, pixel-checked clean against
 * Goon), with a core mask drawn for Voidcrew so the battery glows in its energy kind's colour.
 *
 * Only a harvester draw adds charge, and a new battery is always empty. Batteries are items, so
 * ship saves and checkpoints delete them on load (clear_stock() removes every item, wherever it
 * sits) and a saved harvester comes back with an empty slot: a charged battery can't be copied.
 */
/obj/item/anomaly_battery
	name = "exotic battery"
	desc = "A heavy little cell with a window onto its core."
	icon = 'voidcrew/modules/xenoarch/icons/use.dmi'
	icon_state = "battery0"
	base_icon_state = "battery"
	inhand_icon_state = "cell"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT,
		/datum/material/gold = HALF_SHEET_MATERIAL_AMOUNT,
	)
	/// Charge held, 0 to capacity
	var/stored_charge = 0
	/// Most charge it can hold
	var/capacity = ARTIFACT_BATTERY_CAPACITY
	/// A copy of the artifact effect it holds, or null if it was never filled or was purged
	var/datum/artifact_effect/held_effect
	/// The artifact effect it was drawn from, so a harvester can top it up from the same find
	var/datum/weakref/source_ref
	/// Catalogue number of the find it was drawn from, stamped on its side
	var/source_serial

/obj/item/anomaly_battery/Destroy(force)
	QDEL_NULL(held_effect)
	source_ref = null
	return ..()

/// 0 to 1.
/obj/item/anomaly_battery/proc/charge_fraction()
	if(capacity <= 0)
		return 0
	return clamp(stored_charge / capacity, 0, 1)

/obj/item/anomaly_battery/proc/is_full()
	return stored_charge >= capacity

/// The gauge on its side: 0, 25, 50, 75 or 100. Any charge at all shows a quarter.
/obj/item/anomaly_battery/proc/charge_level()
	if(stored_charge <= 0)
		return 0
	return clamp(round(charge_fraction() * 100, 25), 25, 100)

/// The energy kind its core glows with, or null when it holds nothing.
/obj/item/anomaly_battery/proc/held_kind()
	if(!held_effect)
		return null
	return artifact_energy_kind(held_effect.energy_kind)

/// The kind to show: null while it holds no charge, so an empty core stays dark.
/obj/item/anomaly_battery/proc/lit_kind()
	return stored_charge > 0 ? held_kind() : null

/// Whether it still holds the effect drawn from `source`.
/obj/item/anomaly_battery/proc/holds_from(datum/artifact_effect/source)
	return held_effect && source && source_ref?.resolve() == source

/// Whether a harvester may pour `source`'s energy in: it is empty, or it already holds that same effect.
/obj/item/anomaly_battery/proc/can_take(datum/artifact_effect/source)
	if(!source || is_full())
		return FALSE
	return stored_charge <= 0 || holds_from(source)

/// Readies it to take `source`'s energy, copying the effect unless it already holds it.
/obj/item/anomaly_battery/proc/load_from(datum/artifact_effect/source, serial)
	if(holds_from(source))
		return
	discard_effect()
	held_effect = source.make_harvest_copy(src)
	source_ref = WEAKREF(source)
	source_serial = serial
	stored_charge = 0
	update_appearance()

/// Adds charge, up to capacity. Returns how much went in.
/obj/item/anomaly_battery/proc/add_charge(amount)
	if(!held_effect || amount <= 0)
		return 0
	var/added = min(amount, capacity - stored_charge)
	if(added <= 0)
		return 0
	var/old_level = charge_level()
	stored_charge += added
	if(charge_level() != old_level)
		update_appearance()
	return added

/// Spends charge. Returns how much came out.
/obj/item/anomaly_battery/proc/use_charge(amount)
	if(amount <= 0)
		return 0
	var/used = min(amount, stored_charge)
	var/old_level = charge_level()
	stored_charge -= used
	if(charge_level() != old_level)
		update_appearance()
	return used

/// Empties it and lets go of the effect it held.
/obj/item/anomaly_battery/proc/purge()
	discard_effect()
	source_serial = null
	stored_charge = 0
	update_appearance()

/obj/item/anomaly_battery/proc/discard_effect()
	if(held_effect?.activated)
		held_effect.deactivate()
	QDEL_NULL(held_effect)
	source_ref = null

/obj/item/anomaly_battery/update_icon_state()
	icon_state = "[base_icon_state][charge_level()]"
	return ..()

/obj/item/anomaly_battery/update_overlays()
	. = ..()
	. += anomaly_core_overlays(src, "battery_core", lit_kind(), charge_fraction())

/obj/item/anomaly_battery/examine(mob/user)
	. = ..()
	if(source_serial)
		. += "A strip on its side is stamped <b>[source_serial]</b>."
	. += anomaly_core_description(lit_kind(), charge_fraction())

// ===== Shared with the utilizer and harvester =====

/**
 * The glowing core of a battery as overlays: the tinted mask and its emissive, brighter with
 * more charge. `state` is the mask's icon state on `owner`'s icon. Empty while the core is dark.
 */
/proc/anomaly_core_overlays(atom/owner, state, datum/artifact_energy_kind/kind, fraction)
	. = list()
	if(!kind || fraction <= 0)
		return
	var/core_alpha = round(110 + 145 * clamp(fraction, 0, 1))
	var/mutable_appearance/core = mutable_appearance(owner.icon, state, alpha = core_alpha)
	core.color = kind.color
	. += core
	. += emissive_appearance(owner.icon, state, owner, alpha = round(core_alpha * 0.7))

/// "Its core glows a steady amber." or "Its core is dark."
/proc/anomaly_core_description(datum/artifact_energy_kind/kind, fraction)
	if(!kind || fraction <= 0)
		return "Its core is dark."
	var/strength = "bright"
	if(fraction < 0.34)
		strength = "dim"
	else if(fraction < 0.67)
		strength = "steady"
	return "Its core glows a [strength] [anomaly_glow_word(kind.key)]."

/// A plain colour word for an energy kind's glow.
/proc/anomaly_glow_word(kind_key)
	switch(kind_key)
		if(ARTIFACT_ENERGY_CONCENTRATED)
			return "amber"
		if(ARTIFACT_ENERGY_PSIONIC)
			return "violet"
		if(ARTIFACT_ENERGY_ELECTROMAGNETIC)
			return "pale blue"
		if(ARTIFACT_ENERGY_PARTICLE)
			return "white"
		if(ARTIFACT_ENERGY_ORGANIC)
			return "rose red"
		if(ARTIFACT_ENERGY_BLUESPACE)
			return "deep blue"
		if(ARTIFACT_ENERGY_SYNTHESIS)
			return "green"
	return "strange light"

/datum/design/anomaly_battery
	name = "Exotic Battery"
	desc = "A cell built to hold what a harvester draws off an alien find."
	id = "xenoarch_battery"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT,
		/datum/material/gold = HALF_SHEET_MATERIAL_AMOUNT,
	)
	build_path = /obj/item/anomaly_battery
	category = list(
		RND_CATEGORY_EQUIPMENT + RND_SUBCATEGORY_EQUIPMENT_SCIENCE
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE

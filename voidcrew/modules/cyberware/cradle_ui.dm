/**
 * # Chrome Cradle console support
 *
 * Everything the cradle interface needs that is not the machine itself: how
 * chrome is filed into rows on screen, what Splice charges for each piece, and
 * the two art assets the console draws itself with.
 */

// ---- Slot grouping -----------------------------------------------------

/**
 * How the cradle files chrome on screen: one row per body system, in head-down
 * order, each owning the organ slots that live there. This is presentation
 * only, the slots themselves are the real uniqueness rule.
 *
 * Anything chrome whose slot isn't listed here falls into a trailing "Other
 * Hardware" group rather than vanishing, so a new slot always shows up
 * somewhere even before it gets a home.
 */
GLOBAL_LIST_INIT(cyberware_ui_groups, list(
	list("id" = "cortex", "name" = "Frontal Cortex", "region" = "head", "slots" = list(ORGAN_SLOT_CYBERWARE_GOVERNOR, ORGAN_SLOT_CYBERWARE_RIGGER, ORGAN_SLOT_CYBERWARE_REGISTRY)),
	list("id" = "ocular", "name" = "Ocular System", "region" = "head", "slots" = list(ORGAN_SLOT_EYES)),
	list("id" = "aural", "name" = "Auditory System", "region" = "head", "slots" = list(ORGAN_SLOT_CYBERWARE_EARS, ORGAN_SLOT_CYBERWARE_LARYNX)),
	list("id" = "os", "name" = "Operating System", "region" = "torso", "slots" = list(ORGAN_SLOT_CYBERWARE_OS)),
	list("id" = "nervous", "name" = "Nervous System", "region" = "torso", "slots" = list(ORGAN_SLOT_CYBERWARE_NERVOUS)),
	list("id" = "circulatory", "name" = "Circulatory System", "region" = "torso", "slots" = list(ORGAN_SLOT_CYBERWARE_FILTER, ORGAN_SLOT_HEART_AID, ORGAN_SLOT_CYBERWARE_HEART_AUX)),
	list("id" = "seal", "name" = "Environment Seal", "region" = "torso", "slots" = list(ORGAN_SLOT_CYBERWARE_SEAL)),
	list("id" = "integumentary", "name" = "Integumentary System", "region" = "torso", "slots" = list(ORGAN_SLOT_CYBERWARE_DERMAL, ORGAN_SLOT_CYBERWARE_SKIN, ORGAN_SLOT_CYBERWARE_INK)),
	list("id" = "skeleton", "name" = "Skeletal Frame", "region" = "torso", "slots" = list(ORGAN_SLOT_CYBERWARE_FRAME)),
	list("id" = "digestive", "name" = "Digestive Tract", "region" = "torso", "slots" = list(ORGAN_SLOT_CYBERWARE_GUT, ORGAN_SLOT_CYBERWARE_STASH)),
	list("id" = "arms", "name" = "Arm Hardware", "region" = "arms", "slots" = list(ORGAN_SLOT_RIGHT_ARM_AUG, ORGAN_SLOT_LEFT_ARM_AUG)),
	list("id" = "hands", "name" = "Hands", "region" = "arms", "slots" = list(ORGAN_SLOT_CYBERWARE_HANDS)),
	list("id" = "legs", "name" = "Mobility", "region" = "legs", "slots" = list(ORGAN_SLOT_CYBERWARE_LEGS)),
))

/// slot string -> the group id that owns it. Built once off the table above.
GLOBAL_LIST_EMPTY(cyberware_slot_to_group)

/// Which UI group a piece of chrome files under. Never null: unrecognised
/// slots land in the catch-all.
/proc/get_cyberware_group_id(obj/item/organ/ware)
	if(!length(GLOB.cyberware_slot_to_group))
		for(var/list/group as anything in GLOB.cyberware_ui_groups)
			for(var/slot in group["slots"])
				GLOB.cyberware_slot_to_group[slot] = group["id"]
	return GLOB.cyberware_slot_to_group[ware.slot] || "other"

// ---- Parlor price index ------------------------------------------------

/**
 * organ typepath -> what Splice charges for it, so the cradle can quote a
 * price next to the neural cost. Built lazily on first use because cased pairs
 * only reveal their contents once one has actually been opened.
 *
 * `paired` marks a piece sold two-to-a-case: the price on the card is the
 * whole case's, not this half's.
 */
GLOBAL_LIST_EMPTY(cyberware_price_index)
GLOBAL_VAR_INIT(cyberware_prices_indexed, FALSE)

/proc/get_cyberware_price(obj/item/organ/ware)
	if(!GLOB.cyberware_prices_indexed)
		build_cyberware_price_index()
	return GLOB.cyberware_price_index[ware.type]

/proc/build_cyberware_price_index()
	GLOB.cyberware_prices_indexed = TRUE
	for(var/datum/shop_sku/ripperdoc/sku_type as anything in subtypesof(/datum/shop_sku/ripperdoc))
		var/item_path = initial(sku_type.item_path)
		if(!ispath(item_path, /obj/item))
			continue
		var/list/price = list(
			"credits" = initial(sku_type.price_credits),
			"vouchers" = initial(sku_type.price_vouchers),
			"paired" = FALSE,
		)
		if(ispath(item_path, /obj/item/organ))
			GLOB.cyberware_price_index[item_path] = price
			continue
		// Cased pairs and knuckle sets: crack one open in nullspace to learn
		// which organs it holds, so each half can quote the case's price. The
		// sample and its contents go straight back out. Nothing here is ever
		// meant to reach a turf.
		var/obj/item/sample = new item_path(null)
		for(var/obj/item/organ/held in sample.contents)
			var/list/pair_price = price.Copy()
			pair_price["paired"] = TRUE
			GLOB.cyberware_price_index[held.type] = pair_price
		for(var/atom/movable/packed as anything in sample.contents.Copy())
			qdel(packed)
		qdel(sample)

// ---- Console art -------------------------------------------------------

/**
 * Console faceplate. Its bezels match the interface GEOMETRY coordinates.
 */
/datum/asset/simple/chrome_cradle_plate
	assets = list(
		"chrome_cradle_plate.png" = 'voidcrew/modules/cyberware/icons/chrome_cradle_plate.png',
	)

// ---- Card art ----------------------------------------------------------

/**
 * Inventory sprites for the rack cards, as one CSS spritesheet rather than a
 * base64 blob per row: the cradle re-pushes its whole ware list on every servo
 * beat of an install, and inlined icons would put the entire roster on the wire
 * several times a second.
 *
 * Keyed by icon state, since that IS what makes two pieces look different.
 * The interface builds `chrome32x32 <key>` off the `icon` field of a ware.
 */
/datum/asset/spritesheet_batched/chrome
	name = "chrome"

/datum/asset/spritesheet_batched/chrome/create_spritesheets()
	var/list/seen = list()
	var/list/ware_types = typesof(/obj/item/organ/cyberimp/cyberware) \
		+ typesof(/obj/item/organ/eyes/robotic/cyberware) \
		+ typesof(/obj/item/organ/cyberimp/arm/toolkit/cyberware)
	for(var/obj/item/organ/ware as anything in ware_types)
		var/state = initial(ware.icon_state)
		if(!state || seen[state])
			continue
		var/icon_file = initial(ware.icon)
		if(!icon_exists(icon_file, state))
			continue
		seen[state] = TRUE
		insert_icon(get_cyberware_card_icon_key(state), uni_icon(icon_file, state, SOUTH))

/// The spritesheet key for a ware's card art. Prefixed so chrome states can
/// never collide with another sheet's class names.
/proc/get_cyberware_card_icon_key(icon_state)
	return "chrome-[icon_state]"

#undef CYBERWARE_GHOST_ALPHA

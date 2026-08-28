/**
 * # Hoarfrost Matriarch - drops
 *
 * The jackpot is what the creature itself drops, not a blueprint or a voucher
 * that is really a ticket for some other system. This is the tg megafauna model
 * - drake chest into spectral blade, lava staff, dragon's blood - and the best
 * form of boss loot is that you get the boss.
 *
 * - **hoarfrost hide** (guaranteed) crafts into the **rimeward cloak**: cold
 *   immunity and immunity to her frost effects. Directly mirrors ashdrake hide
 *   into the ash cloak, and it is what makes the kill worth something even on a
 *   bad roll. It also, deliberately, makes you immune to the Matriarch's Heart
 *   below - wear her hide, ignore her cold, exactly like wearing the drake's.
 * - **the Matriarch's Heart** (jackpot) recreates Killing Cold in your hand.
 *   Note that it is spawned with *no* creator, so it is impartial: the deployer
 *   stands in the safe circle like everybody else, or freezes like everybody
 *   else. You own her signature move, demands included.
 * - **rimebreath horn** (jackpot) is the conventional alternative: her cone,
 *   scaled to something a person can hold, chill application included.
 * - **rime fang** is the crusher trophy, per the elite convention already set
 *   by wolf.dm's `fang` and polarbear.dm's `war_paw`.
 *
 * The Heart does not reimplement anything: it spawns the same
 * [/obj/effect/hoarfrost_killing_zone] her ability does and paints its warning
 * with the same [/proc/hoarfrost_paint_zone]. Retuning the field in
 * hoarfrost_objects.dm retunes the ability and this item together.
 */

// =========================================================================
// HOARFROST HIDE -> RIMEWARD CLOAK
// =========================================================================

/obj/item/stack/sheet/animalhide/hoarfrost
	name = "hoarfrost hide"
	desc = "Slabs of thick white pelt. Cold to the touch, and it stays cold no matter where you put it."
	icon = 'voidcrew/icons/obj/hoarfrost.dmi'
	// novariants = FALSE, so /obj/item/stack/update_icon_state() swaps to
	// "_2" past a third of max_amount and "_3" past two thirds. All three
	// states exist in the DMI; do not rename without adding the variants.
	icon_state = "hoarfrost_hide"
	singular_name = "hoarfrost plate"
	max_amount = 12
	novariants = FALSE
	item_flags = NOBLUDGEON
	w_class = WEIGHT_CLASS_NORMAL
	layer = MOB_LAYER
	resistance_flags = FREEZE_PROOF
	merge_type = /obj/item/stack/sheet/animalhide/hoarfrost

/obj/item/stack/sheet/animalhide/hoarfrost/Initialize(mapload, new_amount, merge, list/mat_override, mat_amt)
	. = ..()
	var/static/list/slapcraft_recipe_list = list(/datum/crafting_recipe/rimeward_cloak)
	AddElement(\
		/datum/element/slapcrafting,\
		slapcraft_recipes = slapcraft_recipe_list,\
	)

/datum/crafting_recipe/rimeward_cloak
	name = "Rimeward Cloak"
	result = /obj/item/clothing/suit/hooded/cloak/rimeward
	time = 5 SECONDS
	reqs = list(
		/obj/item/stack/sheet/sinew = 2,
		/obj/item/stack/sheet/animalhide/hoarfrost = 5,
	)
	category = CAT_CLOTHING

/obj/item/clothing/suit/hooded/cloak/rimeward
	name = "rimeward cloak"
	desc = "A heavy hooded cape of hoarfrost pelt. Cold does not get through it, hers included."
	icon = 'voidcrew/icons/obj/hoarfrost.dmi'
	icon_state = "rimeward_cloak"
	// Worn overlay is ours too. It was built by restyling the goliath cloak's
	// worn sprite rather than drawing one blind, then refitted to the exact
	// footprint that sprite occupies per direction - (7,9)-(24,28) facing
	// north/south, narrower side-on. That is what keeps it sitting on the rig
	// instead of floating off the shoulders.
	worn_icon = 'voidcrew/icons/mob/clothing/suits/hoarfrost.dmi'
	worn_icon_state = "rimeward_cloak"
	alternate_worn_layer = NECK_LAYER
	body_parts_covered = CHEST|GROIN|LEGS|ARMS
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION_NO_NEW_ICON
	cold_protection = CHEST|GROIN|LEGS|ARMS
	min_cold_protection_temperature = SPACE_SUIT_MIN_TEMP_PROTECT
	heat_protection = CHEST|GROIN|LEGS|ARMS
	max_heat_protection_temperature = SPACE_SUIT_MAX_TEMP_PROTECT
	resistance_flags = FREEZE_PROOF
	armor_type = /datum/armor/cloak_rimeward
	hoodtype = /obj/item/clothing/head/hooded/cloakhood/rimeward
	// TRAIT_RESISTCOLD is what hoarfrost_shrugs_off_cold() reads, so this one
	// trait buys immunity to the killing field, the rime residue and the
	// Rimebreath chill in a single place.
	clothing_traits = list(TRAIT_RESISTCOLD, TRAIT_SNOWSTORM_IMMUNE, TRAIT_NO_SLIP_ICE)

/obj/item/clothing/suit/hooded/cloak/rimeward/Initialize(mapload)
	. = ..()
	allowed = GLOB.mining_suit_allowed

/// Lighter plate than the goliath cloak - the cloak's value is the cold, not
/// the armour, and it should not quietly become the best mining suit as well.
/datum/armor/cloak_rimeward
	melee = 45
	bullet = 10
	laser = 10
	energy = 20
	bomb = 40
	fire = 25
	acid = 40
	wound = 10

/obj/item/clothing/head/hooded/cloakhood/rimeward
	name = "rimeward hood"
	desc = "A deep hood of hoarfrost pelt. Warm, and it muffles just about everything."
	icon = 'voidcrew/icons/obj/hoarfrost.dmi'
	worn_icon = 'voidcrew/icons/mob/clothing/head/hoarfrost.dmi'
	icon_state = "rimeward_hood"
	worn_icon_state = "rimeward_hood"
	armor_type = /datum/armor/cloak_rimeward
	body_parts_covered = HEAD
	cold_protection = HEAD
	min_cold_protection_temperature = SPACE_HELM_MIN_TEMP_PROTECT
	heat_protection = HEAD
	max_heat_protection_temperature = SPACE_SUIT_MAX_TEMP_PROTECT
	clothing_flags = SNUG_FIT
	flags_inv = HIDEEARS|HIDEEYES|HIDEHAIR|HIDEFACIALHAIR
	transparent_protection = HIDEMASK
	resistance_flags = FREEZE_PROOF

// =========================================================================
// THE MATRIARCH'S HEART - jackpot, her signature move in your hand
// =========================================================================

/**
 * Squeeze it and the same field she plants goes down where you are standing:
 * safe within two tiles of the anchor, lethal outside it, for a few seconds.
 *
 * The anchor is fixed at the moment you arm it, and the warning ring is painted
 * there, so the demand it makes of you is the same one she makes of you - get
 * inside the circle and hold. It spares nobody by default; the counter is the
 * rimeward cloak, which you get from the same corpse.
 */
/obj/item/matriarchs_heart
	name = "Matriarch's Heart"
	desc = "A lump of blue-black ice the size of a fist, cut out of something that was still using it. It hasn't melted and it isn't going to. Squeeze it to freeze everything more than two tiles away."
	icon = 'voidcrew/icons/obj/hoarfrost.dmi'
	icon_state = "matriarchs_heart"
	w_class = WEIGHT_CLASS_SMALL
	throwforce = 5
	resistance_flags = FREEZE_PROOF | FIRE_PROOF
	/// How long the arming ring hangs before the field blooms.
	var/arm_time = 1.5 SECONDS
	/// Time between deployments.
	var/deploy_cooldown_time = 35 SECONDS
	COOLDOWN_DECLARE(deploy_cooldown)

/obj/item/matriarchs_heart/examine(mob/user)
	. = ..()
	. += span_notice("Safe ground is the two tiles around wherever you arm it. Everything further out freezes.")
	if(!COOLDOWN_FINISHED(src, deploy_cooldown))
		. += span_warning("It is still refreezing - about [round(COOLDOWN_TIMELEFT(src, deploy_cooldown) / 10)] seconds.")

/obj/item/matriarchs_heart/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	deploy(user)
	return TRUE

/// Arm the heart where it is standing now.
/obj/item/matriarchs_heart/proc/deploy(mob/user)
	if(!COOLDOWN_FINISHED(src, deploy_cooldown))
		balloon_alert(user, "still refreezing!")
		return
	var/turf/anchor = get_turf(src)
	if(isnull(anchor))
		return
	COOLDOWN_START(src, deploy_cooldown, deploy_cooldown_time)
	user.visible_message(
		span_boldwarning("[user] squeezes [src] and the temperature falls off a cliff!"),
		span_boldwarning("You squeeze [src]. Stay inside the ring."),
	)
	playsound(src, 'sound/effects/magic/ethereal_enter.ogg', 70, TRUE)
	// The same painter her own telegraph uses, so the warning reads identically.
	hoarfrost_paint_zone(anchor, arm_time)
	addtimer(CALLBACK(src, PROC_REF(bloom), anchor), arm_time)

/// The field goes live at the anchor.
/obj/item/matriarchs_heart/proc/bloom(turf/anchor)
	if(QDELETED(anchor))
		return
	// The one and only Killing Cold implementation - see hoarfrost_objects.dm.
	// No creator is passed: the field is impartial, including towards you.
	new /obj/effect/hoarfrost_killing_zone(anchor)

// =========================================================================
// RIMEBREATH HORN - jackpot, the conventional alternative
// =========================================================================

/obj/item/rimebreath_horn
	name = "rimebreath horn"
	desc = "A hollow length of the Matriarch's horn, rimed white all the way down the inside. Breathe into it and frost comes out the far end."
	icon = 'voidcrew/icons/obj/hoarfrost.dmi'
	icon_state = "rimebreath_horn"
	w_class = WEIGHT_CLASS_NORMAL
	force = 12
	throwforce = 10
	attack_verb_continuous = list("clubs", "bludgeons", "gores")
	attack_verb_simple = list("club", "bludgeon", "gore")
	resistance_flags = FREEZE_PROOF | FIRE_PROOF
	actions_types = list(/datum/action/cooldown/mob_cooldown/fire_breath/ice/rimebreath/horn)
	action_slots = ITEM_SLOT_HANDS

/obj/item/rimebreath_horn/examine(mob/user)
	. = ..()
	. += span_notice("Hold it and use the ability, then click where you want the cone.")

/**
 * Her cone, scaled to something a person can hold: same shape, same chill, less
 * of both, and a much longer breath between shots.
 */
/datum/action/cooldown/mob_cooldown/fire_breath/ice/rimebreath/horn
	name = "Rimebreath"
	desc = "Breathe a cone of frost four tiles long at whatever you click. Deals 15 burn and badly slows anything it hits for 3 seconds."
	cooldown_time = 18 SECONDS
	fire_range = 4
	fire_damage = 15
	forecast_delay = 0.8 SECONDS
	chill_duration = 3 SECONDS
	cone_angles = list(-25, 0, 25)

/datum/action/cooldown/mob_cooldown/fire_breath/ice/rimebreath/horn/announce_windup()
	owner.visible_message(span_danger("[owner] puts the horn to [owner.p_their()] lips and draws a long, rattling breath."))

// =========================================================================
// RIME FANG - the crusher trophy
// =========================================================================

/obj/item/crusher_trophy/rime_fang
	name = "rime fang"
	desc = "A tooth as long as a forearm, still cold enough to stick to bare skin. Could be attached to a kinetic crusher, or mounted."
	icon = 'voidcrew/icons/obj/hoarfrost.dmi'
	icon_state = "rime_fang"
	denied_type = /obj/item/crusher_trophy/rime_fang
	/// How long the chill from a mark detonation lasts.
	var/chill_duration = 2 SECONDS

/obj/item/crusher_trophy/rime_fang/effect_desc()
	return "waveform collapse to flash-chill the target, briefly slowing them"

/obj/item/crusher_trophy/rime_fang/on_mark_detonation(mob/living/target, mob/living/user, obj/item/kinetic_crusher/pkc)
	. = ..()
	if(!isliving(target) || HAS_TRAIT(target, TRAIT_RESISTCOLD))
		return
	target.apply_status_effect(/datum/status_effect/hoarfrost_chill/mild, chill_duration)

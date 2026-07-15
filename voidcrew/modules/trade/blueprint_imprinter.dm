/**
 * # Neural Schematic Imprinter
 *
 * The outpost service that converts a physical blueprint into round-long
 * knowledge: feed it the schematic, pay the fee, and the recipe is bound to
 * your ckey until the round ends — the scroll is destroyed in the process.
 *
 * The trade-off is the point: a physical schematic is shareable, resellable
 * and stealable; an imprint is theft-proof but yours alone, and the paper is
 * gone for good. Fees scale with the schematic's tier.
 *
 * Outpost furniture rules apply: indestructible, and attacking it is
 * aggression (resolved through get_trader_outpost_for_turf, like the walls).
 */

#define IMPRINT_FEE_GREEN 750
#define IMPRINT_FEE_YELLOW 1500
#define IMPRINT_FEE_RED 3000

/obj/machinery/blueprint_imprinter
	name = "neural schematic imprinter"
	desc = "A skull-shaped scanner cradle wired into a schematic shredder. Insert a schematic, pay the fee, know the schematic. The shredder half is not optional."
	icon = 'icons/obj/machines/research.dmi'
	icon_state = "d_analyzer"
	density = TRUE
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/obj/machinery/blueprint_imprinter/examine(mob/user)
	. = ..()
	. += span_notice("Imprint fees: [IMPRINT_FEE_GREEN] cr (green-tier) / [IMPRINT_FEE_YELLOW] cr (yellow-tier) / [IMPRINT_FEE_RED] cr (red-tier), charged to your ID. The schematic is destroyed.")
	. += span_notice("An imprint lasts the rest of the round and can't be stolen. The paper copy could have been sold. Choose.")
	var/list/known = get_user_imprints(user)
	if(length(known))
		. += span_notice("You hold neural imprints for: <b>[known.Join(", ")]</b>.")

/**
 * Names of everything this user has imprinted, for examine.
 */
/obj/machinery/blueprint_imprinter/proc/get_user_imprints(mob/user)
	var/list/names = list()
	if(!user?.ckey)
		return names
	var/list/imprints = GLOB.blueprint_imprints[user.ckey]
	if(!length(imprints))
		return names
	for(var/datum/crafting_recipe/recipe as anything in GLOB.crafting_recipes)
		if(recipe.type in imprints)
			names += recipe.name
	return names

/obj/machinery/blueprint_imprinter/attackby(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!istype(attacking_item, /obj/item/blueprint))
		return ..()
	try_imprint(attacking_item, user)
	return TRUE

/obj/machinery/blueprint_imprinter/proc/try_imprint(obj/item/blueprint/print, mob/living/user)
	var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
	if(outpost?.is_user_barred(user))
		outpost.trader?.speak_line(TRADER_LINE_REFUSAL)
		balloon_alert(user, "trade embargo!")
		return
	if(!user.ckey)
		return
	if(!print.recipe_type)
		balloon_alert(user, "unreadable schematic!")
		return

	var/list/imprints = GLOB.blueprint_imprints[user.ckey]
	if(imprints && (print.recipe_type in imprints))
		balloon_alert(user, "already imprinted!")
		return

	var/fee = IMPRINT_FEE_YELLOW
	switch(print.tier)
		if(BLUEPRINT_TIER_GREEN)
			fee = IMPRINT_FEE_GREEN
		if(BLUEPRINT_TIER_RED)
			fee = IMPRINT_FEE_RED

	var/obj/item/card/id/id_card = user.get_idcard(TRUE)
	var/datum/bank_account/account = id_card?.registered_account
	if(!account)
		balloon_alert(user, "no bank account on your ID!")
		return
	if(!account.has_money(fee))
		balloon_alert(user, "needs [fee] cr!")
		return

	balloon_alert(user, "imprinting...")
	if(!do_after(user, 3 SECONDS, src))
		return
	// Re-validate after the channel: the scroll and the money must still be there
	if(QDELETED(print) || !user.is_holding(print))
		return
	if(!account.adjust_money(-fee, "Neural Imprint: [print.schematic_name]"))
		balloon_alert(user, "payment failed!")
		return

	if(!GLOB.blueprint_imprints[user.ckey])
		GLOB.blueprint_imprints[user.ckey] = list()
	GLOB.blueprint_imprints[user.ckey] |= print.recipe_type

	playsound(src, 'sound/machines/ping.ogg', 50, TRUE)
	user.visible_message(
		span_notice("[src] scans [user] and shreds [print] into confetti."),
		span_notice("Cold light sweeps your skull. You know the [print.schematic_name] by heart now — and the schematic is confetti."),
	)
	qdel(print)

// Attacking outpost property is aggression, imprinter included
/obj/machinery/blueprint_imprinter/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force && !istype(attacking_item, /obj/item/blueprint))
		var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
		outpost?.register_aggression(user)
	return ..()

/obj/machinery/blueprint_imprinter/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	if(isliving(hitting_projectile.firer))
		var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
		outpost?.register_aggression(hitting_projectile.firer)
	return ..()

#undef IMPRINT_FEE_GREEN
#undef IMPRINT_FEE_YELLOW
#undef IMPRINT_FEE_RED

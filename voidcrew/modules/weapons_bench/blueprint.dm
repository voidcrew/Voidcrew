/**
 * Weapon schematics: blueprint-gated crafting-menu recipes
 *
 * A blueprint is a physical schematic scroll. Its recipe appears in the
 * ordinary tg crafting menu when EITHER:
 *   1. the crafter is carrying the physical blueprint anywhere on them, or
 *   2. the crafter's ckey holds a neural imprint of it for the round
 *      (bought at an outpost's neural schematic imprinter, destroying the
 *      physical copy, see voidcrew/modules/trade/blueprint_imprinter.dm).
 *
 * The availability gate lives in a //VOID EDIT inside
 * /datum/component/personal_crafting/get_visible_recipes().
 *
 * The tension is deliberate: keep the physical copy and it's shareable,
 * resellable and stealable; imprint it and it's theft-proof but gone.
 *
 * Machined gun parts stay the R&D clock: each gun's part design prints at
 * the protolathe behind its techweb part node (see the per-gun files), and the
 * crafting recipes consume that part. Gun recipes also want a firing pin.
 * Crafted guns get a clean standard pin installed in place of any
 * faction-locked default (see on_craft_completion below). No bench or other
 * machinery is required; the recipe and its reqs are the whole gate, so
 * crafting can happen anywhere.
 */

/// ckey -> list of /datum/crafting_recipe/blueprint types imprinted this round
GLOBAL_LIST_EMPTY(blueprint_imprints)

/**
 * The blueprint-recipe availability gate, called from the VOID EDIT in
 * personal_crafting/get_visible_recipes(): carrying the schematic or holding
 * its neural imprint unlocks the recipe.
 */
/proc/is_blueprint_recipe_available(datum/crafting_recipe/blueprint/recipe, mob/user)
	if(!istype(user))
		return FALSE
	if(user.ckey)
		var/list/imprints = GLOB.blueprint_imprints[user.ckey]
		if(imprints && (recipe.type in imprints))
			return TRUE
	for(var/obj/item/blueprint/print in user.get_all_contents())
		if(print.recipe_type == recipe.type)
			return TRUE
	return FALSE

/**
 * # Blueprint (schematic scroll)
 */
/obj/item/blueprint
	name = "schematic"
	desc = "A rolled-up fabrication schematic. Carry it and its recipe shows up in your crafting menu."
	icon = 'icons/obj/scrolls.dmi'
	icon_state = "blueprints"
	inhand_icon_state = "blueprints"
	w_class = WEIGHT_CLASS_SMALL
	/// The /datum/crafting_recipe/blueprint this schematic unlocks
	var/recipe_type
	/// Display name of the thing it builds
	var/schematic_name = "something"
	/// BLUEPRINT_TIER_*: drives the imprinter fee and the scroll's tint
	var/tier = BLUEPRINT_TIER_YELLOW

/obj/item/blueprint/Initialize(mapload)
	. = ..()
	switch(tier)
		if(BLUEPRINT_TIER_GREEN)
			add_atom_colour("#a8d8b0", FIXED_COLOUR_PRIORITY)
		if(BLUEPRINT_TIER_YELLOW)
			add_atom_colour("#d8cc90", FIXED_COLOUR_PRIORITY)
		if(BLUEPRINT_TIER_RED)
			add_atom_colour("#d89a90", FIXED_COLOUR_PRIORITY)

/**
 * The live recipe instance this schematic corresponds to (from the global
 * crafting recipe list), cached per recipe type.
 */
/obj/item/blueprint/proc/get_recipe()
	var/static/list/recipe_cache = list()
	if(!recipe_type)
		return null
	var/datum/crafting_recipe/cached = recipe_cache[recipe_type]
	if(cached)
		return cached
	for(var/datum/crafting_recipe/recipe as anything in GLOB.crafting_recipes)
		if(recipe.type == recipe_type)
			recipe_cache[recipe_type] = recipe
			return recipe
	return null

/obj/item/blueprint/examine(mob/user)
	. = ..()
	. += span_notice("Schematic: <b>[schematic_name]</b>.")
	var/datum/crafting_recipe/recipe = get_recipe()
	if(recipe)
		var/list/req_names = list()
		for(var/req_path in recipe.reqs)
			var/atom/req_cast = req_path
			var/req_amount = recipe.reqs[req_path]
			req_names += "[req_amount > 1 ? "[req_amount]x " : ""][initial(req_cast.name)]"
		if(length(req_names))
			. += span_notice("Requires: [req_names.Join(", ")].")
		if(length(recipe.machinery))
			var/list/machine_names = list()
			for(var/machine_path in recipe.machinery)
				var/atom/machine_cast = machine_path
				machine_names += initial(machine_cast.name)
			. += span_notice("Needs a [machine_names.Join(" or ")] nearby.")
	. += span_notice("While you're carrying this, the recipe is in your crafting menu. An outpost <b>neural imprinter</b> can burn it into your memory for the rest of the round, but the scroll is destroyed doing it.")

/**
 * # Blueprint recipes
 *
 * Availability of the whole /blueprint subtree is gated in
 * get_visible_recipes (VOID EDIT) — no CRAFT_MUST_BE_LEARNED involved.
 */
/datum/crafting_recipe/blueprint
	time = 10 SECONDS
	category = CAT_WEAPON_RANGED

/// Gun schematics: consume the techweb-gated machined part plus a firing pin.
/// No machinery requirement: craftable anywhere the schematic is available.
/datum/crafting_recipe/blueprint/gun
	tool_behaviors = list(TOOL_SCREWDRIVER, TOOL_WRENCH)

/**
 * Blueprint-crafted guns swap any faction-locked default pin (syndicate
 * implant pins on the C-20r, SAW, Bulldog...) for a clean standard pin, the
 * recipe consumed one as a requirement. Without this the crafted gun would
 * refuse its own crew.
 */
/obj/item/gun/on_craft_completion(list/components, datum/crafting_recipe/current_recipe, atom/crafter)
	. = ..()
	if(!istype(current_recipe, /datum/crafting_recipe/blueprint))
		return
	if(pin && pin.type != /obj/item/firing_pin)
		QDEL_NULL(pin)
	if(!pin)
		pin = new /obj/item/firing_pin(src)

/**
 * # Machined gun part
 *
 * The R&D clock made physical: prints at the protolathe once its techweb
 * part node is researched, then feeds the gun's crafting recipe.
 */
/obj/item/gun_part
	name = "weapon component"
	desc = "A machined firearm component. You'll need the matching schematic to build it into a working gun."
	icon = 'voidcrew/modules/weapons_bench/icons/gun_parts.dmi'
	icon_state = "gun_part"
	lefthand_file = 'voidcrew/modules/weapons_bench/icons/gun_parts_lefthand.dmi'
	righthand_file = 'voidcrew/modules/weapons_bench/icons/gun_parts_righthand.dmi'
	w_class = WEIGHT_CLASS_NORMAL

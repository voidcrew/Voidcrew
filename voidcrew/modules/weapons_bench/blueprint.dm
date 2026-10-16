/**
 * Schematics unlock crafting recipes when carried or neurally imprinted.
 * The availability gate lives in personal_crafting/is_recipe_available().
 */

/// ckey -> list of /datum/crafting_recipe/blueprint types imprinted this round
GLOBAL_LIST_EMPTY(blueprint_imprints)

/**
 * The blueprint-recipe availability gate, called from the VOID EDIT in
 * personal_crafting/is_recipe_available(): carrying the schematic or holding
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
	desc = "A rolled-up fabrication schematic."
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

/**
 * # Blueprint recipes
 *
 * Availability of the whole /blueprint subtree is gated in
 * is_recipe_available (VOID EDIT), no CRAFT_MUST_BE_LEARNED involved.
 */
/datum/crafting_recipe/blueprint
	time = 10 SECONDS
	category = CAT_WEAPON_RANGED

/**
 * # Drug product
 *
 * The finished batch from the lab, packaged by purity tier. A mission-bound
 * recovery item like any other. The pad only takes it for the contract that
 * cooked it; binding vars and the contract examine come from the parent.
 */
/obj/item/mission_recovery/drug_product
	name = "unmarked package"
	desc = "A tightly wrapped package of something you should not be holding during an inspection."
	icon = 'voidcrew/modules/drug_smuggling/icons/drug_items.dmi'
	icon_state = "product_street"
	/// DRUG_PURITY_* tier the batch scored
	var/purity = DRUG_PURITY_STREET
	/// Street name of the recipe this batch was cooked from
	var/street_name

/// Stamp name, desc and packaging from the recipe and the scored purity tier
/obj/item/mission_recovery/drug_product/proc/configure(datum/drug_recipe/recipe, purity_tier)
	purity = purity_tier
	street_name = recipe.street_name
	switch(purity)
		if(DRUG_PURITY_PRIMO)
			name = "primo case of [street_name]"
			desc = "[recipe.product_desc_line] Lab-perfect and case-sealed; the buyer will pay a premium for work this clean."
			icon_state = "product_primo"
		if(DRUG_PURITY_PURE)
			name = "sealed jar of [street_name]"
			desc = "[recipe.product_desc_line] A clean cook, jarred and vacuum-sealed. Respectable product."
			icon_state = "product_pure"
		else
			name = "brick of [street_name]"
			desc = "[recipe.product_desc_line] A rough cut pressed into a brick and wrapped in tape. It'll sell, but nobody's bragging."
			icon_state = "product_street"

/**
 * # Formula chip
 *
 * The mission's shopping list: an encrypted data chip carrying the rolled
 * recipe. Examining it tells the crew what they're cooking, what it needs,
 * and which planet types grow each ingredient.
 */
/obj/item/drug_formula
	name = "encrypted formula chip"
	desc = "A cheap data chip wrapped in shielding tape. Somebody went to real trouble to keep this recipe off the extranet."
	icon = 'voidcrew/modules/drug_smuggling/icons/drug_items.dmi'
	icon_state = "formula_chip"
	w_class = WEIGHT_CLASS_TINY
	/// The recipe this chip encodes
	var/datum/drug_recipe/recipe

/obj/item/drug_formula/Destroy()
	recipe = null
	return ..()

/obj/item/drug_formula/examine(mob/user)
	. = ..()
	if(!recipe)
		. += span_warning("The chip is blank.")
		return
	. += span_notice("Decrypted formula: <b>[recipe.street_name]</b>.")
	for(var/list/entry in recipe.ingredients)
		var/datum/overmap/planet/biome = entry["biome"]
		. += span_notice("Requires: [entry["name"]], harvested on a [initial(biome.name)].")

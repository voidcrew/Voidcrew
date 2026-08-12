/**
 * # Drug ingredients
 *
 * Wild-harvested precursors for the drug smuggling mission. Each grows on one
 * planet type; the formula chip tells the crew which three to go hunt down.
 */
/obj/item/drug_ingredient
	name = "raw precursor"
	desc = "An unrefined chemical precursor. On its own it's just contraband-scented trash."
	icon = 'voidcrew/modules/drug_smuggling/icons/drug_items.dmi'
	icon_state = "wraithvine_resin"
	w_class = WEIGHT_CLASS_SMALL
	/// The /datum/overmap/planet subtype this ingredient is harvested on
	var/biome

/obj/item/drug_ingredient/wraithvine_resin
	name = "wraithvine resin"
	desc = "A wad of dripping black-green resin bled from a strangler vine deep in the canopy. It clings to the wrapper like it's trying to climb out."
	icon_state = "wraithvine_resin"
	biome = /datum/overmap/planet/jungle

/obj/item/drug_ingredient/chromacap_spores
	name = "chromacap spores"
	desc = "A pouch of spores shaken from a mushroom that flashes every color at once. Looking at the dust too long gives you a pounding headache."
	icon_state = "chromacap_spores"
	biome = /datum/overmap/planet/jungle

/obj/item/drug_ingredient/ashrose_petals
	name = "ashrose petals"
	desc = "Petals from a flower that blooms only in cooling lava flows. They stay warm to the touch for weeks and smell faintly of scorched cinnamon."
	icon_state = "ashrose_petals"
	biome = /datum/overmap/planet/lava

/obj/item/drug_ingredient/magmatic_salt
	name = "magmatic salt"
	desc = "A jagged chunk of mineral salt crusted around a volcanic vent. It crackles quietly and stays warm in your hand."
	icon_state = "magmatic_salt"
	biome = /datum/overmap/planet/lava

/obj/item/drug_ingredient/cryoheart_extract
	name = "cryoheart extract"
	desc = "A vial of pale blue fluid pressed from the core of a frost-burrowing organism. Frost creeps up the glass no matter how warm the room is."
	icon_state = "cryoheart_extract"
	biome = /datum/overmap/planet/ice

/obj/item/drug_ingredient/glimmerfrost_crystal
	name = "glimmerfrost crystal"
	desc = "A shard of ice that never melts, chipped from a glacier that hums at night. It sparkles even in the dark."
	icon_state = "glimmerfrost_crystal"
	biome = /datum/overmap/planet/ice

/obj/item/drug_ingredient/tidelily_nectar
	name = "tidelily nectar"
	desc = "Nectar drawn from a flower that blooms in the surf at low tide. Sweet, saline, and mildly luminescent, the fish that drink it swim in spirals."
	icon_state = "tidelily_nectar"
	biome = /datum/overmap/planet/beach

/obj/item/drug_ingredient/driftcoral_powder
	name = "driftcoral powder"
	desc = "Ground coral washed ashore in bone-white branches. The powder changes color with the humidity."
	icon_state = "driftcoral_powder"
	biome = /datum/overmap/planet/beach

/obj/item/drug_ingredient/rustweed_tar
	name = "rustweed tar"
	desc = "A jar of ochre tar boiled down from weeds that grow through collapsed factory floors. It tastes like batteries. Do not ask how anyone knows."
	icon_state = "rustweed_tar"
	biome = /datum/overmap/planet/wasteland

/obj/item/drug_ingredient/scrapland_lichen
	name = "scrapland lichen"
	desc = "A dried mat of lichen peeled off irradiated wreckage. It's the only thing that grows out there, and handling it makes your fingers itch."
	icon_state = "scrapland_lichen"
	biome = /datum/overmap/planet/wasteland

/**
 * # Ingredient cache
 *
 * Weathered stash prop for dressing harvest sites, marks where a previous
 * crew worked the area. Purely decorative.
 */
/obj/structure/ingredient_cache
	name = "weathered stash"
	desc = "A battered crate half-swallowed by the terrain, stripped of anything worth taking. Whoever harvested here didn't plan on coming back."
	icon = 'voidcrew/modules/drug_smuggling/icons/drug_items.dmi'
	icon_state = "ingredient_cache"
	anchored = TRUE
	density = TRUE

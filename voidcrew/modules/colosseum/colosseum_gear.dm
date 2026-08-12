/**
 * # Colosseum arena gear
 *
 * The Lanista's stock: nine bespoke pieces of arena kit sold only at the
 * Grand Colosseum's concourse stall (colosseum_shop.dm). Gladiator panoply,
 * pit armaments and corner-man tools, flavorful mid-power gear, not antag
 * loot. Every piece follows the loot-uniques conventions
 * (voidcrew/modules/loot/uniques/): bespoke ground sprites in
 * 'voidcrew/modules/colosseum/icons/gear.dmi', base-type worn/inhand states
 * reused wherever the base already looks the part, and TRAIT_NO_REPLICATE so
 * duplicators refuse the copy. The only road to these is the sand.
 */

/// Mood bonus for wearing the laurel of the games
#define LAUREL_MOOD_BONUS 2
/// Extra brute a bestiarius pike hit deals to beast-biotype mobs
#define BESTIARIUS_BEAST_BONUS 8

// =========================================================================
// PANOPLY (armor)
// =========================================================================

/**
 * Laurel of the games: the showcase flex piece. Subtypes the costume crown
 * (code/modules/clothing/head/crown.dm) for its slot/armor scaffolding;
 * bespoke ground and worn sprites. Light armor, fireproof gold, and the
 * crowd's favor: a small mood boost while it rests on your brow.
 */
/obj/item/clothing/head/costume/crown/laurel
	name = "laurel of the games"
	desc = "A wreath of gilt laurel leaves, struck for Grand Colosseum champions. It isn't armor and it isn't access - it just tells everyone you won."
	icon = 'voidcrew/modules/colosseum/icons/gear.dmi'
	icon_state = "laurel"
	worn_icon = 'voidcrew/modules/colosseum/icons/gear_worn.dmi'
	worn_icon_state = "laurel"
	armor_type = /datum/armor/crown_laurel
	/// Whether we put the mood event on our current wearer (only worn on the head does)
	var/mood_applied = FALSE

/datum/armor/crown_laurel
	melee = 20
	energy = 10
	fire = 100
	acid = 50
	wound = 10

/obj/item/clothing/head/costume/crown/laurel/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/head/costume/crown/laurel/equipped(mob/living/user, slot)
	. = ..()
	if(slot & ITEM_SLOT_HEAD)
		user.add_mood_event("colosseum_laurel", /datum/mood_event/colosseum_laurel)
		mood_applied = TRUE

/obj/item/clothing/head/costume/crown/laurel/dropped(mob/living/user)
	. = ..()
	// Only clear what we added: dropping a spare laurel from hand must not wipe
	// the mood event another one is granting from the head slot.
	if(!mood_applied)
		return
	mood_applied = FALSE
	user.clear_mood_event("colosseum_laurel")

/datum/mood_event/colosseum_laurel
	description = "I'm wearing the laurels of the games. Everyone can see it."
	mood_change = LAUREL_MOOD_BONUS

/**
 * Galea of the undefeated: the serious helmet. Subtypes the gladiator
 * helmet (code/modules/clothing/head/helmet.dm) so the worn and inhand
 * sprites come free; the ground sprite is bespoke bronze. Real melee
 * protection with poor showing against energy weapons. It was forged for
 * swords, not lasers.
 */
/obj/item/clothing/head/helmet/gladiator/galea
	name = "galea of the undefeated"
	desc = "A bronze fighting helm in the old Colosseum pattern, visor grille and all. Great against swords, a lot less so against lasers."
	icon = 'voidcrew/modules/colosseum/icons/gear.dmi'
	icon_state = "galea"
	worn_icon_state = "gladiator"
	armor_type = /datum/armor/helmet_galea
	resistance_flags = FIRE_PROOF

/datum/armor/helmet_galea
	melee = 40
	bullet = 20
	laser = 20
	energy = 15
	bomb = 25
	fire = 100
	acid = 50
	wound = 15

/obj/item/clothing/head/helmet/gladiator/galea/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/**
 * Pit champion's spaulder: one-shouldered bronze harness. Chest-and-arms
 * armor with zero slowdown, and harness loops sized for pit kit: the pike,
 * the net, a shield or a whetstone all ride the suit slot's storage.
 */
/obj/item/clothing/suit/armor/spaulder
	name = "pit champion's spaulder"
	desc = "A single bronze pauldron and half-cuirass on a leather harness, cut so the sword arm swings free. The strap loops only fit arena kit: a spear, a bola, a shield or a whetstone."
	icon = 'voidcrew/modules/colosseum/icons/gear.dmi'
	icon_state = "spaulder"
	worn_icon = 'voidcrew/modules/colosseum/icons/gear_worn.dmi'
	worn_icon_state = "spaulder"
	blood_overlay_type = "armor"
	body_parts_covered = CHEST|ARMS
	armor_type = /datum/armor/armor_spaulder
	slowdown = 0
	equip_delay_other = 40
	resistance_flags = FIRE_PROOF
	allowed = list(
		/obj/item/spear,
		/obj/item/restraints/legcuffs/bola,
		/obj/item/shield,
		/obj/item/sharpener,
	)

/datum/armor/armor_spaulder
	melee = 35
	bullet = 25
	laser = 25
	energy = 20
	bomb = 30
	fire = 80
	acid = 50
	wound = 15

/obj/item/clothing/suit/armor/spaulder/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/**
 * Sandstrider sandals: the footwork piece. Subtypes the wooden sandal
 * (code/modules/clothing/shoes/sandals.dm, inhand states free) with a
 * bespoke worn state in gear_worn.dmi, and carries the galoshes' no-slip
 * trait: blood, water and spilled drinks on the sand stop being a way to
 * lose a match.
 */
/obj/item/clothing/shoes/sandal/sandstrider
	name = "sandstrider sandals"
	desc = "Arena-pattern fighting sandals with a cork sole and a bronze toe cap. The tread keeps you upright on wet stone and bloody sand."
	icon = 'voidcrew/modules/colosseum/icons/gear.dmi'
	icon_state = "sandstriders"
	worn_icon = 'voidcrew/modules/colosseum/icons/gear_worn.dmi'
	worn_icon_state = "sandstriders"
	clothing_traits = list(TRAIT_NO_SLIP_WATER)
	armor_type = /datum/armor/sandal_sandstrider
	resistance_flags = NONE

// Feet-only clothing may only carry bio/fire/acid armor (see the
// gloves_and_shoes_armor unit test), anything else would need the sandals to
// cover the legs, which they plainly do not.
/datum/armor/sandal_sandstrider
	bio = 10
	fire = 50
	acid = 30

/obj/item/clothing/shoes/sandal/sandstrider/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

// =========================================================================
// ARMAMENTS (weapons)
// =========================================================================

/**
 * Bestiarius pike: the beast-hunter's polearm. Subtypes /obj/item/spear
 * (code/game/objects/items/spear.dm) following the bamboospear recipe:
 * icon_prefix drives the wielded/unwielded ground states ("bestiarius0/1",
 * both in gear.dmi); inhands reuse the base polearm files. Hits on
 * beast-biotype mobs strike harder, forged for the Beast Interlude, and
 * for whatever the planets grow.
 */
/obj/item/spear/bestiarius
	name = "bestiarius pike"
	desc = "A boar-spear with a bronze-shod haft and a cross-lugged blade. Built for the beast interludes, and it hits beasts a lot harder than it hits people."
	icon = 'voidcrew/modules/colosseum/icons/gear.dmi'
	icon_state = "bestiarius0"
	base_icon_state = "bestiarius0"
	icon_prefix = "bestiarius"
	inhand_icon_state = "bamboo_spear0"
	// No bespoke back sprite in gear.dmi; reuse the bamboo spear's, same as inhands.
	worn_icon_state = "bamboo_spear0"
	force_unwielded = 11
	force_wielded = 19
	throwforce = 21

/obj/item/spear/bestiarius/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

// No headpike crafting out of the unique, spare it the spear's slapcraft recipe
/obj/item/spear/bestiarius/add_headpike_component()
	return

/obj/item/spear/bestiarius/attack(mob/living/target_mob, mob/living/user, list/modifiers, list/attack_modifiers)
	if(istype(target_mob) && (target_mob.mob_biotypes & MOB_BEAST))
		MODIFY_ATTACK_FORCE(attack_modifiers, BESTIARIUS_BEAST_BONUS)
	return ..()

/**
 * Retiarius' weighted net: the crowd favorite. Subtypes the bola
 * (code/game/objects/items/handcuffs.dm) for the whole throw-and-ensnare
 * kit; longer knockdown and a slower escape, because a proper net fight
 * should end with someone on the floor.
 */
/obj/item/restraints/legcuffs/bola/retiarius
	name = "retiarius' weighted net"
	desc = "A lead-weighted throwing net. Tangles the legs, puts the target on the floor, and takes a while to get out of. Trident sold separately."
	icon = 'voidcrew/modules/colosseum/icons/gear.dmi'
	icon_state = "retiarius_net"
	knockdown = 3 SECONDS
	breakouttime = 6 SECONDS

/obj/item/restraints/legcuffs/bola/retiarius/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/**
 * Parmula of the pit: the duelist's shield. Subtypes the wooden buckler
 * (code/game/objects/items/shields.dm, inhand states free) with a bronze
 * rim: better block odds, tougher, and it doesn't burn.
 */
/obj/item/shield/buckler/parmula
	name = "parmula of the pit"
	desc = "A small round parrying shield: hide over cork over a bronze rim. Light enough to box with, tough enough to stop a saber."
	icon_state = "parmula"
	icon = 'voidcrew/modules/colosseum/icons/gear.dmi'
	// No bespoke back sprite in gear.dmi; reuse the wooden buckler's, same as inhands.
	worn_icon_state = "buckler"
	block_chance = 35
	max_integrity = 90
	resistance_flags = NONE

/obj/item/shield/buckler/parmula/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

// =========================================================================
// PIT KIT (tools)
// =========================================================================

/**
 * Pit doctor's satchel: the corner-man's bag. A medkit subtype
 * (code/game/objects/items/storage/medkit.dm, inhand states free) stocked
 * for arena trauma: sutures, mesh, gauze, bone gel and one adrenaline pen.
 */
/obj/item/storage/medkit/pit_doctor
	name = "pit doctor's satchel"
	desc = "A scuffed leather satchel in Grand Colosseum infirmary colors. Stocked for exactly the kind of injuries the arena hands out."
	icon = 'voidcrew/modules/colosseum/icons/gear.dmi'
	icon_state = "pit_satchel"
	damagetype_healed = BRUTE

/obj/item/storage/medkit/pit_doctor/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/storage/medkit/pit_doctor/PopulateContents()
	if(empty)
		return
	new /obj/item/stack/medical/suture(src)
	new /obj/item/stack/medical/suture(src)
	new /obj/item/stack/medical/mesh(src)
	new /obj/item/stack/medical/mesh(src)
	new /obj/item/stack/medical/gauze(src)
	new /obj/item/stack/medical/bone_gel(src)
	new /obj/item/reagent_containers/hypospray/medipen(src)

/**
 * Grindstone of the games: the armorer's counter stone. A sharpener
 * subtype (code/game/objects/items/sharpener.dm) with five workings per
 * stone; same edge cap as the standard whetstone, it just doesn't quit
 * after one blade.
 */
/obj/item/sharpener/grindstone
	name = "grindstone of the games"
	desc = "A worn disc of arena stone for putting an edge on a blade. Good for several sharpenings before it wears smooth."
	icon = 'voidcrew/modules/colosseum/icons/gear.dmi'
	icon_state = "grindstone"
	uses = 5
	prefix = "arena-honed"

/obj/item/sharpener/grindstone/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

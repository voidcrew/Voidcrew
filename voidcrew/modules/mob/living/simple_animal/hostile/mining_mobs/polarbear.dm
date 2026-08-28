/**
 * VOIDCREW: elite bear, ported from Voidcrew-LRP.
 *
 * Upstream refactored the polar bear from `/mob/living/simple_animal/hostile/asteroid/polarbear`
 * into `/mob/living/basic/mining/polarbear`, which left these two subtypes hanging off a
 * path that only still existed because this file mentioned it - they compiled, inherited
 * nothing, and would have spawned as blank simple animals. Reparented onto the basic mob,
 * the same way wave 1 handled `wolf.dm` next door.
 *
 * No AI work was needed here: the warbear takes the parent's
 * `/datum/ai_controller/basic_controller/polar` and its compiled tree, which is exactly
 * what the old subtype did - it never overrode the AI, only the numbers.
 *
 * One line did not survive: `move_to_delay = 7`, a 12.5% pursuit-speed edge over the old
 * base bear's 8. Basic mobs have no `move_to_delay`; pursuit cadence comes from `speed`
 * and the controller's `movement_delay` now, and upstream's own conversion already made
 * every polar bear faster (`speed` 3 -> 2). Rather than invent a replacement number the
 * warbear simply keeps its parent's speed. See the notes for a playtest flag.
 */
/mob/living/basic/mining/polarbear/warrior
	name = "polar warbear"
	desc = "An aggressive animal that defends its territory with incredible power. This one appears to be a remnant of the short-lived Wojtek-Aleph program."
	icon = 'voidcrew/icons/mob/icemoon/icemoon_monsters.dmi'
	icon_state = "warbear"
	icon_living = "warbear"
	icon_dead = "warbear_dead"
	melee_damage_lower = 35
	melee_damage_upper = 35
	attack_verb_continuous = "CQB's"
	attack_verb_simple = "CQB"
	maxHealth = 400
	health = 400
	obj_damage = 60
	crusher_loot = /obj/item/crusher_trophy/war_paw
	butcher_results = list(/obj/item/food/meat/slab/bear = 3, /obj/item/stack/sheet/bone = 2, /obj/item/stack/sheet/animalhide/goliath_hide/polar_bear_hide = 3)
	guaranteed_butcher_results = list(/obj/item/stack/sheet/animalhide/goliath_hide/polar_bear_hide = 3, /obj/item/bear_armor = 1)

/obj/item/crusher_trophy/war_paw
	name = "armored bear paw"
	desc = "It's a paw from a true warrior. Still remembers the basics of CQB."
	icon = 'voidcrew/icons/obj/elite_trophies.dmi'
	icon_state = "armor_paw"
	denied_type = /obj/item/crusher_trophy/war_paw

/obj/item/crusher_trophy/war_paw/effect_desc()
	return "doubled strikes when below 70% health"

/obj/item/crusher_trophy/war_paw/on_mark_detonation(mob/living/target, mob/living/user, obj/item/kinetic_crusher/pkc)
	. = ..()
	if(user.health / user.maxHealth > 0.7)
		return
	var/obj/item/held_item = user.get_active_held_item()
	if(!held_item)
		return
	held_item.melee_attack_chain(user, target, null)

/**
 * The spawn-table entry: usually an ordinary polar bear, occasionally a warbear.
 *
 * The common case rolls nothing and this mob simply carries on as itself, which is only
 * a bear at all now that its parent is one again - under the dangling simple-animal path
 * that branch left a blank, nameless, AI-less mob standing on the ice, and the biome
 * tables spawn this type in the hundreds. Reparenting is the whole fix; the 15% warbear
 * swap is unchanged, and matches how `wolf/random` picks its alpha.
 */
/mob/living/basic/mining/polarbear/random/Initialize(mapload)
	. = ..()
	if(!prob(15))
		return
	new /mob/living/basic/mining/polarbear/warrior(loc)
	return INITIALIZE_HINT_QDEL

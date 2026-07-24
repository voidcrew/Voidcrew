//elite bear, ported from Voidcrew-LRP
/mob/living/simple_animal/hostile/asteroid/polarbear/warrior
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
	move_to_delay = 7
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

/obj/item/crusher_trophy/war_paw/on_mark_detonation(mob/living/target, mob/living/user)
	if(user.health / user.maxHealth > 0.7)
		return
	var/obj/item/held_item = user.get_active_held_item()
	if(!held_item)
		return
	held_item.melee_attack_chain(user, target, null)

/mob/living/simple_animal/hostile/asteroid/polarbear/random/Initialize()
	. = ..()
	if(prob(15))
		new /mob/living/simple_animal/hostile/asteroid/polarbear/warrior(loc)
		return INITIALIZE_HINT_QDEL

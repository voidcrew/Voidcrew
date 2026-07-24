//alpha wolf- smaller chance to spawn, practically a miniboss. Has the ability to do a short, untelegraphed lunge with a stun. Be careful!
/mob/living/basic/mining/wolf/alpha
	name = "alpha wolf"
	desc = "An old wolf with matted, dirty fur and a missing eye, trophies of many won battles and successful hunts. Seems like they're the leader of the pack around here. Watch out for the lunge!"
	icon = 'voidcrew/icons/mob/icemoon/icemoon_monsters.dmi'
	icon_state = "alphawolf"
	icon_living = "alphawolf"
	icon_dead = "alphawolf_dead"
	speed = 2
	maxHealth = 100
	health = 100
	melee_damage_lower = 10
	melee_damage_upper = 10
	crusher_loot = /obj/item/crusher_trophy/fang
	ai_controller = /datum/ai_controller/basic_controller/wolf/alpha
	/// Our lunge ability
	var/datum/action/cooldown/mob_cooldown/charge/basic_charge/lunge

/mob/living/basic/mining/wolf/alpha/Initialize(mapload)
	. = ..()
	lunge = new(src)
	lunge.Grant(src)
	ai_controller.set_blackboard_key(BB_TARGETED_ACTION, lunge)

/mob/living/basic/mining/wolf/alpha/Destroy()
	QDEL_NULL(lunge)
	return ..()

/datum/ai_controller/basic_controller/wolf/alpha
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/pet_planning,
		/datum/ai_planning_subtree/call_reinforcements/wolf,
		/datum/ai_planning_subtree/target_retaliate,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/targeted_mob_ability,
		/datum/ai_planning_subtree/attack_obstacle_in_path,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)

/mob/living/basic/mining/wolf/alpha/gib()
	move_force = MOVE_FORCE_DEFAULT
	move_resist = MOVE_RESIST_DEFAULT
	pull_force = PULL_FORCE_DEFAULT
	if(prob(75))
		new /obj/item/crusher_trophy/fang(loc)
		visible_message(span_warning("You find an intact fang that looks salvagable."))
	..()

/obj/item/crusher_trophy/fang
	name = "battle-stained fang"
	desc = "A wolf fang, displaying the wear and tear associated with a long and colorful life. Could be attached to a kinetic crusher or used to make a trophy."
	icon = 'voidcrew/icons/obj/elite_trophies.dmi'
	icon_state = "fang"
	denied_type = /obj/item/crusher_trophy/fang
	var/bleed_stacks_per_hit = 5

/obj/item/crusher_trophy/fang/effect_desc()
	return "waveform collapse to build up a small stack of bleeding, causing a burst of damage if applied repeatedly."

/obj/item/crusher_trophy/fang/on_mark_detonation(mob/living/M, mob/living/user)
	if(istype(M) && (M.mob_biotypes & MOB_ORGANIC))
		var/datum/status_effect/stacking/saw_bleed/bloodletting/B = M.has_status_effect(/datum/status_effect/stacking/saw_bleed/bloodletting)
		if(!B)
			M.apply_status_effect(/datum/status_effect/stacking/saw_bleed/bloodletting, bleed_stacks_per_hit)
		else
			B.add_stacks(bleed_stacks_per_hit)

/mob/living/basic/mining/wolf/random/Initialize()
	. = ..()
	if(prob(15))
		new /mob/living/basic/mining/wolf/alpha(loc)
		return INITIALIZE_HINT_QDEL

/mob/living/basic/mining/wolf/wasteland
	faction = list(FACTION_WASTELAND)

/mob/living/basic/mining/wolf/alpha/wasteland
	faction = list(FACTION_WASTELAND)

/mob/living/basic/mining/wolf/wasteland/random/Initialize()
	. = ..()
	if(prob(15))
		new /mob/living/basic/mining/wolf/alpha/wasteland(loc)
		return INITIALIZE_HINT_QDEL

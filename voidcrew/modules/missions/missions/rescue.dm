/**
 * # Rescue & Repatriation
 *
 * "A survivor's beacon is still pinging inside that wreck. Bring them back
 * breathing - the fee doubles if they can still walk."
 *
 * Recovery variant where the objective breathes: a survivor NPC spawns in
 * the target ruin, follows whoever asks (or rides a fireman carry), and the
 * mission turns in while they're alive beside the ship's mission pad.
 * Survivor death burns a retarget ("another beacon"). The non-gunner's
 * recovery mission.
 */
/datum/mission/rescue
	name = "Rescue Contract"
	weight = 8
	mission_limit = 2
	voucher_count = 1
	quest_lost_policy = MISSION_QUEST_LOST_RETARGET
	gps_tag_prefix = "RESQ"
	// The survivor cannot defend themselves, so this contract does not share a
	// wreck with a bounty's entourage or anybody else's spawns
	exclusive_site = TRUE
	// Green-band pay; the unharmed bonus doubles credits at turn-in
	value_min = 800
	value_max = 1100

/datum/mission/rescue/setup_target()
	var/datum/mission_target/space_ruin/ruin_target = new(src)
	if(!ruin_target.resolve())
		qdel(ruin_target)
		return FALSE
	target = ruin_target
	return TRUE

/datum/mission/rescue/generate_details()
	var/static/list/survivor_stories = list(
		"salvage tech",
		"stranded courier",
		"survey intern",
		"claims adjuster",
		"freighter deckhand",
	)
	objective_name = pick(survivor_stories)

/datum/mission/rescue/build_objectives()
	add_objective(new /datum/mission_objective/field/escort)

/datum/mission/rescue/update_text()
	var/datum/mission_objective/field/escort/escort = objectives[1]
	name = "Rescue Contract: [objective_name]"
	desc = "A [objective_name]'s survival beacon is still pinging inside the signal at ([target.target_x], [target.target_y]) in the [target_zone_name]. \
		Bring them back alive, on or beside your ship's mission pad, then turn in at the mission board. \
		The credit fee doubles if they arrive with at least [escort.unharmed_threshold * 100]% health and have not needed revival. \
		They'll follow whoever offers a hand, or ride a fireman carry. \
		If their vitals stop, revive them within [DisplayTimeText(escort.revival_grace)] to save the contract, minus the bonus. \
		Payment includes [voucher_count] trade voucher[voucher_count > 1 ? "s" : ""]. \
		Tap a GPS unit on the mission board to receive the survivor's beacon ([gps_tag])."

/datum/mission/rescue/waypoint_label()
	return "Rescue: [objective_name]"

/**
 * # Mission Survivor
 *
 * The living objective: friendly, fragile, and clingy on request. An empty
 * hand toggles follow; they never fight back.
 *
 * They are immune to the environment on purpose. The contract puts them inside
 * wrecks, and a wreck is airless and near absolute zero: on tg's basic-mob
 * defaults this mob takes 1 brute (no air to breathe) plus 2 burn (body temp
 * under 250K, which it reaches in a single tick at -30K/s) every two-second
 * Life tick from the moment it spawns. That is 60 HP of survivor in forty
 * seconds, and the survivor spawns when the crew's ship docks - so they were
 * dead before anyone could walk across the ruin to them, every single time, on
 * every airless site. Their suit is what they have been surviving in; only
 * violence gets to kill them.
 */
/mob/living/basic/mission_survivor
	name = "survivor"
	desc = "Somebody who has had a very long week and would love to see a ship interior again. Their emergency softsuit is patched in three places and still holding."
	icon = 'icons/mob/simple/simple_human.dmi'
	maxHealth = 60
	health = 60
	melee_damage_lower = 0
	melee_damage_upper = 0
	combat_mode = FALSE
	mob_biotypes = MOB_ORGANIC | MOB_HUMANOID
	sentience_type = SENTIENCE_HUMANOID
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	speak_emote = list("croaks")

	/// Who the survivor is currently following, if anyone
	var/datum/weakref/following_ref

/mob/living/basic/mission_survivor/Initialize(mapload)
	. = ..()
	var/static/list/survivor_names = list("Adler", "Bex", "Cato", "Dova", "Emin", "Farrow", "Ines", "Jun", "Kest", "Loami")
	name = "survivor ([pick(survivor_names)])"
	real_name = name
	apply_dynamic_human_appearance(src, outfit_path = /datum/outfit/job/assistant)

/mob/living/basic/mission_survivor/examine(mob/user)
	. = ..()
	var/mob/following = following_ref?.resolve()
	if(following)
		. += span_notice("They're sticking close to [following]. An empty hand tells them to stay put.")
	else
		. += span_notice("Offer them an empty hand and they'll follow you.")

/mob/living/basic/mission_survivor/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(. || user.combat_mode)
		return
	var/mob/following = following_ref?.resolve()
	if(following == user)
		stop_following()
		balloon_alert(user, "waiting here")
		say("I'll... wait right here.")
	else
		start_following(user)
		balloon_alert(user, "following you")
		say("Right behind you. Please don't be wrong about the way out.")
	return TRUE

/mob/living/basic/mission_survivor/proc/start_following(mob/living/leader)
	following_ref = WEAKREF(leader)
	GLOB.move_manager.move_to(src, leader, 1, 4)

/mob/living/basic/mission_survivor/proc/stop_following()
	following_ref = null
	GLOB.move_manager.stop_looping(src)

/mob/living/basic/mission_survivor/death(gibbed)
	stop_following()
	return ..()

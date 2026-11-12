// Package: P6 NPCs. Plasma pirates on human NPC bodies (PR #512).
//
// Human pirates hold real guns chosen by their faction's outfit table (human_npc_outfits_pirates.dm) and
// fire them through /datum/pirate_gun_handling (npc_ships/code/pirate_guns.dm). Here:
// - yellow- and red-zone gunners of the six gun-carrying factions can be dressed with a Cinder, red-zone
//   ones with a Furnace (weights as S12: Cinder 2, Furnace 1 next to the faction's own guns); green-zone
//   pirates never carry plasma;
// - the red-zone Director Prime and Chief Auditor carry a Furnace; both may drop the Old Furnace, but
//   only when met in a red zone;
// - a plasma gunner changes flasks for real (load_flask(), a do_after), carrying a spare;
// - a Furnace runs the real heat model in its hands, so the pirate minds it: it vents by hand only where
//   the gas can't catch (near-vacuum or no oxygen), and anywhere else it holds fire and backs off once the
//   coils are hot, until they cool. It never boils indoors.
// NPC gear is locked to the body (human_npc_gear.dm), so none of this becomes loot.

/// Coil heat at which a pirate stops firing its Furnace where it can't vent
#define PIRATE_PLASMA_HOLD_HEAT 80
/// Coil heat at which it starts firing again
#define PIRATE_PLASMA_RESUME_HEAT 40
/// Coil heat at which it vents where venting is safe
#define PIRATE_PLASMA_VENT_HEAT 60
/// Below this pressure (kPa), or this oxygen partial pressure, vented plasma can't catch
#define PIRATE_PLASMA_VENT_PRESSURE 1
#define PIRATE_PLASMA_VENT_OXYGEN 1
/// Blackboard: TRUE while it waits for its coils to cool
#define BB_PIRATE_PLASMA_COOLING "pirate_plasma_cooling"
/// It backs away from a target closer than this while its coils cool
#define PIRATE_PLASMA_BACK_OFF_RANGE 5

// ===== HANDLING =====

/// The Cinder: a pair every six seconds.
/datum/pirate_gun_handling/plasma
	gun_type = /obj/item/gun/energy/plasma_weapon
	shots = 2
	shot_gap = 0.5 SECONDS
	volley_gap = 6 SECONDS
	reload_lines = list("Changing flasks!", "Cover me!")
	dry_lines = list("Flask's dry!", "Out of plasma!")

/// The Furnace: one bolt every four seconds.
/datum/pirate_gun_handling/plasma/rifle
	gun_type = /obj/item/gun/energy/plasma_weapon/rifle
	shots = 1
	volley_gap = 4 SECONDS

// ===== ARMING: flasks and heat =====

/// A plasma gun it holds, or null
/proc/pirate_plasma_held_gun(mob/living/carbon/npc)
	for(var/obj/item/gun/energy/plasma_weapon/gun in npc.held_items)
		return gun
	return null

/// A spare flask it carries with at least a shot in it for `gun`, or null
/proc/pirate_plasma_spare_flask(mob/living/carbon/npc, obj/item/gun/energy/plasma_weapon/gun)
	var/obj/item/ammo_casing/energy/shot = length(gun.ammo_type) ? gun.ammo_type[gun.select] : null
	var/needed = max(shot?.e_cost, 1)
	for(var/obj/item/plasma_flask/flask in npc.get_all_contents_type(/obj/item/plasma_flask))
		if(flask == gun.flask || flask.loc == gun || flask.stored < needed)
			continue
		if(npc.is_holding(flask) || human_npc_can_draw(npc, flask))
			return flask
	return null

/// Whether plasma vented at `spot` can't catch: next to no air, or no oxygen in it
/proc/pirate_plasma_safe_to_vent(turf/spot)
	var/datum/gas_mixture/air = spot?.return_air_readonly()
	if(isnull(air))
		return TRUE
	var/pressure = air.return_pressure()
	if(pressure < PIRATE_PLASMA_VENT_PRESSURE)
		return TRUE
	return human_npc_partial_pressure(air, /datum/gas/oxygen, pressure) < PIRATE_PLASMA_VENT_OXYGEN

/// Says one of `lines`, if it can talk
/proc/pirate_plasma_shout(mob/living/carbon/npc, list/lines)
	if(length(lines) && human_npc_can_talk(npc))
		INVOKE_ASYNC(npc, TYPE_PROC_REF(/atom/movable, say), pick(lines))

// A plasma gunner minds its coils and changes its own flasks before the base arming (draw a knife when dry)
/datum/ai_planning_subtree/human_npc_arm/pirate_crew/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/carbon/npc = controller.pawn
	var/obj/item/gun/energy/plasma_weapon/gun = pirate_plasma_held_gun(npc)
	if(isnull(gun) || HAS_TRAIT(npc, TRAIT_HANDS_BLOCKED) || LAZYLEN(npc.do_afters))
		controller.clear_blackboard_key(BB_PIRATE_PLASMA_COOLING)
		return ..()
	. = pirate_plasma_mind_heat(controller, npc, gun)
	if(.)
		return
	if(gun.can_shoot() || world.time < controller.blackboard[BB_HUMAN_NPC_ARMING_RETRY_AT])
		return ..()
	if(!gun.can_fire_heat())
		// The second after a vent: it waits for its gun
		controller.queue_behavior(/datum/ai_behavior/npc_combat_sense_hold)
		return SUBTREE_RETURN_FINISH_PLANNING
	if(isnull(pirate_plasma_spare_flask(npc, gun)))
		return ..()
	controller.queue_behavior(/datum/ai_behavior/pirate_plasma_reload)
	if(prob(PIRATE_CREW_RELOAD_BARK_CHANCE))
		var/datum/pirate_gun_handling/handling = pirate_gun_handling_for(gun)
		pirate_plasma_shout(npc, handling.reload_lines)
	return SUBTREE_RETURN_FINISH_PLANNING

/**
 * A Furnace's heat, as its holder sees the coils glow. Where the gas can't catch it vents by hand once
 * the coils are warm. Anywhere else it never vents: past PIRATE_PLASMA_HOLD_HEAT it stops firing and backs
 * off from whoever it is fighting until the coils are down to PIRATE_PLASMA_RESUME_HEAT. Returns
 * SUBTREE_RETURN_FINISH_PLANNING while it is busy with its gun.
 */
/datum/ai_planning_subtree/human_npc_arm/pirate_crew/proc/pirate_plasma_mind_heat(datum/ai_controller/controller, mob/living/carbon/npc, obj/item/gun/energy/plasma_weapon/gun)
	if(!gun.uses_heat)
		return
	var/heat = gun.barrel_heat
	var/cooling = controller.blackboard[BB_PIRATE_PLASMA_COOLING]
	if(cooling && heat <= PIRATE_PLASMA_RESUME_HEAT)
		controller.clear_blackboard_key(BB_PIRATE_PLASMA_COOLING)
		cooling = FALSE
	if(heat >= PIRATE_PLASMA_VENT_HEAT && world.time >= gun.next_vent_at && gun.chamber_mol() > 0 && pirate_plasma_safe_to_vent(get_turf(npc)))
		controller.queue_behavior(/datum/ai_behavior/pirate_plasma_vent)
		return SUBTREE_RETURN_FINISH_PLANNING
	if(!cooling && heat < PIRATE_PLASMA_HOLD_HEAT)
		return
	if(!cooling)
		controller.set_blackboard_key(BB_PIRATE_PLASMA_COOLING, TRUE)
		pirate_plasma_shout(npc, list("She's cooking!", "Too hot!", "Cover me, she's cooking!"))
	var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(!QDELETED(target) && get_dist(npc, target) < PIRATE_PLASMA_BACK_OFF_RANGE)
		controller.queue_behavior(/datum/ai_behavior/step_away, BB_BASIC_MOB_CURRENT_TARGET)
	else
		controller.queue_behavior(/datum/ai_behavior/npc_combat_sense_hold)
	return SUBTREE_RETURN_FINISH_PLANNING

/// A player's vent: the gun in the active hand, used in hand (attack_self(), plasma_heat.dm).
/datum/ai_behavior/pirate_plasma_vent
	action_cooldown = 0.5 SECONDS

/datum/ai_behavior/pirate_plasma_vent/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/carbon/npc = controller.pawn
	var/obj/item/gun/energy/plasma_weapon/gun = pirate_plasma_held_gun(npc)
	if(isnull(gun) || !human_npc_ready_item(npc, gun))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	pirate_plasma_shout(npc, list("Venting!"))
	if(!gun.attack_self(npc))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/**
 * A player's flask change, one step per action: take the spare in the free hand, click the gun with it
 * (load_flask(): a do_after, and the spent flask comes out). Fails, and the base arming draws a knife, if
 * it has no spare or no hand free.
 */
/datum/ai_behavior/pirate_plasma_reload
	action_cooldown = 0.8 SECONDS
	/// Gives up after this long, so a flask that won't go in can't hold the NPC forever
	var/give_up_after = 8 SECONDS

/datum/ai_behavior/pirate_plasma_reload/setup(datum/ai_controller/controller)
	. = ..()
	var/mob/living/carbon/npc = controller.pawn
	var/obj/item/gun/energy/plasma_weapon/gun = pirate_plasma_held_gun(npc)
	if(isnull(gun))
		return FALSE
	controller.set_blackboard_key(BB_HUMAN_NPC_RELOAD_UNTIL, world.time + give_up_after)
	npc.visible_message(span_notice("[npc] changes the flask in [gun]."))

/datum/ai_behavior/pirate_plasma_reload/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/carbon/npc = controller.pawn
	var/obj/item/gun/energy/plasma_weapon/gun = pirate_plasma_held_gun(npc)
	if(isnull(gun) || world.time >= controller.blackboard[BB_HUMAN_NPC_RELOAD_UNTIL])
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	if(gun.can_shoot())
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED
	var/obj/item/plasma_flask/flask = pirate_plasma_spare_flask(npc, gun)
	if(isnull(flask))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	if(!npc.is_holding(flask))
		if(!human_npc_take_in_hand(npc, flask))
			return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
		return AI_BEHAVIOR_DELAY
	if(!human_npc_ready_item(npc, flask))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	controller.ai_interact(target = gun, combat_mode = FALSE)
	return AI_BEHAVIOR_DELAY

/datum/ai_behavior/pirate_plasma_reload/finish_action(datum/ai_controller/controller, succeeded)
	. = ..()
	// A change that got nowhere isn't tried again straight away; the NPC fights with what it has.
	controller.set_blackboard_key(BB_HUMAN_NPC_ARMING_RETRY_AT, succeeded ? 0 : world.time + 10 SECONDS)

// ===== DRESSING =====

/// A spare flask, filled, for a pirate's pocket or belt
/obj/item/plasma_flask/full
	stored = PLASMA_FLASK_CAPACITY

/obj/item/plasma_flask/full/Initialize(mapload)
	. = ..()
	update_appearance()

/datum/human_npc_outfit_table/pirate
	/// This faction's Cinder gunner, for yellow- and red-zone crews. Null: the faction carries no plasma.
	var/plasma_pistol_outfit
	/// This faction's Furnace gunner, for red-zone crews
	var/plasma_rifle_outfit
	/// What its boss wears in a red zone, if that differs. Null: `boss` everywhere.
	var/list/red_boss
	/// Choice lists with the plasma gunners added, by "list ref-zone"; built on first use
	var/list/plasma_choices

// Yellow and red: a regular gunner may be a plasma gunner, and a red-zone boss may carry its Furnace.
/datum/human_npc_outfit_table/pirate/outfits_for(mob/living/carbon/human/npc/npc, zone)
	. = ..()
	if(zone != ZONE_YELLOW && zone != ZONE_RED)
		return
	var/rank = npc?.npc_rank || HUMAN_NPC_RANK_REGULAR
	if(rank >= HUMAN_NPC_RANK_BOSS)
		if(zone == ZONE_RED && length(red_boss))
			return red_boss
		return
	if(rank >= HUMAN_NPC_RANK_ELITE || !plasma_pistol_outfit)
		return
	var/list/choices = .
	// A crew's duelists stay duelists
	if(!length(choices) || choices == melee)
		return
	return plasma_gunner_choices(choices, zone)

/// `choices` with this faction's plasma gunners added for `zone`. Never changes `choices`.
/datum/human_npc_outfit_table/pirate/proc/plasma_gunner_choices(list/choices, zone)
	var/key = "[REF(choices)]-[zone]"
	var/list/cached = LAZYACCESS(plasma_choices, key)
	if(cached)
		return cached
	cached = choices.Copy()
	cached[plasma_pistol_outfit] = 2
	if(zone == ZONE_RED && plasma_rifle_outfit)
		cached[plasma_rifle_outfit] = 1
	LAZYSET(plasma_choices, key, cached)
	return cached

/datum/human_npc_outfit_table/pirate/silverscale
	plasma_pistol_outfit = /datum/outfit/piratecorpse/faction/silverscale/ranged/cinder
	plasma_rifle_outfit = /datum/outfit/piratecorpse/faction/silverscale/ranged/furnace

/datum/human_npc_outfit_table/pirate/skeleton
	plasma_pistol_outfit = /datum/outfit/piratecorpse/faction/skeleton/ranged/cinder
	plasma_rifle_outfit = /datum/outfit/piratecorpse/faction/skeleton/ranged/furnace

/datum/human_npc_outfit_table/pirate/grey
	plasma_pistol_outfit = /datum/outfit/piratecorpse/faction/grey/ranged/cinder
	plasma_rifle_outfit = /datum/outfit/piratecorpse/faction/grey/ranged/furnace

/datum/human_npc_outfit_table/pirate/lustrous
	plasma_pistol_outfit = /datum/outfit/piratecorpse/faction/lustrous/ranged/cinder
	plasma_rifle_outfit = /datum/outfit/piratecorpse/faction/lustrous/ranged/furnace

/datum/human_npc_outfit_table/pirate/interdyne
	plasma_pistol_outfit = /datum/outfit/piratecorpse/faction/interdyne/ranged/cinder
	plasma_rifle_outfit = /datum/outfit/piratecorpse/faction/interdyne/ranged/furnace
	red_boss = list(/datum/outfit/piratecorpse/faction/interdyne/prime/armed/furnace = 1)

/datum/human_npc_outfit_table/pirate/irs
	plasma_pistol_outfit = /datum/outfit/piratecorpse/faction/irs/ranged/cinder
	plasma_rifle_outfit = /datum/outfit/piratecorpse/faction/irs/ranged/furnace
	red_boss = list(/datum/outfit/piratecorpse/faction/irs/chief/armed/furnace = 1)

// The gunners: the gun, a spare flask, and a knife for when the plasma runs out.

/datum/outfit/piratecorpse/faction/silverscale/ranged/cinder
	name = "Human NPC: Silverscale Marksman (Cinder)"
	r_hand = /obj/item/gun/energy/plasma_weapon/pistol
	l_pocket = /obj/item/plasma_flask/full
	r_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/silverscale/ranged/furnace
	name = "Human NPC: Silverscale Marksman (Furnace)"
	r_hand = /obj/item/gun/energy/plasma_weapon/rifle
	l_pocket = /obj/item/plasma_flask/full
	r_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/skeleton/ranged/cinder
	name = "Human NPC: Skeleton Gunner (Cinder)"
	r_hand = /obj/item/gun/energy/plasma_weapon/pistol
	l_pocket = /obj/item/plasma_flask/full
	r_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/skeleton/ranged/furnace
	name = "Human NPC: Skeleton Gunner (Furnace)"
	r_hand = /obj/item/gun/energy/plasma_weapon/rifle
	l_pocket = /obj/item/plasma_flask/full
	r_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/grey/ranged/cinder
	name = "Human NPC: Grey Tider Gunner (Cinder)"
	r_hand = /obj/item/gun/energy/plasma_weapon/pistol
	l_pocket = /obj/item/plasma_flask/full
	r_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/grey/ranged/furnace
	name = "Human NPC: Grey Tider Gunner (Furnace)"
	r_hand = /obj/item/gun/energy/plasma_weapon/rifle
	l_pocket = /obj/item/plasma_flask/full
	r_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/lustrous/ranged/cinder
	name = "Human NPC: Lustrous Coruscant (Cinder)"
	r_hand = /obj/item/gun/energy/plasma_weapon/pistol
	l_pocket = /obj/item/plasma_flask/full
	r_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/lustrous/ranged/furnace
	name = "Human NPC: Lustrous Coruscant (Furnace)"
	r_hand = /obj/item/gun/energy/plasma_weapon/rifle
	l_pocket = /obj/item/plasma_flask/full
	r_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/interdyne/ranged/cinder
	name = "Human NPC: Interdyne Pharmacist (Cinder)"
	r_hand = /obj/item/gun/energy/plasma_weapon/pistol
	l_pocket = /obj/item/plasma_flask/full
	r_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/interdyne/ranged/furnace
	name = "Human NPC: Interdyne Pharmacist (Furnace)"
	r_hand = /obj/item/gun/energy/plasma_weapon/rifle
	l_pocket = /obj/item/plasma_flask/full
	r_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/irs/ranged/cinder
	name = "Human NPC: IRS Agent (Cinder)"
	r_hand = /obj/item/gun/energy/plasma_weapon/pistol
	l_pocket = /obj/item/plasma_flask/full
	r_pocket = /obj/item/knife/combat/survival

/datum/outfit/piratecorpse/faction/irs/ranged/furnace
	name = "Human NPC: IRS Agent (Furnace)"
	r_hand = /obj/item/gun/energy/plasma_weapon/rifle
	l_pocket = /obj/item/plasma_flask/full
	r_pocket = /obj/item/knife/combat/survival

// The red-zone bosses: a Furnace in place of the laser, the spare flask on the belt.

/datum/outfit/piratecorpse/faction/interdyne/prime/armed/furnace
	name = "Human NPC: Interdyne Director Prime (Furnace)"
	r_hand = /obj/item/gun/energy/plasma_weapon/rifle
	belt = /obj/item/plasma_flask/full

/datum/outfit/piratecorpse/faction/irs/chief/armed/furnace
	name = "Human NPC: IRS Chief Auditor (Furnace)"
	r_hand = /obj/item/gun/energy/plasma_weapon/rifle
	belt = /obj/item/plasma_flask/full

// ===== THE OLD FURNACE =====

/mob/living/carbon/human/npc/faction_pirate/interdyne/boss
	rare_loot_pool = list(/obj/item/gun/energy/plasma_weapon/rifle/old_furnace)

/mob/living/carbon/human/npc/faction_pirate/irs/boss
	rare_loot_pool = list(/obj/item/gun/energy/plasma_weapon/rifle/old_furnace)

// The Old Furnace is a red-zone prize: a boss met anywhere else never drops it
/mob/living/carbon/human/npc/faction_pirate/npc_roll_death_loot()
	. = ..()
	if(npc_home_zone() != ZONE_RED)
		var/list/rolled = .
		rolled -= /obj/item/gun/energy/plasma_weapon/rifle/old_furnace

// The same for the legacy basic-mob bosses (faction_pirate_bosses.dm)
/mob/living/basic/trooper/pirate/faction/boss/initialize_weapon_loot(zone)
	if(!weapon_loot_initialized && zone != ZONE_RED && rolled_rare_loot)
		rolled_rare_loot -= /obj/item/gun/energy/plasma_weapon/rifle/old_furnace
	return ..()

#undef PIRATE_PLASMA_HOLD_HEAT
#undef PIRATE_PLASMA_RESUME_HEAT
#undef PIRATE_PLASMA_VENT_HEAT
#undef PIRATE_PLASMA_VENT_PRESSURE
#undef PIRATE_PLASMA_VENT_OXYGEN
#undef BB_PIRATE_PLASMA_COOLING
#undef PIRATE_PLASMA_BACK_OFF_RANGE

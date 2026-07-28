/**
 * # Armory uniques — sealed ordnance cache
 *
 * Six one-off prizes for the ARMORY loot tables (voidcrew/modules/loot/zone_loot.dm,
 * see /obj/structure/closet/crate/zone_loot/armory and its /rare variant). Each item
 * carries a bespoke mechanic rather than a stat bump, per the design catalog at
 * obsidian/voidcrew/Rare-loot-uniques.md ("ARMORY — sealed ordnance cache").
 *
 * Tiers: green = Handloader's vise, Sergeant's whistle. Yellow = Phalanx buckler,
 * Marksman's cant. Red = The garrison standard, "Knock-Knock".
 *
 * All six carry TRAIT_NO_REPLICATE (voidcrew/_DEFINES/loot.dm) so duplicators like the
 * Helios pattern stamp refuse to copy them. None of these are wired into the loot
 * tables yet — that's a follow-up edit to zone_loot.dm, out of scope here.
 */

/// Delay between rounds revived by the handloader's vise (a magazine's worth a minute)
#define HANDLOADERS_VISE_RELOAD_DELAY (8 SECONDS)
/// Cooldown between blasts of the sergeant's whistle
#define SERGEANTS_WHISTLE_COOLDOWN (60 SECONDS)
/// View radius that can hear the sergeant's whistle
#define SERGEANTS_WHISTLE_RANGE 7
/// Fraction of a stun/knockdown's remaining duration shaken off by the whistle
#define SERGEANTS_WHISTLE_SHAKEOFF 0.5
/// How long the sergeant's whistle's speed buff lasts
#define SERGEANTS_WHISTLE_HASTE_DURATION (4 SECONDS)
/// How long the wearer of the marksman's cant must stand still before the shot settles
#define MARKSMANS_CANT_STILLNESS (2 SECONDS)
/// Knockdown applied to a target hit by a settled marksman's cant shot
#define MARKSMANS_CANT_STAGGER (1.5 SECONDS)
/// View radius of the garrison standard's aura
#define GARRISON_STANDARD_AURA_RANGE 7
/// Damage-taken multiplier applied to friendlies under the garrison standard's aura
#define GARRISON_STANDARD_DAMAGE_MULT 0.85
/// Max internal charge of the Knock-Knock gauntlet, in punches
#define KNOCK_KNOCK_MAX_CHARGE 8
/// Charge consumed per empowered punch
#define KNOCK_KNOCK_CHARGE_PER_PUNCH 1
/// Charge regenerated per second while the internal cell recharges
#define KNOCK_KNOCK_RECHARGE_RATE 0.5
/// Brute damage a Knock-Knock punch deals to an airlock's integrity
#define KNOCK_KNOCK_AIRLOCK_DAMAGE 170
/// Brute damage dealt to a mob punched by Knock-Knock
#define KNOCK_KNOCK_MOB_DAMAGE 12
/// Tiles a mob punched by Knock-Knock is thrown back
#define KNOCK_KNOCK_THROW_RANGE 4

// =============================================================================
// GREEN — Handloader's vise
// Table-mount reloading press: consumes spent casings + iron sheets left on the
// table, reviving them into live rounds one at a time via newshot() (see
// /obj/item/ammo_casing/proc/newshot, code/modules/projectiles/ammunition/_ammunition.dm).
// Fired casings keep their instance and projectile_type (fire_casing() only nulls
// loaded_projectile), so this works on any spent casing regardless of caliber.
// =============================================================================

/obj/item/handloaders_vise
	name = "handloader's vise"
	desc = "A pocket reloading press, armory-issue. Clamp it to a table stocked with spent casings and iron and it turns them back into live rounds."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "handloaders_vise"
	force = 5
	throwforce = 0
	w_class = WEIGHT_CLASS_SMALL
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT)
	/// Prevents starting a second overlapping reload loop
	var/busy = FALSE

/obj/item/handloaders_vise/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/handloaders_vise/attack_self(mob/living/user)
	. = ..()
	if(busy)
		balloon_alert(user, "already clamped down!")
		return
	var/turf/mount = find_mounting_table(user)
	if(!mount)
		balloon_alert(user, "needs a table!")
		return
	if(!(locate(/obj/item/stack/sheet/iron) in mount))
		balloon_alert(user, "no scrap metal on the table!")
		return
	if(!locate_spent_casing(mount))
		balloon_alert(user, "no spent casings to work!")
		return

	busy = TRUE
	balloon_alert(user, "clamping vise...")
	var/reloaded = 0
	while(TRUE)
		var/obj/item/ammo_casing/spent_case = locate_spent_casing(mount)
		var/obj/item/stack/sheet/iron/scrap = locate(/obj/item/stack/sheet/iron) in mount
		if(!spent_case || !scrap || scrap.get_amount() < 1)
			break
		if(!do_after(user, HANDLOADERS_VISE_RELOAD_DELAY, target = user, extra_checks = CALLBACK(src, PROC_REF(still_mounted), user, mount)))
			break
		if(QDELETED(spent_case) || spent_case.loaded_projectile || QDELETED(scrap) || scrap.get_amount() < 1)
			continue
		scrap.use(1)
		spent_case.newshot()
		spent_case.update_appearance()
		reloaded++
		balloon_alert(user, "reloaded a round")
	busy = FALSE
	if(reloaded)
		to_chat(user, span_notice("You unclamp [src], having reloaded [reloaded] round\s."))
	else
		balloon_alert(user, "unclamped")

/// Extra_checks callback for the reload do_after loop - the user has to stay put, holding the vise, next to the table.
/obj/item/handloaders_vise/proc/still_mounted(mob/living/user, turf/mount)
	return !QDELETED(user) && !QDELETED(mount) && user.Adjacent(mount) && (user.get_active_held_item() == src)

/// Finds a table turf the user is standing on or directly beside.
/obj/item/handloaders_vise/proc/find_mounting_table(mob/living/user)
	var/turf/user_turf = get_turf(user)
	if(!user_turf)
		return null
	if(locate(/obj/structure/table) in user_turf)
		return user_turf
	for(var/direction in GLOB.cardinals)
		var/turf/checked = get_step(user_turf, direction)
		if(locate(/obj/structure/table) in checked)
			return checked
	return null

/// Finds a spent (unloaded) casing sitting on the mount turf.
/obj/item/handloaders_vise/proc/locate_spent_casing(turf/mount)
	for(var/obj/item/ammo_casing/casing in mount)
		if(!casing.loaded_projectile && casing.projectile_type)
			return casing
	return null

// =============================================================================
// GREEN — Sergeant's whistle
// Subtypes the existing police whistle (/obj/item/clothing/mask/whistle,
// code/modules/clothing/masks/hailer.dm) for its sprite and worn-mask action-button
// wiring. Overrides ui_action_click entirely instead of calling the parent's HALT!
// shout. Blast halves the remaining duration of hearers' active stun/knockdown
// (/datum/status_effect/incapacitating/stun and /knockdown, via the base
// /datum/status_effect/proc/remove_duration helper) and grants a short speed buff.
// Audible to anyone in view, hostiles included - that's the drawback.
// =============================================================================

/datum/action/item_action/sergeants_whistle_blast
	name = "Blow whistle"

/obj/item/clothing/mask/whistle/sergeants
	name = "sergeant's whistle"
	desc = "A brass pea whistle on a bootlace. One blast shakes everyone in earshot out of a stun and gets them moving - enemies included."
	actions_types = list(/datum/action/item_action/sergeants_whistle_blast)

/obj/item/clothing/mask/whistle/sergeants/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/mask/whistle/sergeants/ui_action_click(mob/living/user, action)
	if(!COOLDOWN_FINISHED(src, whistle_cooldown))
		balloon_alert(user, "still cooling down")
		return
	COOLDOWN_START(src, whistle_cooldown, SERGEANTS_WHISTLE_COOLDOWN)
	user.visible_message(
		span_danger("[user] blows [src] sharply!"),
		span_notice("You blow [src] sharply!"),
	)
	playsound(src, 'sound/items/whistle/whistle.ogg', 75, FALSE, 6)
	for(var/mob/living/hearer in get_hearers_in_view(SERGEANTS_WHISTLE_RANGE, src))
		rally_hearer(hearer)

/// Shakes off half of a hearer's remaining stun/knockdown, then gives them a short burst of speed.
/obj/item/clothing/mask/whistle/sergeants/proc/rally_hearer(mob/living/hearer)
	var/datum/status_effect/incapacitating/stun/stun_effect = hearer.IsStun()
	if(stun_effect)
		stun_effect.remove_duration((stun_effect.duration - world.time) * SERGEANTS_WHISTLE_SHAKEOFF)
	var/datum/status_effect/incapacitating/knockdown/knockdown_effect = hearer.IsKnockdown()
	if(knockdown_effect)
		knockdown_effect.remove_duration((knockdown_effect.duration - world.time) * SERGEANTS_WHISTLE_SHAKEOFF)
	hearer.apply_status_effect(/datum/status_effect/sergeants_second_wind)

/// Brief movement speed buff granted by the sergeant's whistle's blast.
/datum/status_effect/sergeants_second_wind
	id = "sergeants_second_wind"
	duration = SERGEANTS_WHISTLE_HASTE_DURATION
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null
	status_type = STATUS_EFFECT_REFRESH

/datum/status_effect/sergeants_second_wind/on_apply()
	var/datum/movespeed_modifier/sergeants_second_wind/speed_mod = new()
	owner.add_movespeed_modifier(speed_mod, update = TRUE)
	return TRUE

/datum/status_effect/sergeants_second_wind/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/sergeants_second_wind, update = TRUE)

/datum/movespeed_modifier/sergeants_second_wind
	multiplicative_slowdown = -0.35

// =============================================================================
// YELLOW — Phalanx buckler
// Subtypes the riot shield (/obj/item/shield/riot, code/game/objects/items/shields.dm)
// for its sprite, armor, and baseline block_chance/hit_reaction. Raising it adds a
// heavy movespeed penalty and registers COMSIG_PROJECTILE_PREHIT on the wielder and
// on whoever's standing directly behind them (opposite the wielder's facing),
// intercepting shots that originate from the direction the wielder is facing.
// Returning PROJECTILE_INTERRUPT_HIT from that signal consumes the projectile before
// on_hit/damage resolves (see process_hit_loop() in code/modules/projectiles/projectile.dm).
// =============================================================================

/obj/item/shield/riot/phalanx_buckler
	name = "Phalanx buckler"
	desc = "A tower shield cut down and re-plated by hand. Raised, it stops shots coming at you or at whoever's standing right behind you."
	/// Whether the shield is currently raised, covering the wielder's front and their rear-flank ally
	var/raised = FALSE
	/// The mob currently wielding this shield, tracked while raised for cleanup
	var/mob/living/wielder
	/// Mobs currently covered by the raised shield (wielder + rear ally), for signal cleanup
	var/list/covered_mobs = list()

/obj/item/shield/riot/phalanx_buckler/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/shield/riot/phalanx_buckler/Destroy()
	lower_shield()
	return ..()

/obj/item/shield/riot/phalanx_buckler/dropped(mob/user)
	lower_shield()
	return ..()

/obj/item/shield/riot/phalanx_buckler/attack_self(mob/living/user)
	. = ..()
	if(user.get_active_held_item() != src)
		balloon_alert(user, "hold it first!")
		return
	if(raised)
		lower_shield()
	else
		raise_shield(user)

/// Raises the shield: heavy slowdown, plus projectile coverage for the wielder and their rear flank.
/obj/item/shield/riot/phalanx_buckler/proc/raise_shield(mob/living/user)
	raised = TRUE
	wielder = user
	balloon_alert(user, "shield raised")
	var/datum/movespeed_modifier/phalanx_raised/speed_penalty = new()
	user.add_movespeed_modifier(speed_penalty, update = TRUE)
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(refresh_coverage))
	RegisterSignal(user, COMSIG_ATOM_DIR_CHANGE, PROC_REF(refresh_coverage))
	refresh_coverage(user)

/// Lowers the shield and cleans up every signal/movespeed hook it registered.
/obj/item/shield/riot/phalanx_buckler/proc/lower_shield()
	raised = FALSE
	if(wielder)
		balloon_alert(wielder, "shield lowered")
		wielder.remove_movespeed_modifier(/datum/movespeed_modifier/phalanx_raised, update = TRUE)
		UnregisterSignal(wielder, list(COMSIG_MOVABLE_MOVED, COMSIG_ATOM_DIR_CHANGE))
	for(var/mob/living/covered as anything in covered_mobs)
		UnregisterSignal(covered, COMSIG_PROJECTILE_PREHIT)
	covered_mobs = list()
	wielder = null

/// Re-registers projectile coverage on the wielder and whoever's standing behind them. Signal handler for movement/turning.
/obj/item/shield/riot/phalanx_buckler/proc/refresh_coverage(atom/source, ...)
	SIGNAL_HANDLER
	if(!raised || QDELETED(wielder))
		return
	for(var/mob/living/covered as anything in covered_mobs)
		UnregisterSignal(covered, COMSIG_PROJECTILE_PREHIT)
	covered_mobs = list()

	RegisterSignal(wielder, COMSIG_PROJECTILE_PREHIT, PROC_REF(try_block_projectile))
	covered_mobs += wielder

	var/turf/rear_turf = get_step(wielder, turn(wielder.dir, 180))
	var/mob/living/rear_ally = rear_turf ? (locate(/mob/living) in rear_turf) : null
	if(rear_ally && rear_ally != wielder)
		RegisterSignal(rear_ally, COMSIG_PROJECTILE_PREHIT, PROC_REF(try_block_projectile))
		covered_mobs += rear_ally

/// Signal handler for COMSIG_PROJECTILE_PREHIT on a covered mob. Blocks shots coming from the wielder's facing.
/obj/item/shield/riot/phalanx_buckler/proc/try_block_projectile(mob/living/protected_mob, obj/projectile/incoming)
	SIGNAL_HANDLER
	if(!raised || QDELETED(wielder))
		return NONE
	var/turf/wielder_turf = get_turf(wielder)
	var/turf/origin_turf = incoming.starting || get_turf(incoming)
	if(!wielder_turf || !origin_turf || origin_turf == wielder_turf)
		return NONE
	var/incoming_dir = get_dir(wielder_turf, origin_turf)
	if(!(incoming_dir & wielder.dir))
		return NONE
	playsound(protected_mob, block_sound, 50, TRUE)
	protected_mob.balloon_alert(protected_mob, "blocked!")
	return PROJECTILE_INTERRUPT_HIT

/// Movement penalty applied to the wielder while the Phalanx buckler is raised.
/datum/movespeed_modifier/phalanx_raised
	multiplicative_slowdown = 0.6

// =============================================================================
// YELLOW — Marksman's cant
// Subtypes plain sunglasses (/obj/item/clothing/glasses/sunglasses,
// code/modules/clothing/glasses/_glasses.dm) for its sprite. Standing still for
// MARKSMANS_CANT_STILLNESS "settles" the cant; the next shot fired zeroes bonus
// spread (COMSIG_MOB_FIRED_GUN's bonus_spread_values list - see
// code/modules/deathmatch/deathmatch_modifier.dm's ocelot/stormtrooper modifiers for
// the reference pattern) and zeroes that specific projectile's accuracy_falloff
// (COMSIG_PROJECTILE_FIRER_BEFORE_FIRE), then knocks the target down on impact
// (COMSIG_PROJECTILE_SELF_ON_HIT). One settle, one shot - moving breaks it.
// =============================================================================

/obj/item/clothing/glasses/sunglasses/marksmans_cant
	name = "marksman's cant"
	desc = "Shooting glasses with a spirit level etched into the top rim. Stand still a couple of seconds and your next shot goes exactly where you point it."
	/// Whether the cant has settled and is ready to true up the next shot
	var/settled = FALSE
	/// The mob currently wearing the cant, tracked for signal cleanup
	var/mob/living/wearer

/obj/item/clothing/glasses/sunglasses/marksmans_cant/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/glasses/sunglasses/marksmans_cant/equipped(mob/living/user, slot)
	. = ..()
	if(!(slot & ITEM_SLOT_EYES))
		return
	wearer = user
	settled = FALSE
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(on_wearer_moved))
	RegisterSignal(user, COMSIG_MOB_FIRED_GUN, PROC_REF(on_fired_gun))
	RegisterSignal(user, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE, PROC_REF(on_projectile_before_fire))
	reset_stillness_timer()

/obj/item/clothing/glasses/sunglasses/marksmans_cant/dropped(mob/user)
	if(wearer)
		UnregisterSignal(wearer, list(COMSIG_MOVABLE_MOVED, COMSIG_MOB_FIRED_GUN, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE))
	settled = FALSE
	wearer = null
	return ..()

/// (Re)schedules the settle timer, keyed uniquely per glasses instance so movement just pushes it back.
/obj/item/clothing/glasses/sunglasses/marksmans_cant/proc/reset_stillness_timer()
	addtimer(CALLBACK(src, PROC_REF(become_settled)), MARKSMANS_CANT_STILLNESS, TIMER_UNIQUE | TIMER_OVERRIDE)

/// Signal handler: any movement by the wearer breaks the settle and restarts the stillness clock.
/obj/item/clothing/glasses/sunglasses/marksmans_cant/proc/on_wearer_moved(atom/source, atom/old_loc, dir, forced, list/old_locs)
	SIGNAL_HANDLER
	if(settled)
		balloon_alert(wearer, "cant lost")
	settled = FALSE
	reset_stillness_timer()

/obj/item/clothing/glasses/sunglasses/marksmans_cant/proc/become_settled()
	if(QDELETED(wearer) || wearer.stat == DEAD || loc != wearer)
		return
	settled = TRUE
	balloon_alert(wearer, "settled")

/// Signal handler for COMSIG_MOB_FIRED_GUN: zeroes bonus spread on the settled shot.
/obj/item/clothing/glasses/sunglasses/marksmans_cant/proc/on_fired_gun(mob/living/user, obj/item/gun/gun_fired, atom/target, params, zone_override, list/bonus_spread_values)
	SIGNAL_HANDLER
	if(!settled)
		return
	bonus_spread_values[MIN_BONUS_SPREAD_INDEX] = 0
	bonus_spread_values[MAX_BONUS_SPREAD_INDEX] = 0

/// Signal handler for COMSIG_PROJECTILE_FIRER_BEFORE_FIRE: trues up and marks the settled shot, then consumes the settle.
/obj/item/clothing/glasses/sunglasses/marksmans_cant/proc/on_projectile_before_fire(mob/living/user, obj/projectile/projectile, datum/fired_from, atom/original)
	SIGNAL_HANDLER
	if(!settled)
		return
	projectile.accuracy_falloff = 0
	RegisterSignal(projectile, COMSIG_PROJECTILE_SELF_ON_HIT, PROC_REF(on_settled_hit))
	settled = FALSE
	balloon_alert(user, "cant spent")
	// Start the next settle immediately — without this, a shooter who stays
	// perfectly still after firing would never settle again until they moved
	reset_stillness_timer()

/// Signal handler for COMSIG_PROJECTILE_SELF_ON_HIT on the trued-up shot: staggers whatever it hits.
/obj/item/clothing/glasses/sunglasses/marksmans_cant/proc/on_settled_hit(obj/projectile/source, atom/movable/firer, atom/target, angle, hit_limb_zone, blocked, pierce_hit)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_PROJECTILE_SELF_ON_HIT)
	if(blocked >= 100 || !isliving(target))
		return
	var/mob/living/hit_mob = target
	hit_mob.Knockdown(MARKSMANS_CANT_STAGGER)

// =============================================================================
// RED — The garrison standard
// Fresh item, sprite copied verbatim from the Nanotrasen banner
// (/obj/item/station_charter/banner, code/game/objects/items/charter.dm) rather than
// subtyped, since the banner's station-renaming mechanic has nothing to do with this
// item. Wrenching it to the floor spawns a destructible anchored structure
// (/obj/structure/destructible, code/game/objects/structures/destructible_structures.dm)
// whose process() grants nearby friendlies a damage-taken multiplier via
// /datum/physiology (see modules/antagonists/voidwalker/voidwalker_traumas.dm and the
// dna_infuser organ sets for precedent) and periodically shaves down their active
// stun/knockdown, same remove_duration() trick as the sergeant's whistle.
// =============================================================================

/obj/item/garrison_standard
	name = "the garrison standard"
	desc = "A unit banner, colors faded almost to gray. Wrench it down to plant it."
	icon = 'icons/obj/banner.dmi'
	icon_state = "banner"
	inhand_icon_state = "banner"
	lefthand_file = 'icons/mob/inhands/equipment/banners_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/banners_righthand.dmi'
	w_class = WEIGHT_CLASS_HUGE
	force = 8

/obj/item/garrison_standard/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/garrison_standard/wrench_act(mob/living/user, obj/item/tool)
	. = ..()
	if(!isturf(loc))
		balloon_alert(user, "needs solid ground!")
		return TRUE
	var/turf/plant_turf = loc
	balloon_alert(user, "planting standard...")
	if(!tool.use_tool(src, user, 3 SECONDS, volume = 50))
		return TRUE
	if(QDELETED(src) || loc != plant_turf)
		return TRUE
	new /obj/structure/destructible/garrison_standard(plant_turf)
	qdel(src)
	return TRUE

/// The planted, defensible form of the garrison standard. Cuttable down by anyone who reaches it (standard structure damage).
/obj/structure/destructible/garrison_standard
	name = "the garrison standard"
	desc = "A unit banner, planted. Friendlies within sight take reduced damage and shrug off stuns faster."
	icon = 'icons/obj/banner.dmi'
	icon_state = "banner"
	anchored = TRUE
	density = FALSE
	max_integrity = 60
	break_message = span_warning("The garrison standard is cut down!")
	break_sound = 'sound/effects/meteorimpact.ogg'

/obj/structure/destructible/garrison_standard/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/structure/destructible/garrison_standard/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/structure/destructible/garrison_standard/process(seconds_per_tick)
	for(var/mob/living/carbon/human/friendly in view(GARRISON_STANDARD_AURA_RANGE, src))
		if(friendly.stat == DEAD)
			continue
		friendly.apply_status_effect(/datum/status_effect/garrison_standard_aura)
		var/datum/status_effect/incapacitating/stun/stun_effect = friendly.IsStun()
		if(stun_effect)
			stun_effect.remove_duration(2 SECONDS * seconds_per_tick)
		var/datum/status_effect/incapacitating/knockdown/knockdown_effect = friendly.IsKnockdown()
		if(knockdown_effect)
			knockdown_effect.remove_duration(2 SECONDS * seconds_per_tick)

/// Damage-taken reduction granted to anyone standing near a planted garrison standard. Refreshes while in range, expires shortly after leaving.
/datum/status_effect/garrison_standard_aura
	id = "garrison_standard_aura"
	duration = 3 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null
	status_type = STATUS_EFFECT_REFRESH

/datum/status_effect/garrison_standard_aura/on_apply()
	if(!ishuman(owner))
		return FALSE
	var/mob/living/carbon/human/human_owner = owner
	if(!human_owner.physiology)
		return FALSE
	human_owner.physiology.brute_mod *= GARRISON_STANDARD_DAMAGE_MULT
	human_owner.physiology.burn_mod *= GARRISON_STANDARD_DAMAGE_MULT
	return TRUE

/datum/status_effect/garrison_standard_aura/on_remove()
	if(!ishuman(owner))
		return
	var/mob/living/carbon/human/human_owner = owner
	if(!human_owner.physiology)
		return
	human_owner.physiology.brute_mod /= GARRISON_STANDARD_DAMAGE_MULT
	human_owner.physiology.burn_mod /= GARRISON_STANDARD_DAMAGE_MULT

// =============================================================================
// RED — "Knock-Knock"
// Fresh gloves, sprite copied verbatim from boxing gloves
// (/obj/item/clothing/gloves/boxing and /boxing/evil, code/modules/clothing/gloves/boxing.dm)
// rather than subtyped, to avoid dragging in boxing's martial-art-giver component,
// which would otherwise fight with this item's own COMSIG_LIVING_UNARMED_ATTACK hook.
// Two punches devastate a wall turf (dismantle_wall(devastated = TRUE), same call
// /datum/element/wall_smasher uses in code/datums/elements/wall_smasher.dm) and one
// heavy punch nearly finishes an airlock's atom_integrity; mobs take a moderate hit
// and get thrown back, powerfist-style (code/game/objects/items/powerfist.dm). Every
// empowered punch drains the internal cell; it recharges passively over time.
// =============================================================================

/obj/item/clothing/gloves/knock_knock
	name = "\"Knock-Knock\""
	desc = "A powered breaching gauntlet with AFTER YOU stamped across the knuckle plate. Punches straight through walls and airlocks."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "knock_gauntlet"
	worn_icon = 'voidcrew/modules/loot/icons/uniques_worn.dmi'
	worn_icon_state = "knock_gauntlet"
	force = 10
	obj_flags = CONDUCTS_ELECTRICITY
	/// Current internal cell charge, in punches
	var/charge = KNOCK_KNOCK_MAX_CHARGE
	/// Wall turfs currently cracked (one hit landed, one more finishes them)
	var/list/wall_hits = list()

/obj/item/clothing/gloves/knock_knock/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)
	START_PROCESSING(SSobj, src)

/obj/item/clothing/gloves/knock_knock/Destroy()
	STOP_PROCESSING(SSobj, src)
	wall_hits = null
	return ..()

/obj/item/clothing/gloves/knock_knock/process(seconds_per_tick)
	if(charge < KNOCK_KNOCK_MAX_CHARGE)
		charge = min(KNOCK_KNOCK_MAX_CHARGE, charge + (KNOCK_KNOCK_RECHARGE_RATE * seconds_per_tick))

/obj/item/clothing/gloves/knock_knock/equipped(mob/living/user, slot)
	. = ..()
	if(!(slot & ITEM_SLOT_GLOVES))
		return
	RegisterSignal(user, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_unarmed_attack))

/obj/item/clothing/gloves/knock_knock/dropped(mob/user)
	UnregisterSignal(user, COMSIG_LIVING_UNARMED_ATTACK)
	return ..()

/// Signal handler for COMSIG_LIVING_UNARMED_ATTACK: breaches walls/airlocks, or hits and throws back mobs.
/obj/item/clothing/gloves/knock_knock/proc/on_unarmed_attack(mob/living/puncher, atom/target, proximity_flag, list/modifiers)
	SIGNAL_HANDLER
	// Combat mode only — this signal fires on every empty-hand click, and the
	// gauntlet must not breach the airlock you're just trying to open (or
	// launch someone you're helping up)
	if(!proximity_flag || !puncher.combat_mode)
		return NONE
	if(charge < KNOCK_KNOCK_CHARGE_PER_PUNCH)
		balloon_alert(puncher, "gauntlet drained!")
		return NONE

	if(iswallturf(target) && !isindestructiblewall(target))
		punch_wall(puncher, target)
		return COMPONENT_HOSTILE_NO_ATTACK

	if(istype(target, /obj/machinery/door/airlock))
		punch_airlock(puncher, target)
		return COMPONENT_HOSTILE_NO_ATTACK

	if(isliving(target) && target != puncher)
		punch_mob(puncher, target)
		return COMPONENT_HOSTILE_NO_ATTACK

	return NONE

/// Two empowered punches devastate a wall.
/obj/item/clothing/gloves/knock_knock/proc/punch_wall(mob/living/puncher, turf/closed/wall/wall_turf)
	charge -= KNOCK_KNOCK_CHARGE_PER_PUNCH
	puncher.changeNext_move(CLICK_CD_MELEE)
	puncher.do_attack_animation(wall_turf)
	var/hits = (wall_hits[wall_turf] || 0) + 1
	if(hits >= 2)
		wall_hits -= wall_turf
		playsound(wall_turf, 'sound/effects/meteorimpact.ogg', 100, TRUE)
		wall_turf.dismantle_wall(devastated = TRUE)
	else
		wall_hits[wall_turf] = hits
		playsound(wall_turf, 'sound/items/weapons/genhit2.ogg', 50, TRUE)
		wall_turf.balloon_alert(puncher, "cracked!")

/// A heavy punch that all but finishes an airlock.
/obj/item/clothing/gloves/knock_knock/proc/punch_airlock(mob/living/puncher, obj/machinery/door/airlock/airlock_target)
	charge -= KNOCK_KNOCK_CHARGE_PER_PUNCH
	puncher.changeNext_move(CLICK_CD_MELEE)
	puncher.do_attack_animation(airlock_target)
	playsound(airlock_target, 'sound/effects/meteorimpact.ogg', 75, TRUE)
	airlock_target.take_damage(KNOCK_KNOCK_AIRLOCK_DAMAGE, BRUTE, MELEE, TRUE, get_dir(puncher, airlock_target))

/// A moderate hit that throws the target back.
/obj/item/clothing/gloves/knock_knock/proc/punch_mob(mob/living/puncher, mob/living/hit_mob)
	charge -= KNOCK_KNOCK_CHARGE_PER_PUNCH
	puncher.changeNext_move(CLICK_CD_MELEE)
	playsound(puncher, 'sound/items/weapons/punch1.ogg', 50, TRUE)
	hit_mob.visible_message(
		span_danger("[puncher] slams [hit_mob] with [src]!"),
		span_userdanger("[puncher] slams into you with [src]!"),
	)
	hit_mob.apply_damage(KNOCK_KNOCK_MOB_DAMAGE, BRUTE, wound_bonus = CANT_WOUND)
	if(!QDELETED(hit_mob))
		var/atom/throw_target = get_edge_target_turf(hit_mob, get_dir(puncher, get_step_away(hit_mob, puncher)))
		hit_mob.throw_at(throw_target, KNOCK_KNOCK_THROW_RANGE, 2)
	log_combat(puncher, hit_mob, "breached", src)

#undef HANDLOADERS_VISE_RELOAD_DELAY
#undef SERGEANTS_WHISTLE_COOLDOWN
#undef SERGEANTS_WHISTLE_RANGE
#undef SERGEANTS_WHISTLE_SHAKEOFF
#undef SERGEANTS_WHISTLE_HASTE_DURATION
#undef MARKSMANS_CANT_STILLNESS
#undef MARKSMANS_CANT_STAGGER
#undef GARRISON_STANDARD_AURA_RANGE
#undef GARRISON_STANDARD_DAMAGE_MULT
#undef KNOCK_KNOCK_MAX_CHARGE
#undef KNOCK_KNOCK_CHARGE_PER_PUNCH
#undef KNOCK_KNOCK_RECHARGE_RATE
#undef KNOCK_KNOCK_AIRLOCK_DAMAGE
#undef KNOCK_KNOCK_MOB_DAMAGE
#undef KNOCK_KNOCK_THROW_RANGE

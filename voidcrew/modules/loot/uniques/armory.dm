/**
 * # Armory uniques: sealed ordnance cache
 *
 * Six one-off prizes for the ARMORY loot tables (voidcrew/modules/loot/zone_loot.dm,
 * see /obj/structure/closet/crate/zone_loot/armory). Each item
 * carries a bespoke mechanic rather than a stat bump, per the design catalog at
 * obsidian/voidcrew/Rare-loot-uniques.md ("ARMORY: sealed ordnance cache").
 *
 * Tiers: green = Handloader's vise, Sergeant's whistle. Yellow = Phalanx buckler,
 * Marksman's cant. Red = The garrison standard, "Knock-Knock".
 *
 * All six carry TRAIT_NO_REPLICATE (voidcrew/_DEFINES/loot.dm) so duplicators like the
 * Helios pattern stamp refuse to copy them. None of these are wired into the loot
 * tables yet, that's a follow-up edit to zone_loot.dm, out of scope here.
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
/// Cooldown before the marksman's cant can settle another shot
#define MARKSMANS_CANT_COOLDOWN (30 SECONDS)
/// Anti-spam gap between "still cooling down" alerts from the marksman's cant
#define MARKSMANS_CANT_WARN_GAP (5 SECONDS)
/// Knockdown applied to a target hit by a settled marksman's cant shot
#define MARKSMANS_CANT_STAGGER (1.5 SECONDS)
/// View radius of the garrison standard's aura
#define GARRISON_STANDARD_AURA_RANGE 7
/// Damage-taken multiplier applied to friendlies under the garrison standard's aura
#define GARRISON_STANDARD_DAMAGE_MULT 0.85
/// Colour of the pulse that plays on anyone the garrison standard is buffing
#define GARRISON_STANDARD_AURA_COLOR "#e0bd63"
/// Max internal charge of the Knock-Knock gauntlet, in punches
#define KNOCK_KNOCK_MAX_CHARGE 5
/// Charge consumed per empowered punch
#define KNOCK_KNOCK_CHARGE_PER_PUNCH 1
/// Charge regenerated per second once the gauntlet starts recharging
#define KNOCK_KNOCK_RECHARGE_RATE 0.25
/// Dead time after a punch before the internal cell starts recharging at all
#define KNOCK_KNOCK_RECHARGE_DELAY (5 SECONDS)
/// Brute damage a Knock-Knock punch deals to a door, door frame or girder
#define KNOCK_KNOCK_BREACH_DAMAGE 170
/// Brute damage dealt to a mob punched by Knock-Knock
#define KNOCK_KNOCK_MOB_DAMAGE 12
/// Tiles a mob punched by Knock-Knock is thrown back
#define KNOCK_KNOCK_THROW_RANGE 4

// =============================================================================
// GREEN: Handloader's vise
// Table-mount reloading press: consumes spent casings + iron sheets, reviving the
// casings into live rounds one at a time via newshot() (see
// /obj/item/ammo_casing/proc/newshot, code/modules/projectiles/ammunition/_ammunition.dm).
// Fired casings keep their instance and projectile_type (fire_casing() only nulls
// loaded_projectile), so this works on any spent casing regardless of caliber.
//
// PLAYTEST FIX: the search used to look only at the table turf's own contents, so
// it reported "no spent casings" forever - ejected brass lands on the shooter's
// turf, not on the table, and the iron is in their bag. build_workspace() now
// gathers from the user's inventory, both turfs, and any ammo box or bag sitting
// on them, which is where the casings actually are.
// =============================================================================

/obj/item/handloaders_vise
	name = "handloader's vise"
	desc = "A pocket reloading press, armory-issue. Clamp it to a table and it packs spent casings with iron until they're live rounds again."
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

/obj/item/handloaders_vise/examine(mob/user)
	. = ..()
	. += span_notice("Stand next to a table and use it in hand. It takes spent casings and iron sheets from your hands, your bag, the floor you're standing on, or the table itself.")
	. += span_notice("One round every 8 seconds. Stepping away from the table stops it.")

/obj/item/handloaders_vise/attack_self(mob/living/user)
	. = ..()
	if(busy)
		balloon_alert(user, "already clamped down!")
		return
	var/turf/mount = find_mounting_table(user)
	if(!mount)
		balloon_alert(user, "needs a table!")
		return

	busy = TRUE
	var/reloaded = 0
	while(TRUE)
		var/list/workspace = build_workspace(user, mount)
		var/obj/item/ammo_casing/spent_case = find_spent_casing(workspace)
		var/obj/item/stack/sheet/iron/scrap = find_iron(workspace)
		if(!spent_case)
			if(!reloaded)
				balloon_alert(user, "no spent casings!")
			break
		if(!scrap)
			if(!reloaded)
				balloon_alert(user, "no iron!")
			break
		if(!reloaded)
			balloon_alert(user, "clamping vise...")
		if(!do_after(user, HANDLOADERS_VISE_RELOAD_DELAY, target = user, extra_checks = CALLBACK(src, PROC_REF(still_mounted), user, mount)))
			break
		if(QDELETED(spent_case) || spent_case.loaded_projectile || QDELETED(scrap) || scrap.get_amount() < 1)
			continue
		scrap.use(1)
		spent_case.newshot()
		spent_case.update_appearance()
		// A round revived inside a magazine or box has to repaint the container's ammo counter
		if(istype(spent_case.loc, /obj/item/ammo_box))
			var/obj/item/ammo_box/holder = spent_case.loc
			holder.update_appearance()
		reloaded++
		balloon_alert(user, "reloaded a round")
	busy = FALSE
	if(reloaded)
		to_chat(user, span_notice("You unclamp [src]. [reloaded] round\s reloaded."))

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

/**
 * Everything the vise is allowed to pull casings and iron out of: the user's own
 * inventory (recursively, so bags and magazines count), the turf they're standing
 * on, the table turf, and one level down into any ammo box or bag lying on either.
 * Deliberately does not recurse into other mobs standing on those turfs.
 */
/obj/item/handloaders_vise/proc/build_workspace(mob/living/user, turf/mount)
	var/list/workspace = list()
	workspace += user.get_all_contents()
	var/list/turfs = list()
	var/turf/user_turf = get_turf(user)
	if(user_turf)
		turfs |= user_turf
	if(mount)
		turfs |= mount
	for(var/turf/checked as anything in turfs)
		for(var/obj/item/thing in checked)
			workspace += thing
			if(istype(thing, /obj/item/ammo_box) || istype(thing, /obj/item/storage))
				workspace += thing.contents
	return workspace

/// Finds a spent (unloaded) casing anywhere in the workspace.
/obj/item/handloaders_vise/proc/find_spent_casing(list/workspace)
	for(var/obj/item/ammo_casing/casing in workspace)
		if(!casing.loaded_projectile && casing.projectile_type)
			return casing
	return null

/// Finds an iron stack anywhere in the workspace with at least one sheet left.
/obj/item/handloaders_vise/proc/find_iron(list/workspace)
	for(var/obj/item/stack/sheet/iron/scrap in workspace)
		if(scrap.get_amount() >= 1)
			return scrap
	return null

// =============================================================================
// GREEN: Sergeant's whistle
// Subtypes the existing police whistle (/obj/item/clothing/mask/whistle,
// code/modules/clothing/masks/hailer.dm) for its sprite and worn-mask action-button
// wiring. Blast halves the remaining duration of hearers' active stun/knockdown
// (/datum/status_effect/incapacitating/stun and /knockdown, via the base
// /datum/status_effect/proc/remove_duration helper) and grants a short speed buff.
// Audible to anyone in view, hostiles included - that's the drawback.
//
// PLAYTEST FIX: the blast used to hang off ui_action_click and a plain
// /datum/action/item_action, which gives the button no cooldown feedback at all.
// It is now a /datum/action/cooldown, which reddens the button and prints the
// remaining seconds on it (see update_button_status in
// code/datums/actions/cooldown_action.dm). The item overlay component is the same
// one /datum/action/item_action uses, so the button still shows the whistle.
// =============================================================================

/datum/action/cooldown/sergeants_whistle
	name = "Blow whistle"
	desc = "Shakes everyone in earshot out of a stun and gets them moving, enemies included. 60 second cooldown."
	check_flags = AB_CHECK_INCAPACITATED|AB_CHECK_HANDS_BLOCKED|AB_CHECK_CONSCIOUS
	button_icon_state = null
	cooldown_time = SERGEANTS_WHISTLE_COOLDOWN

/datum/action/cooldown/sergeants_whistle/New(Target, original = TRUE)
	. = ..()
	if(isatom(Target))
		AddComponent(/datum/component/action_item_overlay, Target)

/datum/action/cooldown/sergeants_whistle/IsAvailable(feedback = FALSE)
	. = ..()
	if(. || !feedback || isnull(owner))
		return .
	if(next_use_time > world.time)
		owner.balloon_alert(owner, "[DisplayTimeText(next_use_time - world.time)] left")

/datum/action/cooldown/sergeants_whistle/Activate(atom/activation_target)
	var/obj/item/clothing/mask/whistle/sergeants/whistle = target
	if(!istype(whistle) || isnull(owner))
		return FALSE
	whistle.blow_whistle(owner)
	StartCooldown()
	return TRUE

/obj/item/clothing/mask/whistle/sergeants
	name = "sergeant's whistle"
	desc = "A brass pea whistle on a bootlace. One blast shakes everyone in earshot out of a stun and gets them moving, enemies included. 60 second cooldown."
	actions_types = list(/datum/action/cooldown/sergeants_whistle)

/obj/item/clothing/mask/whistle/sergeants/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/// Sounds the blast and rallies everyone who can hear it. The action button owns the cooldown.
/obj/item/clothing/mask/whistle/sergeants/proc/blow_whistle(mob/living/user)
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
// YELLOW: Phalanx buckler
// Subtypes the riot shield (/obj/item/shield/riot, code/game/objects/items/shields.dm)
// for its sprite, armor, and baseline block_chance/hit_reaction. Raising it adds a
// heavy movespeed penalty and registers COMSIG_PROJECTILE_PREHIT on the wielder and
// on whoever's standing directly behind them (opposite the wielder's facing),
// intercepting shots that originate from the direction the wielder is facing.
// Returning PROJECTILE_INTERRUPT_HIT from that signal consumes the projectile before
// on_hit/damage resolves (see process_hit_loop() in code/modules/projectiles/projectile.dm).
//
// PLAYTEST FIX: custom sprite. The item icon is bespoke; the two inhand states and
// the back-slot worn state are recolours of the vanilla riot shield masks, so the
// hand and back placement is pixel-identical to stock. All three files have to be
// pointed somewhere new together - /obj/item/shield sets lefthand_file/righthand_file
// and the back slot falls back to `worn_icon_state || icon_state` in the stock
// back.dmi, which would have come up empty once icon_state changed.
// =============================================================================

/obj/item/shield/riot/phalanx_buckler
	name = "Phalanx buckler"
	desc = "A tower shield cut down and re-plated by hand. Raised, it stops shots coming at you or at whoever's standing right behind you."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "phalanx_buckler"
	inhand_icon_state = "phalanx_buckler"
	lefthand_file = 'voidcrew/modules/loot/icons/uniques_lefthand.dmi'
	righthand_file = 'voidcrew/modules/loot/icons/uniques_righthand.dmi'
	worn_icon = 'voidcrew/modules/loot/icons/uniques_worn.dmi'
	worn_icon_state = "phalanx_buckler"
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
// YELLOW: Marksman's cant
// Subtypes plain sunglasses (/obj/item/clothing/glasses/sunglasses,
// code/modules/clothing/glasses/_glasses.dm) for its behaviour. Standing still for
// MARKSMANS_CANT_STILLNESS "settles" the cant; the next shot fired zeroes bonus
// spread (COMSIG_MOB_FIRED_GUN's bonus_spread_values list - see
// code/modules/deathmatch/deathmatch_modifier.dm's ocelot/stormtrooper modifiers for
// the reference pattern) and zeroes that specific projectile's accuracy_falloff
// (COMSIG_PROJECTILE_FIRER_BEFORE_FIRE), then knocks the target down on impact
// (COMSIG_PROJECTILE_SELF_ON_HIT). One settle, one shot - moving breaks it.
//
// PLAYTEST FIX: a settled shot now puts the cant on a 30 second cooldown, so it is
// one trued-up shot every half minute rather than one every two seconds of standing
// still. become_settled() reschedules itself for exactly the remaining cooldown
// instead of retrying every two seconds, which keeps the balloon alerts quiet.
// Custom sprite too: the item icon is bespoke and the worn state is a recolour of
// the vanilla sunglasses eye mask, so it sits on the face correctly. worn_icon_state
// has to be set explicitly - build_worn_icon() resolves the worn state as
// `worn_icon_state || icon_state` and would otherwise look for "marksmans_cant" in
// the stock eyes.dmi. The inhand states are left on the stock sunglasses ones.
// =============================================================================

/obj/item/clothing/glasses/sunglasses/marksmans_cant
	name = "marksman's cant"
	desc = "Shooting glasses with a spirit level set into the top rim. Stand still a couple of seconds and your next shot goes exactly where you point it. 30 second cooldown between shots."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "marksmans_cant"
	worn_icon = 'voidcrew/modules/loot/icons/uniques_worn.dmi'
	worn_icon_state = "marksmans_cant"
	/// Whether the cant has settled and is ready to true up the next shot
	var/settled = FALSE
	/// The mob currently wearing the cant, tracked for signal cleanup
	var/mob/living/wearer
	/// Time before the cant can settle another shot
	COOLDOWN_DECLARE(settle_cooldown)
	/// Anti-spam gate on the "still resetting" alert, so autofire doesn't bury the screen
	COOLDOWN_DECLARE(warn_cooldown)

/obj/item/clothing/glasses/sunglasses/marksmans_cant/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/glasses/sunglasses/marksmans_cant/examine(mob/user)
	. = ..()
	. += span_notice("Stand still for 2 seconds to settle the cant. The next shot you fire goes exactly where you point it and knocks the target down.")
	if(!COOLDOWN_FINISHED(src, settle_cooldown))
		. += span_warning("The level is still resetting: [DisplayTimeText(COOLDOWN_TIMELEFT(src, settle_cooldown))] left.")
	else
		. += span_notice("30 second cooldown after each settled shot.")

/obj/item/clothing/glasses/sunglasses/marksmans_cant/equipped(mob/user, slot, initial = FALSE)
	. = ..()
	if(!(slot & ITEM_SLOT_EYES))
		return
	wearer = user
	settled = FALSE
	// override on all three: equipping straight out of another slot fires equipped()
	// again without a matching dropped(), and a duplicate registration is a runtime
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(on_wearer_moved), override = TRUE)
	RegisterSignal(user, COMSIG_MOB_FIRED_GUN, PROC_REF(on_fired_gun), override = TRUE)
	RegisterSignal(user, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE, PROC_REF(on_projectile_before_fire), override = TRUE)
	reset_stillness_timer()

/obj/item/clothing/glasses/sunglasses/marksmans_cant/dropped(mob/user)
	if(wearer)
		UnregisterSignal(wearer, list(COMSIG_MOVABLE_MOVED, COMSIG_MOB_FIRED_GUN, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE))
	settled = FALSE
	wearer = null
	return ..()

/// (Re)schedules the settle timer, keyed uniquely per glasses instance so movement just pushes it back.
/// Never fires before the cooldown from the last settled shot is up.
/obj/item/clothing/glasses/sunglasses/marksmans_cant/proc/reset_stillness_timer()
	var/delay = max(MARKSMANS_CANT_STILLNESS, COOLDOWN_TIMELEFT(src, settle_cooldown))
	addtimer(CALLBACK(src, PROC_REF(become_settled)), delay, TIMER_UNIQUE | TIMER_OVERRIDE)

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
	if(!COOLDOWN_FINISHED(src, settle_cooldown))
		// Come back exactly when the cooldown ends rather than retrying every two seconds
		addtimer(CALLBACK(src, PROC_REF(become_settled)), COOLDOWN_TIMELEFT(src, settle_cooldown) + 1, TIMER_UNIQUE | TIMER_OVERRIDE)
		return
	settled = TRUE
	balloon_alert(wearer, "settled")

/// Signal handler for COMSIG_MOB_FIRED_GUN: zeroes bonus spread on the settled shot.
/obj/item/clothing/glasses/sunglasses/marksmans_cant/proc/on_fired_gun(mob/living/user, obj/item/gun/gun_fired, atom/target, params, zone_override, list/bonus_spread_values)
	SIGNAL_HANDLER
	if(!settled)
		if(!COOLDOWN_FINISHED(src, settle_cooldown) && COOLDOWN_FINISHED(src, warn_cooldown))
			COOLDOWN_START(src, warn_cooldown, MARKSMANS_CANT_WARN_GAP)
			balloon_alert(user, "cant resets in [DisplayTimeText(COOLDOWN_TIMELEFT(src, settle_cooldown))]")
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
	COOLDOWN_START(src, settle_cooldown, MARKSMANS_CANT_COOLDOWN)
	balloon_alert(user, "cant spent")
	// Queue the next settle now, without this, a shooter who stays perfectly still
	// after firing would never settle again until they moved. reset_stillness_timer()
	// won't let it land before the 30 second cooldown is up.
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
// RED: The garrison standard
// Fresh item, sprite copied verbatim from the Nanotrasen banner
// (/obj/item/station_charter/banner, code/game/objects/items/charter.dm) rather than
// subtyped, since the banner's station-renaming mechanic has nothing to do with this
// item. Wrenching it to the floor spawns a destructible anchored structure
// (/obj/structure/destructible, code/game/objects/structures/destructible_structures.dm)
// whose process() grants nearby friendlies a damage-taken multiplier via
// /datum/physiology (see modules/antagonists/voidwalker/voidwalker_traumas.dm and the
// dna_infuser organ sets for precedent) and periodically shaves down their active
// stun/knockdown, same remove_duration() trick as the sergeant's whistle.
//
// PLAYTEST FIX: the aura used to hit every human in view, boarders included. It is
// now scoped to the planter's own crew. Ship crew membership in this codebase is
// /datum/team/voidcrew, tracked both on the ship (ship.ship_team) and on every
// member's mind (mind.ship_teams, voidcrew/modules/teams/_team.dm). Planting snaps
// a weakref to each of the planter's teams, and a mob qualifies if any of those
// teams is still in their own mind.ship_teams - the same test the player outposts
// and trader outposts use. Weakrefs because a disbanded team is qdel'd out from
// under us. And everyone the banner is buffing now pulses with the same
// /obj/effect/temp_visual/heal the lightgeist's healing touch uses.
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

/obj/item/garrison_standard/examine(mob/user)
	. = ..()
	. += span_notice("Planted, it protects your own crew only. Anyone else standing near it gets nothing.")

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
	var/obj/structure/destructible/garrison_standard/planted = new(plant_turf)
	planted.bind_to_crew(user)
	qdel(src)
	return TRUE

/// The planted, defensible form of the garrison standard. Cuttable down by anyone who reaches it (standard structure damage).
/obj/structure/destructible/garrison_standard
	name = "the garrison standard"
	desc = "A unit banner, planted. The crew it was planted for takes less damage nearby and shrugs off stuns faster."
	icon = 'icons/obj/banner.dmi'
	icon_state = "banner"
	anchored = TRUE
	density = FALSE
	max_integrity = 60
	break_message = span_warning("The garrison standard is cut down!")
	break_sound = 'sound/effects/meteorimpact.ogg'
	/// Weakrefs to the /datum/team/voidcrew the planter belonged to. Only their members get the aura.
	var/list/owner_team_refs
	/// Weakref to whoever planted it, used as the fallback when they had no crew at all
	var/datum/weakref/planter_ref
	/// Name of the crew this was planted for, for examine text
	var/owner_name

/obj/structure/destructible/garrison_standard/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/structure/destructible/garrison_standard/Destroy()
	STOP_PROCESSING(SSobj, src)
	owner_team_refs = null
	planter_ref = null
	return ..()

/// Records whose crew this banner flies for. Called the moment it is planted.
/obj/structure/destructible/garrison_standard/proc/bind_to_crew(mob/living/planter)
	if(QDELETED(planter))
		return
	planter_ref = WEAKREF(planter)
	owner_team_refs = list()
	for(var/datum/team/voidcrew/crew_team as anything in planter.mind?.ship_teams)
		owner_team_refs += WEAKREF(crew_team)
		if(!owner_name)
			owner_name = crew_team.name

/obj/structure/destructible/garrison_standard/examine(mob/user)
	. = ..()
	if(owner_name)
		. += span_notice("These are [owner_name]'s colors.")
	else
		. += span_notice("No ship's colors on it - it only covers whoever planted it.")
	. += span_notice("Crew it covers take 15% less brute and burn damage within 7 tiles, and shake off stuns and knockdowns faster.")

/**
 * Whether this mob flies the banner's colors. A mob qualifies if any of the teams
 * recorded at planting is still listed on their own mind - which means latejoiners
 * added to that crew afterwards are covered automatically, while boarders from
 * another ship, mindless mobs and NPCs never are. If the planter had no crew at
 * all (admin spawn, solo claim with no team yet) the banner only covers them.
 */
/obj/structure/destructible/garrison_standard/proc/flies_our_colors(mob/living/friendly)
	if(!length(owner_team_refs))
		var/mob/living/planter = planter_ref?.resolve()
		return !isnull(planter) && friendly == planter
	if(isnull(friendly.mind))
		return FALSE
	for(var/datum/weakref/team_ref as anything in owner_team_refs)
		var/datum/team/voidcrew/crew_team = team_ref.resolve()
		if(crew_team && LAZYFIND(friendly.mind.ship_teams, crew_team))
			return TRUE
	return FALSE

/obj/structure/destructible/garrison_standard/process(seconds_per_tick)
	for(var/mob/living/carbon/human/friendly in view(GARRISON_STANDARD_AURA_RANGE, src))
		if(friendly.stat == DEAD)
			continue
		if(!flies_our_colors(friendly))
			continue
		friendly.apply_status_effect(/datum/status_effect/garrison_standard_aura)
		var/datum/status_effect/incapacitating/stun/stun_effect = friendly.IsStun()
		if(stun_effect)
			stun_effect.remove_duration(2 SECONDS * seconds_per_tick)
		var/datum/status_effect/incapacitating/knockdown/knockdown_effect = friendly.IsKnockdown()
		if(knockdown_effect)
			knockdown_effect.remove_duration(2 SECONDS * seconds_per_tick)

/// Damage-taken reduction granted to crew standing near a planted garrison standard. Refreshes while in range, expires shortly after leaving.
/datum/status_effect/garrison_standard_aura
	id = "garrison_standard_aura"
	duration = 3 SECONDS
	tick_interval = 1.5 SECONDS
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
	show_pulse()
	return TRUE

/datum/status_effect/garrison_standard_aura/tick(seconds_between_ticks)
	show_pulse()

/datum/status_effect/garrison_standard_aura/on_remove()
	if(!ishuman(owner))
		return
	var/mob/living/carbon/human/human_owner = owner
	if(!human_owner.physiology)
		return
	human_owner.physiology.brute_mod /= GARRISON_STANDARD_DAMAGE_MULT
	human_owner.physiology.burn_mod /= GARRISON_STANDARD_DAMAGE_MULT

/// The visible tell that someone is under the banner - same effect the lightgeist leaves on things it heals.
/datum/status_effect/garrison_standard_aura/proc/show_pulse()
	var/turf/owner_turf = get_turf(owner)
	if(owner_turf)
		new /obj/effect/temp_visual/heal(owner_turf, GARRISON_STANDARD_AURA_COLOR)

// =============================================================================
// RED: "Knock-Knock"
// Fresh gloves, sprite copied verbatim from boxing gloves
// (/obj/item/clothing/gloves/boxing and /boxing/evil, code/modules/clothing/gloves/boxing.dm)
// rather than subtyped, to avoid dragging in boxing's martial-art-giver component,
// which would otherwise fight with this item's own COMSIG_LIVING_UNARMED_ATTACK hook.
// Two punches devastate a wall turf (dismantle_wall(devastated = TRUE), same call
// /datum/element/wall_smasher uses in code/datums/elements/wall_smasher.dm) and one
// heavy punch nearly finishes a door's atom_integrity; mobs take a moderate hit
// and get thrown back, powerfist-style (code/game/objects/items/powerfist.dm). Every
// empowered punch drains the internal cell; it recharges passively over time.
//
// PLAYTEST FIXES, three of them:
//  * Door remains. A wrecked airlock leaves an /obj/structure/door_assembly behind
//    (on_deconstruction in code/game/machinery/doors/airlock.dm), which is dense and
//    still plugs the hole. The gauntlet couldn't touch it. punch_barrier() now covers
//    door assemblies and girders as well, and the door branch was widened from
//    /obj/machinery/door/airlock to /obj/machinery/door so firelocks and blast doors
//    count too.
//  * Charges never ran out on mobs. The charge WAS being deducted, but the cell
//    recharged flat out at one charge every two seconds with no interruption, and
//    every punch throws the target four tiles away - the walk back refilled the
//    gauntlet faster than punching drained it. Charge spending now goes through a
//    single use_charge(), which also stops recharging for five seconds, so five
//    punches in a row genuinely empty it.
//  * Max charge dropped from 8 to 5.
// =============================================================================

/obj/item/clothing/gloves/knock_knock
	name = "\"Knock-Knock\""
	desc = "A powered breaching gauntlet with AFTER YOU stamped across the knuckle plate. Punches straight through walls, doors and door frames. Holds 5 charges."
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
	/// Dead time after the last punch before the cell starts refilling
	COOLDOWN_DECLARE(recharge_delay)

/obj/item/clothing/gloves/knock_knock/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)
	START_PROCESSING(SSobj, src)

/obj/item/clothing/gloves/knock_knock/Destroy()
	STOP_PROCESSING(SSobj, src)
	wall_hits = null
	return ..()

/obj/item/clothing/gloves/knock_knock/examine(mob/user)
	. = ..()
	. += span_notice("The charge gauge reads [round(charge)] of [KNOCK_KNOCK_MAX_CHARGE]. Every punch that lands costs one.")
	if(!COOLDOWN_FINISHED(src, recharge_delay))
		. += span_warning("The cell won't start refilling for another [DisplayTimeText(COOLDOWN_TIMELEFT(src, recharge_delay))].")
	else if(charge < KNOCK_KNOCK_MAX_CHARGE)
		. += span_notice("It's refilling at one charge every 4 seconds.")

/obj/item/clothing/gloves/knock_knock/process(seconds_per_tick)
	if(charge >= KNOCK_KNOCK_MAX_CHARGE)
		return
	if(!COOLDOWN_FINISHED(src, recharge_delay))
		return
	charge = min(KNOCK_KNOCK_MAX_CHARGE, charge + (KNOCK_KNOCK_RECHARGE_RATE * seconds_per_tick))

/obj/item/clothing/gloves/knock_knock/equipped(mob/user, slot, initial = FALSE)
	. = ..()
	if(!(slot & ITEM_SLOT_GLOVES))
		return
	RegisterSignal(user, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_unarmed_attack), override = TRUE)

/obj/item/clothing/gloves/knock_knock/dropped(mob/user)
	if(user)
		UnregisterSignal(user, COMSIG_LIVING_UNARMED_ATTACK)
	return ..()

/// Signal handler for COMSIG_LIVING_UNARMED_ATTACK: breaches walls, doors and door frames, or hits and throws back mobs.
/obj/item/clothing/gloves/knock_knock/proc/on_unarmed_attack(mob/living/puncher, atom/target, proximity_flag, list/modifiers)
	SIGNAL_HANDLER
	// Combat mode only: this signal fires on every empty-hand click, and the
	// gauntlet must not breach the airlock you're just trying to open (or
	// launch someone you're helping up)
	if(!proximity_flag || !puncher.combat_mode)
		return NONE

	var/is_wall = iswallturf(target) && !isindestructiblewall(target)
	var/is_barrier = istype(target, /obj/machinery/door) || istype(target, /obj/structure/door_assembly) || istype(target, /obj/structure/girder)
	var/is_mob = isliving(target) && target != puncher
	if(!is_wall && !is_barrier && !is_mob)
		return NONE
	if(is_mob && HAS_TRAIT(puncher, TRAIT_PACIFISM))
		return NONE
	if(charge < KNOCK_KNOCK_CHARGE_PER_PUNCH)
		balloon_alert(puncher, "gauntlet drained!")
		return NONE

	if(is_wall)
		punch_wall(puncher, target)
	else if(is_barrier)
		punch_barrier(puncher, target)
	else
		punch_mob(puncher, target)
	return COMPONENT_CANCEL_ATTACK_CHAIN

/**
 * Spends one charge and stalls the recharge. Every charged hit routes through here,
 * so no branch can quietly skip the cost.
 */
/obj/item/clothing/gloves/knock_knock/proc/use_charge(mob/living/puncher)
	charge -= KNOCK_KNOCK_CHARGE_PER_PUNCH
	COOLDOWN_START(src, recharge_delay, KNOCK_KNOCK_RECHARGE_DELAY)
	puncher.changeNext_move(CLICK_CD_MELEE)
	if(charge < KNOCK_KNOCK_CHARGE_PER_PUNCH)
		balloon_alert(puncher, "last charge spent")

/// Two empowered punches devastate a wall.
/obj/item/clothing/gloves/knock_knock/proc/punch_wall(mob/living/puncher, turf/closed/wall/wall_turf)
	use_charge(puncher)
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

/// A heavy punch that all but finishes a door, a door frame left behind by one, or a girder.
/obj/item/clothing/gloves/knock_knock/proc/punch_barrier(mob/living/puncher, obj/barrier)
	use_charge(puncher)
	puncher.do_attack_animation(barrier)
	playsound(barrier, 'sound/effects/meteorimpact.ogg', 75, TRUE)
	barrier.take_damage(KNOCK_KNOCK_BREACH_DAMAGE, BRUTE, MELEE, TRUE, get_dir(puncher, barrier))

/// A moderate hit that throws the target back.
/obj/item/clothing/gloves/knock_knock/proc/punch_mob(mob/living/puncher, mob/living/hit_mob)
	use_charge(puncher)
	puncher.do_attack_animation(hit_mob)
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
#undef MARKSMANS_CANT_COOLDOWN
#undef MARKSMANS_CANT_WARN_GAP
#undef MARKSMANS_CANT_STAGGER
#undef GARRISON_STANDARD_AURA_RANGE
#undef GARRISON_STANDARD_DAMAGE_MULT
#undef GARRISON_STANDARD_AURA_COLOR
#undef KNOCK_KNOCK_MAX_CHARGE
#undef KNOCK_KNOCK_CHARGE_PER_PUNCH
#undef KNOCK_KNOCK_RECHARGE_RATE
#undef KNOCK_KNOCK_RECHARGE_DELAY
#undef KNOCK_KNOCK_BREACH_DAMAGE
#undef KNOCK_KNOCK_MOB_DAMAGE
#undef KNOCK_KNOCK_THROW_RANGE

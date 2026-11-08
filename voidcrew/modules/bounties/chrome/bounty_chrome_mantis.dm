/**
 * # Bounty chrome: Mantis Blades
 *
 * The player's Mantis Blades (voidcrew/modules/cyberware/ware_military_arms.dm) on a bounty fighter
 * who fights up close: a brawler, a knife or a club, or one of their companions.
 *
 * - The housings show on both forearms (organ_looks puts the real pair in the look dummy).
 * - When the fight starts the blades come out with the housing's own sound and a line, one in each
 *   hand, drawn with the blade's real in-hand sprites. While they are out the blade is their weapon:
 *   its real numbers (bounty_real_weapon()) and its verbs on every blow, and their style's own extras
 *   (a brawler's shove, a bat's knock-back) stay out of it (owns_blow()). When they leave the fight,
 *   go down, die or are hit by an EMP, the blades go back in and their own weapon comes back.
 * - They never carry a gun or a bottle: whatever put the housings in them (a roll, an admin's pick),
 *   a fighter whose style isn't one of the close-in ones becomes a knife fighter (bounty_chrome_fit_style()).
 * - The lunge: with someone two to five tiles off in a clear line, they plant their feet and drop
 *   low, and a line lights up on the floor from them through their target. A beat later they dash
 *   down the whole line, after-images behind them, and cut everyone standing on it: the player
 *   lunge's two blade cuts, a bleed, and a knockdown. Then they have to recover, rooted and unable to
 *   swing, and for longer if they hit nobody, or ran into a shield.
 *
 * Counterplay: step off the marked line (it never turns), keep out of five tiles, keep a table, a
 * railing or a door between you (the line stops at anything solid, and a door shut on it stops the
 * dash), carry a shield (it blocks the lunge outright and staggers them), and punish the recovery.
 * An EMP pulls the blades for the reboot and spoils a lunge in progress.
 */

/// Trait source for standing still through the wind-up, the dash and the recovery, and for the crouch
#define BOUNTY_MANTIS_TRAIT "bounty_chrome_mantis"
/// The blade: the player implant's own item, for its numbers and its in-hand sprites
#define BOUNTY_MANTIS_BLADE /obj/item/melee/energy/blade/hardlight/cyberware_mantis
/// Tiles the lunge covers, and the closest and farthest a target may be for one (the player lunge's range)
#define BOUNTY_MANTIS_LUNGE_RANGE 5
#define BOUNTY_MANTIS_LUNGE_MIN 2
/// The wind-up: the marked line shows this long before the dash
#define BOUNTY_MANTIS_LUNGE_WINDUP (0.7 SECONDS)
/// Between lunges, and before the first one once the blades are out
#define BOUNTY_MANTIS_LUNGE_COOLDOWN (12 SECONDS)
#define BOUNTY_MANTIS_FIRST_LUNGE (2.5 SECONDS)
/// Brute each blade lands on everyone the lunge cuts, and its wound bonus (the player lunge's CYBERWARE_MANTIS_LUNGE_BONUS, both blades out)
#define BOUNTY_MANTIS_LUNGE_DAMAGE 10
#define BOUNTY_MANTIS_LUNGE_WOUND 10
/// How long someone the lunge cuts stays down
#define BOUNTY_MANTIS_LUNGE_KNOCKDOWN (1.5 SECONDS)
/// The recovery after a lunge, rooted and unable to swing: after cutting someone, after cutting nobody, and after hitting a shield
#define BOUNTY_MANTIS_RECOVER_HIT (1.2 SECONDS)
#define BOUNTY_MANTIS_RECOVER_WHIFF (2 SECONDS)
#define BOUNTY_MANTIS_RECOVER_BLOCKED (2.5 SECONDS)
/// How often they look for a lunge while the blades are out
#define BOUNTY_MANTIS_WATCH (0.5 SECONDS)
/// The marked line in the hardlight blade's blue (#6cb8ff). The mark art is pure red, which a plain colour
/// only darkens, so a colour matrix turns its red into the blue.
#define BOUNTY_MANTIS_MARK_COLOR list(0.42, 0.72, 1, 0, 0, 0, 0, 0, 0)
/// How far the crouch drops them for the wind-up
#define BOUNTY_MANTIS_CROUCH -3

/// Where a lunge is: winding up, dashing, or recovering (null: none)
#define BOUNTY_MANTIS_WINDUP "windup"
#define BOUNTY_MANTIS_DASH "dash"
#define BOUNTY_MANTIS_RECOVER "recover"

/datum/bounty_chrome/mantis
	key = BOUNTY_CHROME_MANTIS
	name = "Mantis Blades"
	// About as common as any other piece among the fighters it suits
	weight = 10
	min_tier = BOUNTY_TIER_PETTY
	// Fighters who close in. Never the meek, who run, and never a mini-boss: the Juggernaut's charge and
	// the Ghost's dash already close the gap down a line, and a second one would blur the kit.
	archetypes = list(BOUNTY_ARCHETYPE_NORMAL, BOUNTY_CHROME_COMPANION)
	styles = list(BOUNTY_STYLE_BRAWLER, BOUNTY_STYLE_KNIFE, BOUNTY_STYLE_CLUB)
	// Gorilla Arms take the same arm slots. The Piledriver is a second leap onto whoever keeps their
	// distance, and with both, staying out of reach would stop being an answer.
	exclusive_with = list(BOUNTY_CHROME_GORILLA, BOUNTY_CHROME_PILEDRIVER)
	organ_looks = list(
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left,
	)
	/// The blades are out
	var/deployed = FALSE
	/// Their own weapon while the blades are out (a typepath, or null for bare fists), and their own blow's look
	var/saved_weapon
	var/saved_vis_effect
	/// The left blade, drawn in their vis_contents; the right one is their hand (bounty_ai_hold())
	var/obj/effect/abstract/bounty_held/left_blade
	/// The look for a lunge, while the blades are out
	var/watch_timer
	/// world.time the next lunge may start
	var/next_lunge_at = 0
	/// Where the lunge is: BOUNTY_MANTIS_WINDUP, _DASH, _RECOVER, or null
	var/lunge_state
	/// Goes up with every lunge and every cancel, so a stale timer does nothing
	var/lunge_serial = 0
	/// The marked tiles, in order, from the wind-up
	var/list/turf/lunge_path
	/// Weakrefs to the marks on the floor
	var/list/lunge_marks
	/// How far down the line the dash is
	var/lunge_step = 0
	/// REF() of everyone cut this lunge, so nobody is cut twice
	var/list/lunge_cut
	/// The lunge cut someone, or struck a mech
	var/lunge_hit = FALSE

/datum/bounty_chrome/mantis/Destroy(force)
	cancel_lunge()
	deltimer(watch_timer)
	watch_timer = null
	QDEL_NULL(left_blade)
	return ..()

/datum/bounty_chrome/mantis/attach(mob/living/basic/fighter)
	. = ..()
	// The blades are their weapon: never a gun or a bottle, however the housings got there
	bounty_chrome_fit_style(fighter, list(BOUNTY_STYLE_BRAWLER, BOUNTY_STYLE_KNIFE, BOUNTY_STYLE_CLUB), BOUNTY_STYLE_KNIFE)

/datum/bounty_chrome/mantis/detach()
	retract(quiet = TRUE)
	return ..()

/// With the blades out every blow is the blade's: a brawler's shove or a bat's knock-back has no place in it
/datum/bounty_chrome/mantis/owns_blow()
	return deployed

/datum/bounty_chrome/mantis/on_fight_start(atom/target)
	if(in_fight())
		deploy()

/datum/bounty_chrome/mantis/on_tick(seconds_per_tick, fighting)
	if(!in_fight())
		if(deployed)
			retract()
		return
	if(!deployed)
		deploy()
		return
	// Something put another weapon in their hand while the blades were out: the blades are still what they hit with
	var/datum/ai_controller/controller = owner.ai_controller
	if(!QDELETED(controller) && controller.blackboard[BB_BOUNTY_WEAPON] != BOUNTY_MANTIS_BLADE)
		saved_weapon = controller.blackboard[BB_BOUNTY_WEAPON]
		arm_blades(controller)
		bounty_ai_hold(owner, BOUNTY_MANTIS_BLADE)

/datum/bounty_chrome/mantis/on_downed()
	retract(quiet = TRUE)

/datum/bounty_chrome/mantis/on_death()
	retract(quiet = TRUE)

/datum/bounty_chrome/mantis/on_emp(severity)
	if(deployed)
		owner.visible_message(span_warning("[owner]'s blades flicker out."))
	retract(quiet = TRUE)

/datum/bounty_chrome/mantis/examine_line()
	if(deployed)
		return "Hardlight blades jut from %THEIR forearms."
	return "Chrome housings sheathe %THEIR forearms."

// ===== IN THE FIGHT =====

/**
 * Whether they are in a fight the blades stay out for: a criminal fighting (knocked down for a moment
 * still counts), or a companion in the fight. Never down, cuffed, given up, run off, hidden, passing as
 * a patron or dead. A mini-boss never: its kit fights for it.
 */
/datum/bounty_chrome/mantis/proc/in_fight()
	if(!owner || QDELETED(owner) || owner.stat != CONSCIOUS)
		return FALSE
	if(istype(owner, /mob/living/basic/bounty_criminal/boss))
		return FALSE
	if(istype(owner, /mob/living/basic/bounty_criminal))
		var/mob/living/basic/bounty_criminal/criminal = owner
		if(criminal.ai_mode != BOUNTY_AI_FIGHTING || criminal.hidden || criminal.blended)
			return FALSE
		return !criminal.is_downed() && !criminal.is_restrained() && !HAS_TRAIT(criminal, TRAIT_BOUNTY_SURRENDERED)
	if(istype(owner, /mob/living/basic/bounty_companion))
		var/mob/living/basic/bounty_companion/companion = owner
		return companion.ai_in_fight && !companion.ai_fled && !companion.ai_gave_up
	return FALSE

/// What they hold in their hand now, by whichever of the two types they are
/datum/bounty_chrome/mantis/proc/hand()
	if(istype(owner, /mob/living/basic/bounty_criminal))
		var/mob/living/basic/bounty_criminal/criminal = owner
		return criminal.ai_hand
	if(istype(owner, /mob/living/basic/bounty_companion))
		var/mob/living/basic/bounty_companion/companion = owner
		return companion.ai_hand
	return null

/// The blades come out: their weapon until they go back in, one in each hand
/datum/bounty_chrome/mantis/proc/deploy()
	var/datum/ai_controller/controller = owner?.ai_controller
	if(deployed || QDELETED(controller))
		return FALSE
	deployed = TRUE
	saved_weapon = controller.blackboard[BB_BOUNTY_WEAPON]
	saved_vis_effect = owner.attack_vis_effect
	arm_blades(controller)
	owner.attack_vis_effect = ATTACK_EFFECT_SLASH
	bounty_ai_hold(owner, BOUNTY_MANTIS_BLADE)
	show_left_blade()
	owner.visible_message(span_warning("Blades of hard light slide out of [owner]'s forearms!"))
	playsound(owner, 'sound/items/unsheath.ogg', 50, TRUE)
	next_lunge_at = max(next_lunge_at, world.time + BOUNTY_MANTIS_FIRST_LUNGE)
	deltimer(watch_timer)
	watch_timer = addtimer(CALLBACK(src, PROC_REF(watch)), BOUNTY_MANTIS_WATCH, TIMER_STOPPABLE | TIMER_DELETE_ME)
	return TRUE

/// The blade is what they hold and hit with: its real numbers, its verbs
/datum/bounty_chrome/mantis/proc/arm_blades(datum/ai_controller/controller)
	controller.set_blackboard_key(BB_BOUNTY_WEAPON, BOUNTY_MANTIS_BLADE)
	bounty_real_weapon(BOUNTY_MANTIS_BLADE).apply_melee(owner)

/**
 * The blades go back in, any lunge stops, and their own weapon comes back: in hand if they are still
 * fighting. Safe at any time, their controller gone or not. `quiet` puts them away with no line or
 * sound.
 */
/datum/bounty_chrome/mantis/proc/retract(quiet = FALSE)
	cancel_lunge()
	deltimer(watch_timer)
	watch_timer = null
	if(left_blade)
		owner?.vis_contents -= left_blade
		QDEL_NULL(left_blade)
	if(!deployed)
		return FALSE
	deployed = FALSE
	if(!owner)
		return TRUE
	owner.attack_vis_effect = saved_vis_effect
	var/datum/ai_controller/controller = owner.ai_controller
	if(!QDELETED(controller) && controller.blackboard[BB_BOUNTY_WEAPON] == BOUNTY_MANTIS_BLADE)
		if(saved_weapon)
			controller.set_blackboard_key(BB_BOUNTY_WEAPON, saved_weapon)
		else
			controller.clear_blackboard_key(BB_BOUNTY_WEAPON)
		var/datum/bounty_real_weapon/own_weapon = bounty_ai_real_weapon(owner) || bounty_real_weapon(saved_weapon)
		own_weapon.apply_melee(owner)
	var/obj/effect/abstract/bounty_held/held = hand()
	if(held?.held_type == BOUNTY_MANTIS_BLADE)
		bounty_ai_hold(owner, in_fight() ? saved_weapon : null)
	saved_weapon = null
	if(!quiet && owner.stat == CONSCIOUS)
		owner.visible_message(span_notice("[owner]'s blades slide back into [owner.p_their()] forearms."))
		playsound(owner, 'sound/items/sheath.ogg', 40, TRUE)
	return TRUE

/// The left blade, in the left hand: the player blade's own left in-hand sprite, turning with them
/datum/bounty_chrome/mantis/proc/show_left_blade()
	if(left_blade || !owner)
		return
	var/obj/item/blade = BOUNTY_MANTIS_BLADE
	left_blade = new(null)
	left_blade.appearance = mutable_appearance(initial(blade.lefthand_file), initial(blade.inhand_icon_state))
	left_blade.name = ""
	left_blade.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	left_blade.appearance_flags = KEEP_APART | RESET_COLOR | RESET_TRANSFORM | PIXEL_SCALE
	left_blade.vis_flags = VIS_INHERIT_PLANE | VIS_INHERIT_DIR
	left_blade.layer = ABOVE_MOB_LAYER
	left_blade.inhand = TRUE
	left_blade.held_type = BOUNTY_MANTIS_BLADE
	owner.vis_contents += left_blade

// ===== THE LUNGE =====

/**
 * While the blades are out, every BOUNTY_MANTIS_WATCH: a lunge when one is worth it, and the blades
 * away soon after they leave the fight (gave up, cuffed, backed off, ran), not at the next Life tick.
 */
/datum/bounty_chrome/mantis/proc/watch()
	watch_timer = null
	if(!deployed || !owner || QDELETED(owner))
		return
	if(!in_fight())
		retract()
		return
	if(online() && !lunge_state)
		var/atom/target = bounty_chrome_target(owner)
		if(can_lunge(target))
			start_lunge(target)
	watch_timer = addtimer(CALLBACK(src, PROC_REF(watch)), BOUNTY_MANTIS_WATCH, TIMER_STOPPABLE | TIMER_DELETE_ME)

/// Whether they can lunge at `target` now: blades out and ready, on their feet in the fight, and their target (a person or their mech) two to five tiles off in a clear line
/datum/bounty_chrome/mantis/proc/can_lunge(atom/target)
	if(!deployed || lunge_state || world.time < next_lunge_at || !online() || !able())
		return FALSE
	if(QDELETED(target) || !(isliving(target) || ismecha(target)) || !bounty_ai_may_hit(owner, target))
		return FALSE
	// The blades pass over someone already on the floor
	var/mob/living/person = target
	if(isliving(person) && person.body_position == LYING_DOWN)
		return FALSE
	var/turf/here = get_turf(owner)
	var/turf/there = get_turf(target)
	if(!here || !there || here.z != there.z)
		return FALSE
	var/distance = get_dist(here, there)
	if(distance < BOUNTY_MANTIS_LUNGE_MIN || distance > BOUNTY_MANTIS_LUNGE_RANGE)
		return FALSE
	// Someone standing where the dash may not go (aboard their ship, out in space) is out of its reach
	if(!tile_ok(there))
		return FALSE
	return can_see(owner, target, BOUNTY_MANTIS_LUNGE_RANGE) && bounty_boss_clear_line(here, there)

/// On their feet, free and in the fight, standing on a tile where nothing holds them, and nobody playing them
/datum/bounty_chrome/mantis/proc/able()
	if(!owner || QDELETED(owner) || !isturf(owner.loc) || owner.buckled || owner.pulledby || owner.throwing)
		return FALSE
	if(owner.client || owner.mind)
		return FALSE
	return in_fight() && bounty_chrome_fighting(owner)

/**
 * The line they will lunge down at `target`: from them through where `target` stands and on, up to
 * BOUNTY_MANTIS_LUNGE_RANGE tiles. It ends before anything solid, a hazard, the edge of their leash or
 * someone standing it won't cut, and on a mech it will strike.
 */
/datum/bounty_chrome/mantis/proc/lunge_path(atom/target)
	. = list()
	var/turf/origin = get_turf(owner)
	var/turf/aim = get_turf(target)
	if(!origin || !aim || origin == aim || origin.z != aim.z)
		return
	var/step_x = aim.x - origin.x
	var/step_y = aim.y - origin.y
	var/turf/from = origin
	var/turf/to_spot = aim
	// The same line again past the target, as many times as it takes to reach the full length
	while(length(.) < BOUNTY_MANTIS_LUNGE_RANGE)
		for(var/turf/spot as anything in get_line(from, to_spot))
			if(spot == from)
				continue
			if(!tile_ok(spot))
				return
			var/obj/vehicle/sealed/mecha/mech = locate() in spot
			if(mech)
				if(bounty_ai_may_hit(owner, mech))
					. += spot
				return
			if(spot.is_blocked_turf(exclude_mobs = TRUE) || standing_in_the_way(spot))
				return
			. += spot
			if(length(.) >= BOUNTY_MANTIS_LUNGE_RANGE)
				return
		from = to_spot
		to_spot = locate(clamp(from.x + step_x, 1, world.maxx), clamp(from.y + step_y, 1, world.maxy), origin.z)
		if(!to_spot || to_spot == from)
			return

/// Whether they may dash over `spot`: on their leash (their criminal's, for a companion), and no wall, space, drop, lava or chasm
/datum/bounty_chrome/mantis/proc/tile_ok(turf/spot)
	if(!spot || isclosedturf(spot) || isspaceturf(spot) || isopenspaceturf(spot) || isgroundlessturf(spot) || islava(spot) || ischasm(spot))
		return FALSE
	if(!spot.can_cross_safely(owner))
		return FALSE
	var/mob/living/basic/bounty_criminal/leash_holder = bounty_ai_side_of(owner)
	return !leash_holder || leash_holder.leash_ok(spot)

/// Someone standing on `spot` the lunge won't cut, and stops short of: their own gang, anyone but a hunter they may hit
/datum/bounty_chrome/mantis/proc/standing_in_the_way(turf/spot)
	for(var/mob/living/person in spot)
		if(person == owner || !person.density)
			continue
		if(!may_cut(person))
			return person
	return null

/// Whether the lunge cuts `person`: a hunter on their feet whom they may hit
/datum/bounty_chrome/mantis/proc/may_cut(mob/living/person)
	if(person.stat != CONSCIOUS || person.body_position == LYING_DOWN)
		return FALSE
	return bounty_ai_is_hunter(person) && bounty_ai_may_hit(owner, person)

/**
 * The wind-up: feet planted and low, blades flat along the arms, and the line marked on the floor.
 * The dash follows BOUNTY_MANTIS_LUNGE_WINDUP later. Returns TRUE if it started.
 */
/datum/bounty_chrome/mantis/proc/start_lunge(atom/target)
	var/list/path = lunge_path(target)
	// Only a line that reaches them: one cut short by a friend standing in the way is no lunge
	if(!(get_turf(target) in path))
		return FALSE
	lunge_serial++
	lunge_state = BOUNTY_MANTIS_WINDUP
	lunge_path = path
	next_lunge_at = world.time + BOUNTY_MANTIS_LUNGE_COOLDOWN
	owner.ai_controller?.CancelActions()
	ADD_TRAIT(owner, TRAIT_IMMOBILIZED, BOUNTY_MANTIS_TRAIT)
	// No swing through the wind-up and the dash (a decisecond a tile); end_dash() sets the recovery's
	owner.changeNext_move(BOUNTY_MANTIS_LUNGE_WINDUP + BOUNTY_MANTIS_LUNGE_RANGE + 1)
	owner.face_atom(target)
	owner.add_offsets(BOUNTY_MANTIS_TRAIT, y_add = BOUNTY_MANTIS_CROUCH)
	owner.visible_message(span_boldwarning("[owner] drops low, blades laid flat along [owner.p_their()] arms!"))
	playsound(owner, 'sound/items/weapons/sear.ogg', 50, TRUE)
	lunge_marks = list()
	for(var/turf/spot as anything in path)
		lunge_marks += WEAKREF(new /obj/effect/temp_visual/bounty_boss_mark(spot, BOUNTY_MANTIS_LUNGE_WINDUP + 1, BOUNTY_MANTIS_MARK_COLOR))
	addtimer(CALLBACK(src, PROC_REF(begin_dash), lunge_serial), BOUNTY_MANTIS_LUNGE_WINDUP, TIMER_DELETE_ME)
	return TRUE

/// The wind-up is over: down the marked line, unless they were stopped meanwhile
/datum/bounty_chrome/mantis/proc/begin_dash(serial)
	if(serial != lunge_serial || lunge_state != BOUNTY_MANTIS_WINDUP)
		return FALSE
	clear_marks()
	owner.remove_offsets(BOUNTY_MANTIS_TRAIT)
	if(!online() || !able())
		cancel_lunge()
		return FALSE
	lunge_state = BOUNTY_MANTIS_DASH
	lunge_step = 0
	lunge_hit = FALSE
	lunge_cut = list()
	owner.set_glide_size(DELAY_TO_GLIDE_SIZE(1))
	playsound(owner, 'sound/items/weapons/bladeslice.ogg', 60, TRUE)
	dash_step(serial)
	return TRUE

/// One tile of the dash: cut whoever stands there, then step onto it
/datum/bounty_chrome/mantis/proc/dash_step(serial)
	if(serial != lunge_serial || lunge_state != BOUNTY_MANTIS_DASH)
		return
	if(!online() || !able())
		cancel_lunge()
		return
	lunge_step++
	if(lunge_step > length(lunge_path))
		end_dash(serial)
		return
	var/turf/next = lunge_path[lunge_step]
	if(!tile_ok(next))
		end_dash(serial)
		return
	for(var/mob/living/person in next)
		if(person == owner || lunge_cut[REF(person)] || !may_cut(person))
			continue
		if(!cut(person))
			end_dash(serial, person, blocked = TRUE)
			return
	for(var/obj/vehicle/sealed/mecha/mech in next)
		if(bounty_ai_may_hit(owner, mech))
			strike(mech)
		end_dash(serial, mech)
		return
	var/mob/living/in_the_way = standing_in_the_way(next)
	if(in_the_way)
		end_dash(serial, in_the_way)
		return
	var/turf/was = get_turf(owner)
	// Shoved or blown off the line between steps: Move() would jump them back onto it
	if(get_dist(was, next) != 1)
		end_dash(serial)
		return
	if(!owner.Move(next, get_dir(was, next)) || get_turf(owner) != next)
		end_dash(serial, blocker_on(next, was))
		return
	new /obj/effect/temp_visual/decoy/fading/halfsecond(was, owner)
	addtimer(CALLBACK(src, PROC_REF(dash_step), serial), 1, TIMER_DELETE_ME)

/// What stopped a step from `was` onto `next`: the wall, or something solid on either tile
/datum/bounty_chrome/mantis/proc/blocker_on(turf/next, turf/was)
	if(next.density)
		return next
	for(var/atom/movable/thing in next)
		if(thing.density && thing != owner)
			return thing
	for(var/atom/movable/thing in was)
		if(thing.density && thing != owner && (thing.flags_1 & ON_BORDER_1))
			return thing
	return null

/**
 * The lunge reaches `person`: both blades, a bleed, and the floor. A shield blocks it outright, and
 * then nothing lands. Returns FALSE if it was blocked.
 */
/datum/bounty_chrome/mantis/proc/cut(mob/living/person)
	lunge_cut[REF(person)] = TRUE
	var/obj/item/blade = BOUNTY_MANTIS_BLADE
	var/armour_penetration = initial(blade.armour_penetration)
	owner.face_atom(person)
	owner.do_attack_animation(person, ATTACK_EFFECT_SLASH)
	if(person.check_block(owner, npc_zone_damage(BOUNTY_MANTIS_LUNGE_DAMAGE * 2, owner), "[owner]'s lunge", LEAP_ATTACK, armour_penetration) == SUCCESSFUL_BLOCK)
		return FALSE
	lunge_hit = TRUE
	// One armour roll for both blades: they land together on the same spot (the player lunge's rule)
	var/armour = person.run_armor_check(BODY_ZONE_CHEST, MELEE, armour_penetration = armour_penetration, silent = TRUE)
	for(var/i in 1 to 2)
		person.apply_damage(npc_zone_damage(BOUNTY_MANTIS_LUNGE_DAMAGE, owner), BRUTE, BODY_ZONE_CHEST, armour, wound_bonus = BOUNTY_MANTIS_LUNGE_WOUND, sharpness = SHARP_EDGED)
	person.Knockdown(BOUNTY_MANTIS_LUNGE_KNOCKDOWN)
	person.apply_status_effect(/datum/status_effect/bounty_boss_bleed, owner.get_npc_zone_damage_factor())
	person.visible_message(
		span_danger("[owner] flickers across the gap and cuts [person] down!"),
		span_userdanger("[owner] flickers across the gap. The blades are already in you, and the floor comes up fast!"),
	)
	playsound(person, 'sound/items/weapons/bladeslice.ogg', 70, TRUE)
	log_combat(owner, person, "mantis-lunged", "mantis blades")
	return TRUE

/// The lunge ends on a mech with a hunter in it: both blades across its hull
/datum/bounty_chrome/mantis/proc/strike(obj/vehicle/sealed/mecha/mech)
	var/obj/item/blade = BOUNTY_MANTIS_BLADE
	lunge_hit = TRUE
	owner.face_atom(mech)
	owner.do_attack_animation(mech, ATTACK_EFFECT_SLASH)
	mech.take_damage(npc_zone_damage(BOUNTY_MANTIS_LUNGE_DAMAGE * 2, owner), BRUTE, MELEE, TRUE, get_dir(mech, owner), initial(blade.armour_penetration))
	mech.visible_message(span_danger("[owner] rakes both blades across [mech]!"))
	playsound(mech, 'sound/items/weapons/bladeslice.ogg', 70, TRUE)

/**
 * The dash is over, at the end of the line or stopped by `blocker`: they recover, rooted and unable to
 * swing, the longer if they cut nobody, and longest if a shield stopped them (`blocked`).
 */
/datum/bounty_chrome/mantis/proc/end_dash(serial, atom/blocker, blocked = FALSE)
	if(serial != lunge_serial || lunge_state != BOUNTY_MANTIS_DASH)
		return
	lunge_path = null
	lunge_cut = null
	lunge_state = BOUNTY_MANTIS_RECOVER
	var/recover = lunge_hit ? BOUNTY_MANTIS_RECOVER_HIT : BOUNTY_MANTIS_RECOVER_WHIFF
	if(blocked)
		recover = BOUNTY_MANTIS_RECOVER_BLOCKED
		owner.visible_message(span_warning("[owner] rebounds off [blocker] and staggers!"))
		owner.Shake(2, 1, recover)
	else if(!lunge_hit)
		if(blocker)
			owner.visible_message(span_warning("[owner] crashes into [blocker]!"))
			playsound(owner, 'sound/effects/bang.ogg', 50, TRUE)
		else
			owner.visible_message(span_warning("[owner] skids to a stop, blades scraping the floor."))
	owner.changeNext_move(recover)
	addtimer(CALLBACK(src, PROC_REF(end_recovery), serial), recover, TIMER_DELETE_ME)

/// Back on balance: free to move and swing again
/datum/bounty_chrome/mantis/proc/end_recovery(serial)
	if(serial != lunge_serial || lunge_state != BOUNTY_MANTIS_RECOVER)
		return
	lunge_state = null
	REMOVE_TRAIT(owner, TRAIT_IMMOBILIZED, BOUNTY_MANTIS_TRAIT)

/// Stops any lunge where it is: no marks, no crouch, free to move. Safe at any time.
/datum/bounty_chrome/mantis/proc/cancel_lunge()
	lunge_serial++
	clear_marks()
	lunge_path = null
	lunge_cut = null
	if(!lunge_state)
		return
	lunge_state = null
	if(owner)
		owner.remove_offsets(BOUNTY_MANTIS_TRAIT)
		REMOVE_TRAIT(owner, TRAIT_IMMOBILIZED, BOUNTY_MANTIS_TRAIT)

/// Takes the marked line off the floor
/datum/bounty_chrome/mantis/proc/clear_marks()
	for(var/datum/weakref/ref as anything in lunge_marks)
		var/obj/effect/mark = ref.resolve()
		if(!QDELETED(mark))
			qdel(mark)
	lunge_marks = null

#undef BOUNTY_MANTIS_TRAIT
#undef BOUNTY_MANTIS_BLADE
#undef BOUNTY_MANTIS_LUNGE_RANGE
#undef BOUNTY_MANTIS_LUNGE_MIN
#undef BOUNTY_MANTIS_LUNGE_WINDUP
#undef BOUNTY_MANTIS_LUNGE_COOLDOWN
#undef BOUNTY_MANTIS_FIRST_LUNGE
#undef BOUNTY_MANTIS_LUNGE_DAMAGE
#undef BOUNTY_MANTIS_LUNGE_WOUND
#undef BOUNTY_MANTIS_LUNGE_KNOCKDOWN
#undef BOUNTY_MANTIS_RECOVER_HIT
#undef BOUNTY_MANTIS_RECOVER_WHIFF
#undef BOUNTY_MANTIS_RECOVER_BLOCKED
#undef BOUNTY_MANTIS_WATCH
#undef BOUNTY_MANTIS_MARK_COLOR
#undef BOUNTY_MANTIS_CROUCH
#undef BOUNTY_MANTIS_WINDUP
#undef BOUNTY_MANTIS_DASH
#undef BOUNTY_MANTIS_RECOVER

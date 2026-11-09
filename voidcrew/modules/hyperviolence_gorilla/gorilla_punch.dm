/**
 * # The Gorilla punch, through #509
 *
 * The piston punch of Gorilla Arms and Brawler myomers (ware_military_arms.dm on_punch()) lands here:
 * - The blow goes through #509 like any weapon: the punching hand is the attacking item and the blow
 *   has a direction, so aimed crits roll, blood sprays the way it went, and every wound line joins
 *   the attack line in one message.
 * - Bone breakers: piston hits on one limb strain it. The third Gorilla hit inside the window (the
 *   fourth from Brawler myomers) snaps an arm or a leg, or caves in the ribs. Heavy armour on the limb,
 *   robotic limbs and the Atlas frame stop the snap, and the head never snaps.
 * - The knockback rides the safe path (gorilla_throw.dm). A grabbed body is hurled, once per grab-move
 *   cooldown shared with the slam, so a held body can't be thrown into a wall over and over.
 * - Grab and slam: with someone in an aggressive grab, a click on the floor under them, an open floor
 *   beside you or a table lifts them and brings them down. Brawler myomers slam lighter, with a lower
 *   lift and a body-fall thud. A table click while grabbing slams instead of caving the table in.
 * - Every Gorilla blow on a person counts as PvP aggression at a trader outpost: the punch cancels the
 *   attack chain before the outpost's own unarmed-attack listener ever hears it.
 */

/obj/item/organ/cyberimp/cyberware/gorilla_arms
	/// The hurl, the haymaker, the flex, and the Gorilla pair's pound and three finishers. The Brawler has none
	/// of these; its pair has its own pound and the limb rip (cyberware_brawler, ware_line_models_a.dm).
	var/heavy_moves = TRUE
	/// Whether a grabbed body can be slammed onto the floor or a table.
	var/grab_slam = TRUE
	/// Brute a floor slam deals.
	var/slam_floor_damage = GORILLA_SLAM_FLOOR_DAMAGE
	/// Stamina a floor slam takes.
	var/slam_floor_stamina = GORILLA_SLAM_FLOOR_STAMINA
	/// Brute a table slam deals.
	var/slam_table_damage = GORILLA_SLAM_TABLE_DAMAGE
	/// Stamina a table slam takes.
	var/slam_table_stamina = GORILLA_SLAM_TABLE_STAMINA
	/// How long a slam floors them.
	var/slam_knockdown = GORILLA_SLAM_KNOCKDOWN
	/// Damage a table slam does to the table.
	var/slam_table_break = GORILLA_SLAM_TABLE_BREAK
	/// The bearer-wide wait after a slam or a hurl before the next one.
	var/grab_move_cooldown = GORILLA_GRAB_MOVE_COOLDOWN
	/// How high a slammed body is lifted, in pixels.
	var/slam_lift = GORILLA_SLAM_LIFT
	/// The Gorilla's floor slam: the meteor crash, the big ring and the cracks. Off: a body-fall thud, a small ring.
	var/slam_full_fx = TRUE
	/// What drives the fist, in the attack line.
	var/fist_word = "piston-driven"
	/// Strain on one limb that snaps it.
	var/snap_strain = 3
	/// Wound bonus on the punch.
	var/punch_wound_bonus = GORILLA_PUNCH_WOUND_BONUS
	/// The sparks a landed punch throws (gorilla_gore.dmi).
	var/impact_state = "impact_gorilla"

/// Starts (or restarts) a bearer-wide cooldown, replacing any one already running under [index].
/proc/gorilla_cooldown(mob/living/bearer, index, time)
	var/old_timer = TIMER_COOLDOWN_RUNNING(bearer, index)
	if(old_timer)
		deltimer(old_timer)
		TIMER_COOLDOWN_END(bearer, index)
	S_TIMER_COOLDOWN_START(bearer, index, time)

/// Counts a Gorilla blow on [victim] as PvP aggression at a trader outpost.
/proc/gorilla_register_aggression(mob/living/victim, mob/living/offender)
	if(!isliving(victim) || !isliving(offender) || victim == offender)
		return
	GLOB.outpost_pvp_enforcement?.register_pvp_aggression(victim, offender)

/// The bearer's installed Gorilla Arms of the real (heavy) kind, both sides.
/proc/gorilla_heavy_arms(mob/living/carbon/bearer)
	RETURN_TYPE(/list)
	. = list()
	if(!iscarbon(bearer))
		return
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm in bearer.organs)
		if(arm.heavy_moves && arm.owner == bearer)
			. += arm

/// Whether [bearer] has both real Gorilla arms synced (the set bonus): the finishers and the ground pound.
/proc/gorilla_synced(mob/living/carbon/bearer)
	var/datum/status_effect/organ_set_bonus/cyberware_gorilla/bonus = bearer?.has_status_effect(/datum/status_effect/organ_set_bonus/cyberware_gorilla)
	return !!bonus?.bonus_active

/// Whether [bearer] has both Brawler myomers synced: the Brawler pound, the forced door and the limb rip.
/proc/brawler_synced(mob/living/carbon/bearer)
	var/datum/status_effect/organ_set_bonus/cyberware_gorilla/bonus = bearer?.has_status_effect(/datum/status_effect/organ_set_bonus/cyberware_brawler)
	return !!bonus?.bonus_active

/// [bearer]'s installed arms that sync into [bonus_type] (an arm's pair_bonus).
/proc/gorilla_pair_arms(mob/living/carbon/bearer, bonus_type)
	RETURN_TYPE(/list)
	. = list()
	if(!iscarbon(bearer) || !bonus_type)
		return
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm in bearer.organs)
		if(arm.pair_bonus == bonus_type && arm.owner == bearer)
			. += arm

/// The arms of [bearer]'s synced pair, Gorilla or Brawler; empty when neither is synced.
/proc/gorilla_synced_pair(mob/living/carbon/bearer)
	RETURN_TYPE(/list)
	if(gorilla_synced(bearer))
		return gorilla_pair_arms(bearer, /datum/status_effect/organ_set_bonus/cyberware_gorilla)
	if(brawler_synced(bearer))
		return gorilla_pair_arms(bearer, /datum/status_effect/organ_set_bonus/cyberware_brawler)
	return list()

/**
 * Who may use the Gorilla's heavy moves: the slam, the haymaker, the ground pound and the finishers.
 * Players, and NPCs of boss rank, as with gun executions (hv_can_execute()). This is the one gate for all
 * of them, so letting other NPCs use the moves later is a change here and nowhere else.
 */
/proc/gorilla_may_use_heavy_moves(mob/living/bearer)
	return isliving(bearer) && bearer.hv_can_execute()

/// Whether this arm's chrome is running (not EMP'd, browned out or failing).
/obj/item/organ/cyberimp/cyberware/gorilla_arms/proc/gorilla_running()
	if(organ_flags & ORGAN_FAILING)
		return FALSE
	var/datum/component/cyberware/chrome = GetComponent(/datum/component/cyberware)
	return !chrome || chrome.is_running()

// =========================================================================
// THE PISTON PUNCH
// =========================================================================

/**
 * A landed piston punch on [living_target]: the damage through #509 as one line, strain, the
 * knockback or the hurl, aggression, and the look. Returns the brute it dealt.
 */
/obj/item/organ/cyberimp/cyberware/gorilla_arms/proc/piston_hit(mob/living/carbon/human/source, mob/living/living_target, obj/item/bodypart/active_hand)
	var/grabbed = living_target.pulledby == source && source.grab_state >= GRAB_AGGRESSIVE
	var/standing = source.body_position != LYING_DOWN
	var/hurl = heavy_moves && hurl_range > 0 && grabbed && standing && TIMER_COOLDOWN_FINISHED(source, COOLDOWN_GORILLA_GRAB_MOVE)
	var/direction = get_dir(source, living_target) || source.dir
	source.do_attack_animation(living_target, ATTACK_EFFECT_SMASH)
	gorilla_punch_impact_sound(living_target)
	var/target_zone = living_target.get_random_valid_zone(source.zone_selected)
	var/armor_block = living_target.run_armor_check(target_zone, MELEE, armour_penetration = active_hand.unarmed_effectiveness)
	if(hurl)
		living_target.hv_hold_attack_message("[source] hurls [living_target] across the room!", "[source] hurls you across the room!", "You hurl [living_target] across the room!", source)
	else
		living_target.hv_hold_attack_message("[source] slams [living_target] with a [fist_word] fist!", "[source] slams you with a [fist_word] fist!", "You slam [living_target]!", source)
	var/list/wounds_before
	if(iscarbon(living_target))
		var/mob/living/carbon/carbon_before = living_target
		wounds_before = carbon_before.gorilla_wound_snapshot()
	var/dealt = living_target.apply_damage(punch_damage, BRUTE, target_zone, armor_block, wound_bonus = punch_wound_bonus, attack_direction = direction, attacking_item = active_hand)
	var/wounded = FALSE
	if(iscarbon(living_target) && !QDELETED(living_target))
		var/mob/living/carbon/carbon_target = living_target
		if(dealt >= GORILLA_STRAIN_MIN_DAMAGE)
			gorilla_add_strain(carbon_target, check_zone(target_zone), source, snap_strain, active_hand, direction)
		wounded = gorilla_new_wound(carbon_target, wounds_before)
	living_target.hv_flush_hit()
	gorilla_register_aggression(living_target, source)
	if(standing && !QDELETED(living_target))
		if(hurl)
			gorilla_cooldown(source, COOLDOWN_GORILLA_GRAB_MOVE, grab_move_cooldown)
			gorilla_launch(living_target, source, direction, hurl_range, 2, FALSE, FALSE, wounded)
		else if(!grabbed)
			gorilla_launch(living_target, source, direction, 1, rand(1, 4), TRUE, FALSE, wounded)
	gorilla_punch_fx(source, living_target, wounded)
	log_combat(source, living_target, hurl ? "piston-hurled" : "piston-punched", "gorilla arms")
	return dealt

/// Whether [victim] picked up a wound (or a worse one) since [before] (gorilla_wound_snapshot()).
/proc/gorilla_new_wound(mob/living/carbon/victim, list/before)
	for(var/datum/wound/wound as anything in victim.all_wounds)
		if(!(wound in before) || before[wound] < wound.severity)
			return TRUE
	return FALSE

/**
 * What a piston punch looks like: knuckle sparks over the target, and on a heavy hit a small ring.
 */
/obj/item/organ/cyberimp/cyberware/gorilla_arms/proc/gorilla_punch_fx(mob/living/carbon/human/source, mob/living/target, heavy = FALSE)
	gorilla_play_impact(source, target, impact_state)
	if(heavy)
		var/turf/spot = get_turf(target)
		if(spot)
			new /obj/effect/temp_visual/circle_wave/cyberware_slam(spot, 0.4)

/// The sound of a landed piston punch on [target]. The one place to swap it.
/proc/gorilla_punch_impact_sound(atom/target)
	playsound(get_turf(target), GORILLA_PUNCH_SOUND, 55, TRUE, -1)

/// The landed piston punch: one of three at random.
/datum/sound_effect/gorilla_piston_punch
	key = GORILLA_PUNCH_SOUND
	file_paths = list(
		'voidcrew/modules/hyperviolence_gorilla/sound/gorilla_piston_punch.ogg',
		'voidcrew/modules/hyperviolence_gorilla/sound/gorilla_piston_punch2.ogg',
		'voidcrew/modules/hyperviolence_gorilla/sound/gorilla_piston_punch3.ogg',
	)

/// The sound of a landed haymaker on [target]. The one place to swap it.
/proc/gorilla_haymaker_impact_sound(atom/target)
	playsound(target, GORILLA_HAYMAKER_SOUND, 70, TRUE)

/// The sound of a back breaking across a Gorilla's knee on [target]. The one place to swap it.
/proc/gorilla_backbreaker_sound(atom/target)
	playsound(target, GORILLA_BACKBREAKER_SOUND, 70, TRUE)

/**
 * Knuckle sparks over [target]: a short one-shot drawn upright and turned to come from the
 * attacker's side, like cyberware_play_impact() but from this module's sheet.
 */
/proc/gorilla_play_impact(atom/movable/attacker, atom/movable/target, impact_state)
	if(!impact_state || !ismovable(target))
		return null
	var/obj/effect/abstract/cyberware_anim/impact = cyberware_anim_play(target, GORILLA_GORE_ICON, impact_state, GORILLA_ANIM_TOP_LAYER, 0.4 SECONDS, glow = impact_state == "impact_gorilla")
	if(!impact)
		return null
	impact.appearance_flags |= RESET_TRANSFORM
	var/direction = get_dir(attacker, target)
	if((direction & WEST) || (!(direction & EAST) && prob(50)))
		impact.transform = matrix(-1, 0, 0, 0, 1, 0)
	return impact

// =========================================================================
// BONE BREAKERS
// =========================================================================

/**
 * Strain on a body from piston hits: how many hard hits each limb has taken, and when the last one
 * landed. A limb that goes [GORILLA_STRAIN_MEMORY] without a hit forgets its count. Expires on its own.
 */
/datum/status_effect/gorilla_strain
	id = "gorilla_strain"
	alert_type = null
	duration = GORILLA_STRAIN_MEMORY
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_REFRESH
	/// Body zone -> hard hits counted
	var/list/counts = list()
	/// Body zone -> world.time of its last hard hit
	var/list/last_hit = list()

/// Counts one more hard hit on [zone]. Returns the count.
/datum/status_effect/gorilla_strain/proc/add(zone)
	if(world.time - (last_hit[zone] || -INFINITY) > GORILLA_STRAIN_MEMORY)
		counts[zone] = 0
	counts[zone] = (counts[zone] || 0) + 1
	last_hit[zone] = world.time
	return counts[zone]

/// Forgets [zone]'s count after it snapped.
/datum/status_effect/gorilla_strain/proc/clear(zone)
	counts -= zone
	last_hit -= zone

/// A hard piston hit on [zone]: strains it, and snaps it when it has taken [snap_at] in the window.
/proc/gorilla_add_strain(mob/living/carbon/victim, zone, mob/living/attacker, snap_at, obj/item/source_item, direction)
	if(zone == BODY_ZONE_HEAD)
		return FALSE
	var/datum/status_effect/gorilla_strain/strain = victim.has_status_effect(/datum/status_effect/gorilla_strain)
	if(strain)
		strain.refresh()
	else
		strain = victim.apply_status_effect(/datum/status_effect/gorilla_strain)
	if(!strain)
		return FALSE
	if(strain.add(zone) < snap_at)
		return FALSE
	strain.clear(zone)
	return gorilla_snap_limb(victim, victim.get_bodypart(zone), attacker, direction, source_item)

/**
 * Snaps [limb]: tg's compound fracture forced on an arm or a leg, or the ribs caved in on the chest.
 * Heavy armour on the limb, a limb without bone (robotic) and the Atlas frame stop it. Returns TRUE
 * if it snapped.
 */
/proc/gorilla_snap_limb(mob/living/carbon/victim, obj/item/bodypart/limb, mob/living/attacker, direction, obj/item/source_item)
	if(isnull(limb) || limb.owner != victim || limb.body_zone == BODY_ZONE_HEAD)
		return FALSE
	if(hv_crit_cover_rating(victim, limb, MELEE) >= GORILLA_SNAP_ARMOUR)
		return FALSE
	if(!hv_crit_apply_wound(limb, /datum/wound/blunt/bone/critical, direction, source_item))
		return FALSE
	if(limb.body_zone == BODY_ZONE_CHEST)
		victim.hv_add_hit_line("[victim]'s ribs cave in!", HV_LINE_HUGE, "Your ribs cave in!", DEFAULT_MESSAGE_RANGE)
	else
		victim.hv_add_hit_line("The bone in [victim]'s [limb.plaintext_zone] snaps!", HV_LINE_HUGE, "The bone in your [limb.plaintext_zone] snaps!", DEFAULT_MESSAGE_RANGE)
	playsound(victim, 'sound/effects/wounds/crack2.ogg', 80, TRUE, falloff_exponent = SOUND_FALLOFF_EXPONENT + 2, ignore_walls = FALSE, falloff_distance = 0)
	cyberware_flash_fx(victim, 0.2 SECONDS)
	var/turf/spot = get_turf(victim)
	if(spot)
		new /obj/effect/temp_visual/circle_wave/cyberware_slam(spot, 0.5)
	log_combat(attacker, victim, "snapped the [limb.plaintext_zone] of", source_item, "(gorilla arms)")
	return TRUE

// =========================================================================
// GRAB AND SLAM
// =========================================================================

/**
 * With someone in an aggressive grab, a click on the floor under them, an open floor beside the bearer
 * or a table brings them down onto it. Returns GORILLA_SLAM_*.
 */
/obj/item/organ/cyberimp/cyberware/gorilla_arms/proc/try_slam(mob/living/carbon/human/source, atom/target, obj/item/bodypart/active_hand)
	var/mob/living/victim = source.pulling
	if(!isliving(victim) || source.grab_state < GRAB_AGGRESSIVE || victim == source)
		return GORILLA_SLAM_NO
	var/obj/structure/table/table = istype(target, /obj/structure/table) ? target : null
	if(!table && !isturf(target))
		return GORILLA_SLAM_NO
	if(!grab_slam || !gorilla_running() || !gorilla_may_use_heavy_moves(source) || HAS_TRAIT(source, TRAIT_PACIFISM) || victim.buckled || source.body_position == LYING_DOWN)
		return table ? GORILLA_SLAM_PASS : GORILLA_SLAM_NO
	if(!TIMER_COOLDOWN_FINISHED(source, COOLDOWN_GORILLA_GRAB_MOVE))
		return table ? GORILLA_SLAM_PASS : GORILLA_SLAM_NO
	var/turf/victim_spot = get_turf(victim)
	var/turf/spot = table ? get_turf(table) : target
	if(!source.Adjacent(spot))
		return GORILLA_SLAM_NO
	if(!table && !gorilla_slam_floor_ok(spot))
		return GORILLA_SLAM_NO
	source.stop_pulling()
	if(spot != victim_spot)
		var/passtable_key = REF(source)
		if(table)
			passtable_on(victim, passtable_key)
		victim.Move(spot, get_dir(victim, spot))
		if(table)
			passtable_off(victim, passtable_key)
		if(victim.loc != spot)
			// Something stopped them getting there: no slam, but the grab is gone
			return table ? GORILLA_SLAM_PASS : GORILLA_SLAM_NO
	gorilla_cooldown(source, COOLDOWN_GORILLA_GRAB_MOVE, grab_move_cooldown)
	source.changeNext_move(CLICK_CD_MELEE)
	source.face_atom(victim)
	// Up, then down: the blow lands as the body comes down.
	animate(victim, pixel_z = slam_lift, time = 0.12 SECONDS, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
	animate(pixel_z = 0, time = 0.06 SECONDS, flags = ANIMATION_RELATIVE)
	animate(pixel_z = -slam_lift, time = 0.06 SECONDS, easing = SINE_EASING | EASE_IN, flags = ANIMATION_RELATIVE)
	source.do_attack_animation(victim, ATTACK_EFFECT_SMASH)
	addtimer(CALLBACK(src, PROC_REF(slam_down), source, victim, spot, table ? WEAKREF(table) : null, active_hand), 0.24 SECONDS)
	return GORILLA_SLAM_DONE

/**
 * Slams whoever [bearer] holds in an aggressive grab onto [onto] (their own tile, an open floor beside the
 * bearer, or a table) with the active arm, as a click there would. Returns TRUE if it slammed. For an AI.
 * Brawler arms slam too; gorilla_may_use_heavy_moves() still keeps it to players and boss-rank NPCs.
 */
/proc/gorilla_try_slam(mob/living/carbon/human/bearer, atom/onto)
	var/obj/item/bodypart/hand = bearer?.get_active_hand()
	if(!iscarbon(bearer))
		return FALSE
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm in bearer.organs)
		if(arm.owner != bearer || !arm.grab_slam || arm.zone != hand?.body_zone || !arm.gorilla_running() || !COOLDOWN_FINISHED(arm, slam_cooldown))
			continue
		if(arm.try_slam(bearer, onto, hand) != GORILLA_SLAM_DONE)
			return FALSE
		COOLDOWN_START(arm, slam_cooldown, arm.punch_cooldown_time)
		return TRUE
	return FALSE

/// Whether a body can be slammed down on [spot]: solid floor with gravity and nothing standing in the way.
/proc/gorilla_slam_floor_ok(turf/spot)
	if(!isfloorturf(spot) || isgroundlessturf(spot) || !spot.has_gravity())
		return FALSE
	for(var/obj/thing in spot)
		if(thing.density && !(thing.flags_1 & ON_BORDER_1))
			return FALSE
	return TRUE

/// The slam lands, if the body is still where it was brought down.
/obj/item/organ/cyberimp/cyberware/gorilla_arms/proc/slam_down(mob/living/carbon/human/source, mob/living/victim, turf/spot, datum/weakref/table_ref, obj/item/bodypart/active_hand)
	if(QDELETED(source) || QDELETED(victim) || victim.loc != spot || owner != source)
		return
	var/obj/structure/table/table = table_ref?.resolve()
	if(table && table.loc != spot)
		table = null
	var/aimed = source.zone_selected
	var/obj/item/bodypart/limb = victim.get_bodypart(check_zone(aimed)) || victim.get_bodypart(BODY_ZONE_CHEST)
	var/face_first = check_zone(aimed) == BODY_ZONE_HEAD
	var/damage = table ? slam_table_damage : slam_floor_damage
	var/stamina = table ? slam_table_stamina : slam_floor_stamina
	var/others
	var/self
	if(table)
		others = face_first ? "[source] slams [victim] face first into [table]!" : "[source] slams [victim] onto [table]!"
		self = face_first ? "[source] slams you face first into [table]!" : "[source] slams you onto [table]!"
	else
		others = "[source] slams [victim] into the floor!"
		self = "[source] slams you into the floor!"
	victim.hv_hold_attack_message(others, self, null, source, vision_range = DEFAULT_MESSAGE_RANGE)
	var/armour = victim.run_armor_check(limb, MELEE)
	victim.apply_damage(damage, BRUTE, limb || BODY_ZONE_CHEST, armour, wound_bonus = punch_wound_bonus, attack_direction = get_dir(source, victim) || source.dir, attacking_item = active_hand)
	victim.hv_flush_hit()
	if(QDELETED(victim))
		return
	victim.apply_damage(stamina, STAMINA)
	victim.Knockdown(slam_knockdown)
	gorilla_register_aggression(victim, source)
	shake_camera(victim, slam_full_fx ? 3 : 2, slam_full_fx ? 2 : 1)
	cyberware_flash_fx(victim, 0.2 SECONDS)
	new /obj/effect/temp_visual/circle_wave/cyberware_slam(spot, slam_full_fx ? 0.8 : 0.5)
	if(table)
		playsound(victim, 'sound/effects/tableslam.ogg', 90, TRUE)
		var/datum/component/table_smash/smash = table.GetComponent(/datum/component/table_smash)
		table.take_damage(slam_table_break)
		// Glass tables break as they do under any slammed body
		if(!QDELETED(table))
			smash?.after_smash?.Invoke(victim)
	else if(slam_full_fx)
		playsound(spot, 'sound/effects/meteorimpact.ogg', 40, TRUE)
		new /obj/effect/temp_visual/cyberware_impact_cracks(spot, "damaged1", 220)
		cyberware_grey_dust(spot)
	else
		playsound(spot, SFX_BODYFALL, 70, TRUE)
		new /obj/effect/temp_visual/cyberware_impact_cracks(spot, "damaged1", 70)
	log_combat(source, victim, table ? "piston-slammed onto a table" : "piston-slammed into the floor", "gorilla arms")

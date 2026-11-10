/**
 * # Finisher stages
 *
 * One step of a finisher (finisher.dm). A stage runs for [var/duration]; its beat, effect(), fires
 * [var/effect_delay] in, or the moment it begins when that is 0. enter() poses the attacker and
 * shows the stage's opening line; the beat shows the gory line through hv_add_hit_line().
 *
 * The kinds here carry the mechanics. Each boss subtypes them in finisher_users.dm for its own
 * words, sounds and timing:
 * - windup: rears up and marks the victim. Holds nobody, so the victim can still be pulled clear.
 * - hold: the pin. From here the victim is held down.
 * - maul: a bite or a blow, with blood. Deals no damage, so the victim lives to the end. When a person
 *   does it (host.real_hits) it is a real blow with the weapon in hand instead, at [var/blow_zone].
 * - kill/rip_limb, kill/decapitate, kill/burst_head, kill/bisect: the killing blow. A person's is a real
 *   blow with a higher wound bonus (real_kill()); tg's wounds and dismemberment decide what it takes.
 * - recover: the attacker straightens up after the kill. Lets the victim go.
 */

/datum/hv_finisher_stage
	/// The finisher it belongs to
	var/datum/hv_finisher/host
	/// How long the stage lasts
	var/duration = 1 SECONDS
	/// How far into the stage its beat fires
	var/effect_delay = 0
	/// TRUE once the beat has fired
	var/effect_done = FALSE
	/// TRUE once the stage has begun
	var/entered = FALSE
	/// The victim is held down during this stage
	var/pins = TRUE
	/// This stage's beat is the kill. Once it lands nothing calls the finisher off.
	var/killing_blow = FALSE
	/// Pixels the attacker leans toward the victim during this stage
	var/lunge = 0
	/// Pixels the attacker rises during this stage
	var/rise = 0
	/// Sound when the stage begins, from the attacker
	var/enter_sound
	var/enter_volume = 60
	/// Playback speed of the opening sound. Null lets it vary as playsound() does; a big beast wants a fixed low one.
	var/enter_frequency
	/// Sound of the beat, from the victim
	var/effect_sound
	var/effect_volume = 70
	/// HV_LINE_BOLD or HV_LINE_HUGE for the beat's line. 0 shows it as a plain combat line.
	var/effect_severity = HV_LINE_BOLD
	/// How far the beat's line carries
	var/effect_range = COMBAT_MESSAGE_RANGE
	/// How far the opening line carries. The crew should see a boss rear up over one of their own.
	var/enter_range = DEFAULT_MESSAGE_RANGE

/datum/hv_finisher_stage/New(datum/hv_finisher/host)
	. = ..()
	src.host = host

/datum/hv_finisher_stage/Destroy()
	host = null
	return ..()

/// Begins the stage: pose, sound and its opening line
/datum/hv_finisher_stage/proc/enter()
	entered = TRUE
	host.user.face_atom(host.victim)
	host.pose_user(lunge, rise)
	if(enter_sound)
		playsound(host.user, enter_sound, enter_volume, TRUE, frequency = enter_frequency)
	var/text = enter_message()
	if(text)
		host.victim.visible_message(span_danger(text), span_userdanger(enter_self_message() || text), vision_distance = enter_range)

/// The stage's beat
/datum/hv_finisher_stage/proc/effect()
	if(effect_sound)
		playsound(host.victim, effect_sound, effect_volume, TRUE)
	show_effect_line()

/// Shows [proc/effect_message] at [var/effect_severity]
/datum/hv_finisher_stage/proc/show_effect_line()
	var/text = effect_message()
	if(!text)
		return
	if(effect_severity)
		// Positional: (text, severity, self_text, range) on the shared hook
		host.victim.hv_add_hit_line(text, effect_severity, effect_self_message(), effect_range)
		return
	var/self_text = effect_self_message()
	host.victim.visible_message(span_danger(text), self_text ? span_userdanger(self_text) : null, vision_distance = effect_range)

/// What the room sees as the stage begins, or null for nothing
/datum/hv_finisher_stage/proc/enter_message()
	return null

/// What the victim sees as the stage begins, or null to see the room's line
/datum/hv_finisher_stage/proc/enter_self_message()
	return null

/// The line of the beat, or null for none
/datum/hv_finisher_stage/proc/effect_message()
	return null

/// What the victim sees of the beat, or null to see the room's line
/datum/hv_finisher_stage/proc/effect_self_message()
	return null

/// Called as the finisher moves on to the next stage
/datum/hv_finisher_stage/proc/exit()
	return

/// Called on every stage that began when the finisher is called off before the kill
/datum/hv_finisher_stage/proc/on_interrupt()
	return

/// Called on every stage that began when the finisher ends, however it ends
/datum/hv_finisher_stage/proc/on_stop()
	return

/// The name of the limb the kill goes for ("left arm"), or "body" if there is none
/datum/hv_finisher_stage/proc/target_limb_name()
	var/obj/item/bodypart/part = host.target_zone ? host.victim.get_bodypart(host.target_zone) : null
	return part ? part.plaintext_zone : "body"

/// Which way blood flies: away from the attacker
/datum/hv_finisher_stage/proc/away_dir()
	return get_dir(host.user, host.victim) || host.user.dir

// ===== Wind-up =====

/// Rears up over the victim and marks them. Holds nobody yet.
/datum/hv_finisher_stage/windup
	pins = FALSE
	duration = 1.5 SECONDS
	rise = 6
	/// Something the attacker says as it winds up, or null
	var/say_line

/datum/hv_finisher_stage/windup/enter()
	. = ..()
	host.place_mark(duration)
	if(say_line)
		INVOKE_ASYNC(host.user, TYPE_PROC_REF(/atom/movable, say), say_line)

// ===== Hold =====

/// The pin. A beat with no damage.
/datum/hv_finisher_stage/hold
	duration = 1.5 SECONDS
	lunge = 6
	effect_severity = 0

// ===== Maul =====

/// A bite or a blow: blood and a shake, but no damage, so the victim lives until the kill. A person's is a
/// real blow with its weapon at blow_zone.
/datum/hv_finisher_stage/maul
	duration = 2 SECONDS
	effect_delay = 0.5 SECONDS
	lunge = 8
	/// How far the blood flies
	var/spray_strength = 2
	/// Where a person's blow lands
	var/blow_zone = BODY_ZONE_HEAD

/datum/hv_finisher_stage/maul/effect()
	. = ..()
	if(host.real_hits)
		host.real_blow(blow_zone)
		return
	host.victim.hv_blood_spray(away_dir(), spray_strength)
	host.victim.hv_vis_shudder(2, 1, 0.6 SECONDS)

// ===== The kill =====

/// The killing blow. Subtypes do the gore in gore(); if there is nothing to take, fallback() hurts them instead.
/datum/hv_finisher_stage/kill
	killing_blow = TRUE
	duration = 1.5 SECONDS
	effect_delay = 0.5 SECONDS
	lunge = 4
	effect_severity = HV_LINE_HUGE
	// Carries as far as tg's own dismemberment line
	effect_range = DEFAULT_MESSAGE_RANGE
	/// How far the blood flies
	var/spray_strength = 5
	/// Brute dealt to the chest when the gore can't happen
	var/fallback_damage = 40

/datum/hv_finisher_stage/kill/effect()
	if(effect_sound)
		playsound(host.victim, effect_sound, effect_volume, TRUE)
	var/spray_dir = away_dir()
	if(host.real_hits)
		real_kill(spray_dir)
		return
	if(!can_gore())
		fallback(spray_dir)
		return
	// The line names the part, so it goes out while the part is still attached
	show_effect_line()
	gore(spray_dir)

/// Where a person's killing blow lands
/datum/hv_finisher_stage/kill/proc/real_zones()
	return list(host.target_zone || BODY_ZONE_CHEST)

/**
 * A person's killing blow: a real blow at each of real_zones() with the finisher's extra wound bonus. What
 * it takes off, if anything, is tg's to decide. The line said is what happened: the gore line if the part
 * came off, else the fallback.
 */
/datum/hv_finisher_stage/kill/proc/real_kill(spray_dir)
	var/list/before = real_parts()
	for(var/zone in real_zones())
		host.real_blow(zone, host.kill_wound_bonus)
		if(QDELETED(host.victim))
			return
	var/list/after = real_parts()
	if(length(after) < length(before))
		show_effect_line()
		return
	var/text = fallback_message()
	if(text)
		host.victim.hv_add_hit_line(text, HV_LINE_BOLD, null, effect_range)

/// The parts a person's killing blow goes for that the victim still has
/datum/hv_finisher_stage/kill/proc/real_parts()
	. = list()
	for(var/zone in real_zones())
		var/obj/item/bodypart/part = host.victim.get_bodypart(zone)
		if(part)
			. += part

/// Whether the victim still has what gore() takes
/datum/hv_finisher_stage/kill/proc/can_gore()
	return FALSE

/// The gore itself
/datum/hv_finisher_stage/kill/proc/gore(spray_dir)
	return

/// When there is nothing to take: a heavy wound instead
/datum/hv_finisher_stage/kill/proc/fallback(spray_dir)
	var/text = fallback_message()
	if(text)
		host.victim.hv_add_hit_line(text, HV_LINE_BOLD, null, effect_range)
	host.victim.apply_damage(fallback_damage, BRUTE, BODY_ZONE_CHEST, wound_bonus = 10, sharpness = SHARP_EDGED, attack_direction = spray_dir)
	host.victim.hv_blood_spray(spray_dir, 3)

/// The line for fallback()
/datum/hv_finisher_stage/kill/proc/fallback_message()
	return "[host.user] tears into [host.victim]!"

/// Tears off the limb at the finisher's target zone, flinging it
/datum/hv_finisher_stage/kill/rip_limb

/datum/hv_finisher_stage/kill/rip_limb/can_gore()
	if(!host.target_zone || host.target_zone == BODY_ZONE_HEAD || host.target_zone == BODY_ZONE_CHEST)
		return FALSE
	var/obj/item/bodypart/part = host.victim.get_bodypart(host.target_zone)
	return part?.can_dismember()

/datum/hv_finisher_stage/kill/rip_limb/gore(spray_dir)
	var/obj/item/bodypart/part = host.victim.get_bodypart(host.target_zone)
	host.victim.hv_blood_spray(spray_dir, spray_strength)
	// Torn off toward whoever tore it: it comes away with the pull and falls between the two of them,
	// not off in whatever direction tg picks.
	part?.hv_vis_fling_dir = REVERSE_DIR(spray_dir)
	part?.dismember(BRUTE, TRUE, WOUND_SLASH)

/// Takes the head off and leaves it at the victim's feet, brain and all
/datum/hv_finisher_stage/kill/decapitate

/datum/hv_finisher_stage/kill/decapitate/can_gore()
	var/obj/item/bodypart/head/head = host.victim.get_bodypart(BODY_ZONE_HEAD)
	return head?.can_dismember()

/datum/hv_finisher_stage/kill/decapitate/gore(spray_dir)
	host.victim.hv_blood_spray(spray_dir, spray_strength)
	hv_finisher_take_head(host.victim, WOUND_SLASH)

/// Bursts the head through the shared hook, which keeps the brain intact
/datum/hv_finisher_stage/kill/burst_head
	// hv_burst_head() adds its own big line; this stage's line is the blow that does it
	effect_severity = HV_LINE_BOLD

/datum/hv_finisher_stage/kill/burst_head/can_gore()
	var/obj/item/bodypart/head/head = host.victim.get_bodypart(BODY_ZONE_HEAD)
	return head?.can_dismember()

/datum/hv_finisher_stage/kill/burst_head/gore(spray_dir)
	if(!host.victim.hv_burst_head(spray_dir))
		fallback(spray_dir)

/datum/hv_finisher_stage/kill/burst_head/real_zones()
	return list(BODY_ZONE_HEAD)

// The blow is the line here, whatever it does: a head that bursts says so itself (brain_burst.dm).
/datum/hv_finisher_stage/kill/burst_head/real_kill(spray_dir)
	show_effect_line()
	host.real_blow(BODY_ZONE_HEAD, host.kill_wound_bonus)

/// Cuts through at the hips: both legs come off
/datum/hv_finisher_stage/kill/bisect

/datum/hv_finisher_stage/kill/bisect/can_gore()
	for(var/zone in list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		var/obj/item/bodypart/leg = host.victim.get_bodypart(zone)
		if(leg?.can_dismember())
			return TRUE
	return FALSE

/datum/hv_finisher_stage/kill/bisect/real_zones()
	return list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)

/datum/hv_finisher_stage/kill/bisect/gore(spray_dir)
	var/turf/spot = get_turf(host.victim)
	host.victim.hv_blood_spray(spray_dir, spray_strength)
	host.victim.hv_blood_spray(REVERSE_DIR(spray_dir), 3)
	for(var/zone in list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		var/obj/item/bodypart/leg = host.victim.get_bodypart(zone)
		if(leg?.can_dismember())
			leg.dismember(BRUTE, TRUE, WOUND_SLASH)
	if(spot && !QDELETED(host.victim) && host.victim.can_bleed(BLOOD_COVER_TURFS) == BLEED_SPLATTER)
		new /obj/effect/decal/cleanable/blood/gibs(spot, host.victim.get_static_viruses(), host.victim.get_blood_dna_list())

// ===== Recover =====

/// The attacker straightens up after the kill and lets go
/datum/hv_finisher_stage/recover
	pins = FALSE
	duration = 1 SECONDS

/**
 * Takes `victim`'s head off without flinging it. dismember() throws the part a few tiles, and a
 * head carries the brain: in zero gravity it would drift away for good. So this does what
 * dismember() does for a head and drops it where the body lies. Returns the head, or null.
 */
/proc/hv_finisher_take_head(mob/living/carbon/victim, wounding_type = WOUND_SLASH)
	var/obj/item/bodypart/head/head = victim?.get_bodypart(BODY_ZONE_HEAD)
	if(!head?.can_dismember() || HAS_TRAIT(victim, TRAIT_GODMODE))
		return null
	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	chest?.receive_damage(15, wound_bonus = CANT_WOUND)
	playsound(get_turf(victim), 'sound/effects/dismember.ogg', 80, TRUE)
	LAZYSET(victim.body_zone_dismembered_by, BODY_ZONE_HEAD, wounding_type)
	var/bleeds = head.can_bleed()
	if(bleeds)
		victim.bleed(rand(20, 40))
	var/turf/spot = get_turf(victim)
	head.drop_limb(FALSE, TRUE)
	victim.update_equipment_speed_mods()
	if(bleeds && isturf(spot))
		victim.add_splatter_floor(spot)
	return head

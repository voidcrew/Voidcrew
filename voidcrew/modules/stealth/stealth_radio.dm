/**
 * # Stealth guards: radios (owner decision 8)
 *
 * Some guard types carry an earpiece (`stealth_radio` on the type, and a working headset in its ears). A
 * carrier that learns of trouble raises a hand to its earpiece, and STEALTH_RADIO_CALL_TIME later says it
 * out loud; every other carrier in its group then knows, wherever it stands, and passes it on by voice to
 * whoever stands next to it.
 *
 * Players stop a call with tg's own tools and nothing else: drop, stun or silence the speaker before the call
 * is due; run a radio jammer near the speaker or the receiver; EMP the earpiece (tg switches a radio off for
 * 20 s); deafen the receiver. The headset can't be stripped: it is locked gear like the rest of the kit.
 *
 * No timers: a pending call is a stamp the guard's scan reads. One alarm delivery per group per
 * STEALTH_RADIO_GROUP_COOLDOWN, so a den full of carriers doesn't echo itself.
 */

/mob/living/carbon/human/npc
	/// Whether this type is on its group's radio net (it still needs a working headset in its ears)
	var/stealth_radio = FALSE

/// Its working headset, or null: on the net, headset in the ears and switched on, not in a jammer's range.
/mob/living/carbon/human/npc/proc/stealth_radio_ready()
	if(!stealth_radio)
		return null
	var/obj/item/radio/earpiece = ears
	if(!istype(earpiece) || !earpiece.is_on() || is_within_radio_jammer_range(src))
		return null
	return earpiece

/**
 * Starts a radio call about `where`: a hand to the earpiece now, the call STEALTH_RADIO_CALL_TIME later if it
 * can still make it (stealth_deliver_call()). A call already on its way out is kept unless this one is more
 * urgent, so a run of noises never puts the call off. Returns TRUE if a call is now pending.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_start_call(kind, turf/where, name)
	var/mob/living/carbon/human/npc/guard = pawn
	if(!ishumannpc(guard) || !guard.stealth_radio || !istype(guard.ears, /obj/item/radio))
		return FALSE
	if(guard.stat != CONSCIOUS || stealth_driven() || isnull(where))
		return FALSE
	if(pending_call)
		if(pending_call[STEALTH_CALL_KIND] >= kind)
			return TRUE
	pending_call = list(kind, where, world.time + STEALTH_RADIO_CALL_TIME, name)
	guard.visible_message(span_emote("<b>[guard]</b> raises a hand to [guard.p_their()] earpiece."))
	return TRUE

/// The scan: makes its pending call once it is due, if it still can. A call it can't make is lost, never
/// retried; if only the radio failed, it says so.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_deliver_call()
	if(isnull(pending_call) || world.time < pending_call[STEALTH_CALL_DUE])
		return
	var/list/call_made = pending_call
	pending_call = null
	// Its level slept through it: nobody finishes a call that late.
	if(world.time > call_made[STEALTH_CALL_DUE] + STEALTH_RADIO_CALL_STALE)
		return
	var/mob/living/carbon/human/npc/guard = pawn
	if(guard.stat != CONSCIOUS || HAS_TRAIT(guard, TRAIT_INCAPACITATED) || !human_npc_can_talk(guard))
		return
	if(!guard.stealth_radio_ready())
		stealth_bark(STEALTH_BARK_RADIO_DEAD)
		return
	var/turf/where = call_made[STEALTH_CALL_WHERE]
	var/bark_kind = STEALTH_BARK_RADIO_ALARM
	switch(call_made[STEALTH_CALL_KIND])
		if(STEALTH_CALL_REPORT)
			bark_kind = STEALTH_BARK_RADIO_REPORT
		if(STEALTH_CALL_MISSING)
			bark_kind = STEALTH_BARK_RADIO_MISSING
	// Said out loud, always: anyone in earshot of the speaker hears where the others are being sent.
	stealth_bark(bark_kind, where, call_made[STEALTH_CALL_NAME], TRUE)
	group?.radio_call(guard, call_made[STEALTH_CALL_KIND], where)

/// A call that can't go out any more (the speaker was stunned, dropped or taken over).
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_drop_call()
	pending_call = null

/// Whether `guard` can take a radio call now.
/datum/stealth_group/proc/radio_receiver(mob/living/carbon/human/npc/guard)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
	if(!istype(guard_ai) || guard.stat != CONSCIOUS || guard.client || guard_ai.ai_status == AI_STATUS_OFF)
		return FALSE
	return guard.stealth_radio_ready() && guard.can_hear() && !guard_ai.stealth_captive()

/**
 * `speaker` has made its call. Every other member with a working radio that can hear gets it.
 * - A report ("checking something"): they know it went, so they miss it if it doesn't come back. Nobody moves.
 * - An alarm or a missing friend: at most one per STEALTH_RADIO_GROUP_COOLDOWN. The nearest
 *   STEALTH_RADIO_RESPONDERS receivers that aren't sentries search at the spot and answer; each brings up to
 *   STEALTH_RELAY_VOICE_RESPONDERS friends without radios from within earshot of its answer. Sentries and the
 *   rest hold.
 * Returns how many receivers got it.
 */
/datum/stealth_group/proc/radio_call(mob/living/carbon/human/npc/speaker, kind, turf/where)
	. = 0
	var/list/guards = living_members()
	if(kind == STEALTH_CALL_REPORT)
		var/list/speaker_checks = list()
		for(var/datum/stealth_check/check as anything in checks)
			if(check.who?.resolve() == speaker)
				speaker_checks += check
		for(var/mob/living/carbon/human/npc/guard as anything in guards)
			if(guard == speaker || !radio_receiver(guard))
				continue
			.++
			for(var/datum/stealth_check/check as anything in speaker_checks)
				check.waiters |= WEAKREF(guard)
		return
	if(world.time < next_radio_alarm)
		return 0
	next_radio_alarm = world.time + STEALTH_RADIO_GROUP_COOLDOWN
	// Receivers, nearest to the spot first.
	var/list/receivers = list()
	for(var/mob/living/carbon/human/npc/guard as anything in guards)
		if(guard == speaker || !radio_receiver(guard))
			continue
		var/dist = get_dist(guard, where)
		var/index = 1
		while(index <= length(receivers) && get_dist(receivers[index], where) <= dist)
			index++
		receivers.Insert(index, guard)
	var/moved = 0
	for(var/mob/living/carbon/human/npc/receiver as anything in receivers)
		.++
		var/datum/ai_controller/basic_controller/human_npc/stealth/receiver_ai = receiver.ai_controller
		if(receiver_ai.stealth_state() == STEALTH_ALERT)
			continue
		if(isnull(receiver_ai.route_id) || moved >= STEALTH_RADIO_RESPONDERS || !receiver_ai.stealth_respond(where))
			receiver_ai.stealth_hold(where)
			continue
		moved++
		receiver_ai.stealth_bark(STEALTH_BARK_COPY, null, null, TRUE)
		// Its answer carries to whoever stands near it.
		var/turf/receiver_turf = get_turf(receiver)
		var/brought = 0
		for(var/mob/living/carbon/human/npc/friend as anything in guards)
			if(brought >= STEALTH_RELAY_VOICE_RESPONDERS)
				break
			var/datum/ai_controller/basic_controller/human_npc/stealth/friend_ai = friend.ai_controller
			if(friend == receiver || friend == speaker || friend.stealth_radio || !istype(friend_ai) || isnull(friend_ai.route_id))
				continue
			if(friend.stat != CONSCIOUS || friend.client || friend_ai.ai_status == AI_STATUS_OFF || !friend.can_hear())
				continue
			var/turf/friend_turf = get_turf(friend)
			if(get_dist(friend_turf, receiver_turf) > STEALTH_RELAY_VOICE_RANGE || stealth_muffled_dist(receiver_turf, friend_turf) > STEALTH_RELAY_VOICE_RANGE)
				continue
			if(friend_ai.stealth_respond(where))
				brought++

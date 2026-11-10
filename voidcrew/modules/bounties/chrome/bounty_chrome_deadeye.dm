/// How far it locks on: the implant's tag range (CYBERWARE_DEADEYE_TAG_RANGE, ware_pro_combat.dm)
#define BOUNTY_DEADEYE_RANGE 9
/// The lock's tell: red eyes and a red laser line on the mark, before the tag lands
#define BOUNTY_DEADEYE_TELL (1 SECONDS)
/// After a fight starts, how soon it locks on: early, so the tell runs while it draws and the first homing rounds come while the fight is young
#define BOUNTY_DEADEYE_OPENING (0.5 SECONDS)
/// The same for an SMG, if that style exists (a homing burst that early outguns most hunters)
#define BOUNTY_DEADEYE_OPENING_SMG (2 SECONDS)
/// How often a held tag checks the mark is still in sight and on its feet
#define BOUNTY_DEADEYE_WATCH (0.5 SECONDS)
/// The red of the eyes, the line and the outline: the implant's reticle red
#define BOUNTY_DEADEYE_RED "#ff3300"
/// The eye-colour priority of the red eyes while it holds a lock (over a cultist's)
#define BOUNTY_DEADEYE_EYES_PRIORITY (EYE_COLOR_CULT_PRIORITY + 10)

/**
 * # Deadeye link on a bounty gunman
 *
 * The optics players buy (/obj/item/organ/eyes/robotic/cyberware/deadeye, ware_pro_combat.dm), used as a
 * player would: tag whoever it is shooting at, then shoot. The tag, its reticle on the mark, its three
 * homing rounds, its 15 seconds and its 25 second cooldown are all the implant's; the AI picks the moment,
 * shows it coming, and lets go when the mark gets away.
 *
 * - The moment: in a fight with a gun style (bounty_chrome_style_shoots()), at someone it may shoot who
 *   is on their feet and in sight within the tag's range. The first lock comes BOUNTY_DEADEYE_OPENING
 *   into the fight (BOUNTY_DEADEYE_OPENING_SMG with an SMG), then whenever the implant is off cooldown.
 * - The tell, BOUNTY_DEADEYE_TELL: its eyes go red, a red laser line runs from it to the mark, a red
 *   outline pulses on it and the scope whirs. It keeps drawing, moving and shooting meanwhile
 *   (tell_keeps_acting): the lock costs it no shots, which is what makes the optics worth a gunman's while.
 *   Out of sight when the tell ends, the implant itself refuses the tag.
 * - Then the implant's Deadeye Tag, Trigger()ed on the mark as a player's click: its next three rounds
 *   home in. The eyes stay red while the tag holds.
 * - It lets go (the implant's own end_tag(), with its "lost it" chirp) the moment the mark is out of its
 *   sight or down, and when it goes down itself or the fight ends: breaking line of sight is the answer,
 *   and a homing round never chases someone round a corner or into crit. Letting go only ever costs it.
 */
/datum/bounty_chrome_move/deadeye
	piece_key = BOUNTY_CHROME_DEADEYE
	name = "Deadeye tag"
	action_type = /datum/action/cooldown/cyberware/deadeye_tag
	tell_time = BOUNTY_DEADEYE_TELL
	tell_holds_still = FALSE
	tell_keeps_acting = TRUE
	tell_color = BOUNTY_DEADEYE_RED
	tell_sound = 'sound/items/weapons/scope.ogg'
	max_range = BOUNTY_DEADEYE_RANGE
	/// The opening lock's timer
	var/opening_timer
	/// The held tag's sight check
	var/watch_timer
	/// Weakref to who it tagged, while the tag holds
	var/datum/weakref/mark_ref

/datum/bounty_chrome_move/deadeye/detach()
	stop()
	return ..()

/datum/bounty_chrome_move/deadeye/Destroy()
	stop()
	return ..()

/// Its optics, if they are in its owner
/datum/bounty_chrome_move/deadeye/proc/optics()
	var/obj/item/organ/eyes/robotic/cyberware/deadeye/optics = owner?.get_organ_slot(ORGAN_SLOT_EYES)
	return istype(optics) ? optics : null

/datum/bounty_chrome_move/deadeye/can_start(atom/target)
	if(!..())
		return FALSE
	var/mob/living/mark = target
	if(!isliving(mark) || mark.stat != CONSCIOUS)
		return FALSE
	var/datum/bounty_style/style = bounty_ai_style(owner)
	if(!bounty_chrome_style_shoots(style?.key))
		return FALSE
	// One lock at a time: a tag still holding is the implant's to spend
	var/obj/item/organ/eyes/robotic/cyberware/deadeye/optics = optics()
	return !optics?.tagged_ref?.resolve()

/datum/bounty_chrome_move/deadeye/tell_text(atom/target)
	return "[owner]'s eyes flash red."

/datum/bounty_chrome_move/deadeye/tell(atom/target)
	..()
	if(QDELETED(owner) || QDELETED(target))
		return
	bounty_chrome_red_eyes(owner, REF(src), BOUNTY_DEADEYE_EYES_PRIORITY, TRUE, BOUNTY_DEADEYE_RED)
	add_mark(owner.Beam(target, icon_state = "r_beam", time = tell_time, maxdistance = BOUNTY_DEADEYE_RANGE + 1))

/datum/bounty_chrome_move/deadeye/effect(atom/target)
	. = ..()
	var/obj/item/organ/eyes/robotic/cyberware/deadeye/optics = optics()
	if(!. || QDELETED(target) || optics?.tagged_ref?.resolve() != target)
		eyes_off()
		return
	mark_ref = WEAKREF(target)
	deltimer(watch_timer)
	watch_timer = addtimer(CALLBACK(src, PROC_REF(watch)), BOUNTY_DEADEYE_WATCH, TIMER_STOPPABLE | TIMER_LOOP | TIMER_DELETE_ME)

/datum/bounty_chrome_move/deadeye/cancel(reason)
	eyes_off()

/datum/bounty_chrome_move/deadeye/on_fight_start(atom/target)
	deltimer(opening_timer)
	opening_timer = addtimer(CALLBACK(src, PROC_REF(open)), opening_delay(), TIMER_STOPPABLE | TIMER_DELETE_ME)

/datum/bounty_chrome_move/deadeye/on_fight_end()
	deltimer(opening_timer)
	opening_timer = null
	let_go()

/datum/bounty_chrome_move/deadeye/on_downed()
	deltimer(opening_timer)
	opening_timer = null
	let_go()

/datum/bounty_chrome_move/deadeye/on_death()
	stop()

/// How soon into a fight its first lock comes
/datum/bounty_chrome_move/deadeye/proc/opening_delay()
#ifdef BOUNTY_STYLE_SMG
	var/datum/bounty_style/style = bounty_ai_style(owner)
	if(style?.key == BOUNTY_STYLE_SMG)
		return BOUNTY_DEADEYE_OPENING_SMG
#endif
	return BOUNTY_DEADEYE_OPENING

/// The opening lock, early in the fight: its tell starts now if it can (the framework's opening gap is for the other moves)
/datum/bounty_chrome_move/deadeye/proc/open()
	opening_timer = null
	var/datum/component/bounty_chrome/chrome = owner?.GetComponent(/datum/component/bounty_chrome)
	if(!chrome?.fighting || chrome.telling)
		return
	var/atom/target = bounty_chrome_target(owner)
	if(can_start(target))
		chrome.start_move(src, target)

/// The held tag's look: it lets go when the mark is out of sight or down, or it can't shoot anyway; it stops looking once the implant has spent or dropped the tag
/datum/bounty_chrome_move/deadeye/proc/watch()
	var/mob/living/mark = mark_ref?.resolve()
	var/obj/item/organ/eyes/robotic/cyberware/deadeye/optics = optics()
	if(!mark || QDELETED(owner) || optics?.tagged_ref?.resolve() != mark)
		stop()
		return
	if(owner.stat != CONSCIOUS || mark.stat != CONSCIOUS || !bounty_ai_can_see(owner, mark, BOUNTY_DEADEYE_RANGE))
		let_go(lost = TRUE)

/// Lets go of its tag through the implant's own end_tag(), if it holds one. `lost`: the mark got away, and the optics chirp.
/datum/bounty_chrome_move/deadeye/proc/let_go(lost = FALSE)
	var/mob/living/mark = mark_ref?.resolve()
	var/obj/item/organ/eyes/robotic/cyberware/deadeye/optics = optics()
	if(mark && optics?.tagged_ref?.resolve() == mark)
		optics.end_tag(owner)
		if(lost && owner.stat == CONSCIOUS)
			playsound(owner, 'sound/machines/synth/synth_no.ogg', 30, TRUE)
	stop()

/// Stops watching a tag (whatever became of it) and its eyes go back to their own colour
/datum/bounty_chrome_move/deadeye/proc/stop()
	deltimer(watch_timer)
	watch_timer = null
	mark_ref = null
	eyes_off()

/datum/bounty_chrome_move/deadeye/proc/eyes_off()
	if(owner)
		bounty_chrome_red_eyes(owner, REF(src), BOUNTY_DEADEYE_EYES_PRIORITY, FALSE)

/**
 * Turns `npc`'s eyes `color` (on) or back (off) for `source`, at eye-colour `priority` (tg's own
 * add_eye_color(), as a cultist's go red), and gives examine its "eyes are glowing" line. A look only.
 * Each source keeps its own priority, so two of them never clear each other's. Redline uses it too.
 */
/proc/bounty_chrome_red_eyes(mob/living/carbon/human/npc, source, priority, on, color = BOUNTY_DEADEYE_RED)
	if(!ishuman(npc) || QDELETED(npc))
		return
	var/had = !isnull(LAZYACCESS(npc.eye_color_left_overrides, "[priority]"))
	if(on)
		ADD_TRAIT(npc, TRAIT_UNNATURAL_RED_GLOWY_EYES, source)
		if(!had)
			npc.add_eye_color(color, priority)
		return
	REMOVE_TRAIT(npc, TRAIT_UNNATURAL_RED_GLOWY_EYES, source)
	if(had)
		npc.remove_eye_color(priority)

#undef BOUNTY_DEADEYE_RANGE
#undef BOUNTY_DEADEYE_TELL
#undef BOUNTY_DEADEYE_OPENING
#undef BOUNTY_DEADEYE_OPENING_SMG
#undef BOUNTY_DEADEYE_WATCH
#undef BOUNTY_DEADEYE_RED
#undef BOUNTY_DEADEYE_EYES_PRIORITY

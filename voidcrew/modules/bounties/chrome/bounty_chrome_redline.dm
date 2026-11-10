/// Percent of its health at or under which it burns: the AI's moment (the implant fires whenever its bearer presses it)
#define BOUNTY_REDLINE_HURT_BELOW 75
/// Stamina lost at or over which it burns too: halfway to a stamina crit, so a baton or a disabler gets an answer before the floor
#define BOUNTY_REDLINE_WINDED_AT 50
/// The tell: the chest speaker charging before the roar
#define BOUNTY_REDLINE_TELL (1 SECONDS)
/// How far the implant's roar reaches (CYBERWARE_REDLINE_ROAR_RANGE, ware_legend.dm): the bystander gate looks this far
#define BOUNTY_REDLINE_ROAR_RANGE 5
/// The red of the tell's outline, its light and the eyes through the burn
#define BOUNTY_REDLINE_COLOR "#ff2a2a"
/// The eye-colour priority of the red eyes through the burn (over a cultist's)
#define BOUNTY_REDLINE_EYES_PRIORITY (EYE_COLOR_CULT_PRIORITY + 11)

/**
 * # Redline core on a bounty NPC
 *
 * The rage OS players buy (/obj/item/organ/cyberimp/cyberware/redline, ware_legend.dm), used the way a
 * player would: once a fight has turned on them. The AI picks the moment and shows it coming; everything
 * after the button press is the implant's own.
 *
 * - The moment: in a fight, hurt to BOUNTY_REDLINE_HURT_BELOW percent of its health or winded to
 *   BOUNTY_REDLINE_WINDED_AT stamina, and nobody outside the fight within the roar's reach (the bystander
 *   gate, owner decision 5): its own side and the site's people keep it shut.
 * - The tell, BOUNTY_REDLINE_TELL: it stands still, a red outline pulses over it, the chest speaker
 *   crackles and glows red, and it says so. A stun, a knockdown, cuffs, crit or an EMP in the tell and
 *   nothing happens (the framework).
 * - Then the implant's Redline Burn, Trigger()ed as a player's button: the roar (it staggers everyone in
 *   reach who isn't crew with the bearer, so the gate is checked again as it fires), 12 seconds of stun
 *   immunity, a red outline over it the whole time (the implant's, as on a player), 40% less brute and
 *   burn through its physiology, harder fists, 90 seconds of cooldown, then
 *   the crash: a hundred stamina, which floors it in stamina crit, and leaden legs. That collapse is the
 *   hunters' window. An EMP in the burn drops it straight into the crash, as it does a player.
 * - Its eyes stay red through the burn (the implant's own lines say they flood red and drain), a look only.
 */
/datum/bounty_chrome_move/redline
	piece_key = BOUNTY_CHROME_REDLINE
	name = "Redline burn"
	action_type = /datum/action/cooldown/cyberware/redline_burn
	tell_time = BOUNTY_REDLINE_TELL
	tell_color = BOUNTY_REDLINE_COLOR
	tell_lines = list("That's it.", "Now you've done it.", "You want to see red?")
	area_move = TRUE

// Hurt first: it is cheap, and the bystander gate's look around (view()) only runs once it would burn
/datum/bounty_chrome_move/redline/can_start(atom/target)
	return bounty_redline_hurt(owner) && ..()

/// Whether `npc` is hurt or winded enough to burn its Redline
/proc/bounty_redline_hurt(mob/living/npc)
	if(QDELETED(npc))
		return FALSE
	return npc.health <= npc.maxHealth * BOUNTY_REDLINE_HURT_BELOW / 100 || npc.getStaminaLoss() >= BOUNTY_REDLINE_WINDED_AT

// The implant's roar staggers only those outside its side (cyberware_is_ally()), so its own companions don't hold it back
/datum/bounty_chrome_move/redline/area_clear(atom/target)
	return bounty_chrome_area_clear(owner, area_turfs(target), target, TRUE)

/// The roar's reach: every tile it can see within BOUNTY_REDLINE_ROAR_RANGE, as the implant's roar looks (oview())
/datum/bounty_chrome_move/redline/area_turfs(atom/target)
	. = list()
	if(QDELETED(owner))
		return
	for(var/turf/spot in view(BOUNTY_REDLINE_ROAR_RANGE, owner))
		. += spot

/datum/bounty_chrome_move/redline/tell_text(atom/target)
	return "[owner]'s chest speaker crackles and starts to glow red."

/datum/bounty_chrome_move/redline/tell(atom/target)
	..()
	if(QDELETED(owner))
		return
	add_mark(owner.mob_light(1.5, 1, BOUNTY_REDLINE_COLOR))
	owner.Shake(1, 0, tell_time)

// Someone outside the fight stepped into the roar's reach during the tell: the button stays unpressed (the gate, owner decision 5)
/datum/bounty_chrome_move/redline/effect(atom/target)
	if(!area_clear(target))
		return FALSE
	. = ..()
	if(. && owner.has_status_effect(/datum/status_effect/cyberware_redline_window))
		owner.apply_status_effect(/datum/status_effect/bounty_redline_eyes)

/datum/bounty_chrome_move/redline/detach()
	owner?.remove_status_effect(/datum/status_effect/bounty_redline_eyes)
	return ..()

/**
 * Red eyes through a Redline burn on a bounty NPC: what the implant's roar and crash lines say happens
 * ("eyes flood red", "the red drains out of their eyes"). A look only; it ends with the burn.
 */
/datum/status_effect/bounty_redline_eyes
	id = "bounty_redline_eyes"
	// Past the implant's 12 second window; it ends with the window, this is a backstop
	duration = 15 SECONDS
	tick_interval = 0.5 SECONDS
	alert_type = null

/datum/status_effect/bounty_redline_eyes/on_apply()
	if(owner.stat == DEAD || !owner.has_status_effect(/datum/status_effect/cyberware_redline_window))
		return FALSE
	bounty_chrome_red_eyes(owner, id, BOUNTY_REDLINE_EYES_PRIORITY, TRUE, BOUNTY_REDLINE_COLOR)
	return TRUE

/datum/status_effect/bounty_redline_eyes/tick(seconds_between_ticks)
	if(owner.stat == DEAD || !owner.has_status_effect(/datum/status_effect/cyberware_redline_window))
		qdel(src)

/datum/status_effect/bounty_redline_eyes/on_remove()
	bounty_chrome_red_eyes(owner, id, BOUNTY_REDLINE_EYES_PRIORITY, FALSE)

#undef BOUNTY_REDLINE_HURT_BELOW
#undef BOUNTY_REDLINE_WINDED_AT
#undef BOUNTY_REDLINE_TELL
#undef BOUNTY_REDLINE_ROAR_RANGE
#undef BOUNTY_REDLINE_COLOR
#undef BOUNTY_REDLINE_EYES_PRIORITY

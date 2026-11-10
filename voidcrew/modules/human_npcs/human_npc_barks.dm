/**
 * # Human NPC barks (N3)
 *
 * What a human NPC says when something real happens to its body. Every hook hangs on a tg state change,
 * never on a stand-in state: entering crit (TRAIT_CRITICAL_CONDITION), leaving crit or getting up from
 * stamcrit, handcuffs going on and coming off (TRAIT_RESTRAINED), starting to work at its cuffs (tg's
 * cuff_resist(), COMSIG_MOB_REMOVING_CUFFS), breaking out of a grab or off someone's shoulders by
 * resisting, giving up (human_npc_surrender.dm) and dying.
 *
 * A family supplies its lines with a /datum/human_npc_voice subtype on the NPC's npc_voice. A voice has
 * spoken `lines` and third-person `emotes` ("collapses.") per kind (HUMAN_NPC_BARK_*, or any kind of the
 * family's own: npc_bark("alert") works the same). Speech goes through say() without `forced`, so a gag or
 * a mute works on an NPC as on a player, and tg whispers it in soft crit. In hard crit and after death it
 * can't speak, so only the emote shows. One NPC barks at most once per voice `cooldown`; surrender and
 * death always come through. A family that already has its own voice system (bounty criminals'
 * bounty_say()) overrides npc_bark() instead.
 *
 * Death also plays the hyperviolence death throes (HV-21, hv_death_throes(), a shudder as the body
 * falls). The deathgasp itself is tg's: carbons always give it.
 */

/// Says or shows its line for `kind` (HUMAN_NPC_BARK_*). `force` skips the cooldown and the voice's chance.
/// Returns TRUE if it said or did anything. Override to voice a family another way.
/mob/living/carbon/human/npc/proc/npc_bark(kind, force = FALSE)
	if(QDELETED(src) || !ispath(npc_voice, /datum/human_npc_voice))
		return FALSE
	var/datum/human_npc_voice/voice = human_npc_singleton(npc_voice)
	return voice.bark(src, kind, force)

/**
 * A family's lines. Lists are kind => list of strings. Emotes are third person without the name
 * ("collapses.", "groans and tries to get up."). Keep them short and in character (kit rules, "Writing
 * for players"): no mechanics, no hints.
 */
/datum/human_npc_voice
	/// Spoken lines by kind
	var/list/lines = list()
	/// Emotes by kind, shown before the line, and alone when it can't speak
	var/list/emotes = list()
	/// Percent chance it barks at all, by kind. A kind not listed always barks (cooldown allowing).
	var/list/chances = list()
	/// Seconds between two barks from one NPC
	var/cooldown = HUMAN_NPC_BARK_COOLDOWN

/// The spoken lines for `kind`. Pleading falls back to the downed lines.
/datum/human_npc_voice/proc/lines_for(kind)
	. = lines[kind]
	if(!length(.) && kind == HUMAN_NPC_BARK_PLEAD)
		. = lines[HUMAN_NPC_BARK_DOWNED]

/// The emotes for `kind`.
/datum/human_npc_voice/proc/emotes_for(kind)
	return emotes[kind]

/datum/human_npc_voice/proc/bark(mob/living/carbon/human/npc/speaker, kind, force = FALSE)
	if(!force && !COOLDOWN_FINISHED(speaker, npc_bark_cooldown))
		return FALSE
	if(!force && (kind in chances) && !prob(chances[kind]))
		return FALSE
	var/list/acts = emotes_for(kind)
	var/list/spoken = lines_for(kind)
	var/can_talk = length(spoken) && human_npc_can_talk(speaker)
	if(!length(acts) && !can_talk)
		return FALSE
	if(length(acts))
		speaker.visible_message(span_emote("<b>[speaker]</b> [pick(acts)]"))
	if(can_talk)
		INVOKE_ASYNC(speaker, TYPE_PROC_REF(/atom/movable, say), pick(spoken))
	speaker.npc_last_bark = kind
	COOLDOWN_START(speaker, npc_bark_cooldown, cooldown)
	return TRUE

/// Whether `speaker` can speak out loud or whisper now. Never in hard crit: tg turns that into last words.
/proc/human_npc_can_talk(mob/living/speaker)
	if(speaker.stat != CONSCIOUS && speaker.stat != SOFT_CRIT)
		return FALSE
	return speaker.can_speak()

/**
 * Relays the tg state changes the barks hang on to the NPC's own procs, so a family can override what
 * happens (npc_on_downed() and so on) without touching the signals. An element, so a subtype can listen
 * to the same signals on itself.
 */
/datum/element/human_npc_reactions
	element_flags = ELEMENT_DETACH_ON_HOST_DESTROY

/datum/element/human_npc_reactions/Attach(datum/target)
	. = ..()
	if(!ishumannpc(target))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, SIGNAL_ADDTRAIT(TRAIT_CRITICAL_CONDITION), PROC_REF(on_crit_started))
	RegisterSignal(target, SIGNAL_REMOVETRAIT(TRAIT_CRITICAL_CONDITION), PROC_REF(on_crit_ended))
	RegisterSignal(target, COMSIG_LIVING_STATUS_REMOVED, PROC_REF(on_status_removed))
	RegisterSignal(target, SIGNAL_ADDTRAIT(TRAIT_RESTRAINED), PROC_REF(on_restrained))
	RegisterSignal(target, SIGNAL_REMOVETRAIT(TRAIT_RESTRAINED), PROC_REF(on_unrestrained))
	RegisterSignal(target, COMSIG_MOB_REMOVING_CUFFS, PROC_REF(on_working_cuffs))
	RegisterSignal(target, COMSIG_LIVING_RESIST, PROC_REF(on_resist))
	RegisterSignal(target, COMSIG_ATOM_NO_LONGER_PULLED, PROC_REF(on_let_go))
	RegisterSignal(target, COMSIG_LIVING_SET_BUCKLED, PROC_REF(on_buckled))
	RegisterSignal(target, COMSIG_LIVING_DEATH, PROC_REF(on_death))

/datum/element/human_npc_reactions/Detach(datum/source)
	UnregisterSignal(source, list(
		SIGNAL_ADDTRAIT(TRAIT_CRITICAL_CONDITION),
		SIGNAL_REMOVETRAIT(TRAIT_CRITICAL_CONDITION),
		COMSIG_LIVING_STATUS_REMOVED,
		SIGNAL_ADDTRAIT(TRAIT_RESTRAINED),
		SIGNAL_REMOVETRAIT(TRAIT_RESTRAINED),
		COMSIG_MOB_REMOVING_CUFFS,
		COMSIG_LIVING_RESIST,
		COMSIG_ATOM_NO_LONGER_PULLED,
		COMSIG_LIVING_SET_BUCKLED,
		COMSIG_LIVING_DEATH,
	))
	return ..()

/datum/element/human_npc_reactions/proc/on_crit_started(mob/living/carbon/human/npc/source)
	SIGNAL_HANDLER
	if(source.stat != DEAD)
		source.npc_on_downed()

/datum/element/human_npc_reactions/proc/on_crit_ended(mob/living/carbon/human/npc/source)
	SIGNAL_HANDLER
	// tg drops the trait on death too; only a living body that came out of crit has recovered.
	if(source.stat != DEAD && !QDELING(source))
		source.npc_on_recovered()

/datum/element/human_npc_reactions/proc/on_status_removed(mob/living/carbon/human/npc/source, datum/status_effect/effect)
	SIGNAL_HANDLER
	if(source.stat == DEAD || QDELING(source))
		return
	if(istype(effect, /datum/status_effect/incapacitating/stamcrit))
		if(source.stat == CONSCIOUS)
			source.npc_on_recovered()
		return
	if(istype(effect, /datum/status_effect/incapacitating/paralyzed) && source.npc_surrendering)
		source.npc_surrender_ended()

/datum/element/human_npc_reactions/proc/on_restrained(mob/living/carbon/human/npc/source)
	SIGNAL_HANDLER
	if(source.handcuffed && source.stat != DEAD)
		source.npc_bark(HUMAN_NPC_BARK_CUFFED)

/datum/element/human_npc_reactions/proc/on_unrestrained(mob/living/carbon/human/npc/source)
	SIGNAL_HANDLER
	if(source.stat != DEAD && !QDELING(source))
		source.npc_bark(HUMAN_NPC_BARK_UNCUFFED)

/datum/element/human_npc_reactions/proc/on_working_cuffs(mob/living/carbon/human/npc/source, obj/item/cuffs)
	SIGNAL_HANDLER
	source.npc_bark(HUMAN_NPC_BARK_SLIPPING)

/// Notes who held it as it resisted. tg's resist_grab() lets go in the same call when it works.
/datum/element/human_npc_reactions/proc/on_resist(mob/living/carbon/human/npc/source)
	SIGNAL_HANDLER
	var/atom/movable/holder = source.pulledby || (ismob(source.buckled) ? source.buckled : null)
	if(isnull(holder) || HAS_TRAIT(source, TRAIT_RESTRAINED))
		return
	source.npc_resisted_hold = WEAKREF(holder)
	source.npc_resisted_at = world.time

/datum/element/human_npc_reactions/proc/on_let_go(mob/living/carbon/human/npc/source, atom/movable/puller)
	SIGNAL_HANDLER
	source.npc_check_pulled_free(puller)

/datum/element/human_npc_reactions/proc/on_buckled(mob/living/carbon/human/npc/source, atom/movable/new_buckled)
	SIGNAL_HANDLER
	// Squirming off a carrier's shoulders can take a moment; a grab breaks in the same call.
	if(isnull(new_buckled))
		source.npc_check_pulled_free(within = 6 SECONDS)

/datum/element/human_npc_reactions/proc/on_death(mob/living/carbon/human/npc/source, gibbed)
	SIGNAL_HANDLER
	source.npc_surrendering = FALSE
	if(gibbed)
		return
	source.hv_death_throes()
	source.npc_bark(HUMAN_NPC_BARK_DEATH, force = TRUE)

// ===== What it does when those things happen. Families override these. =====

/// It entered crit.
/mob/living/carbon/human/npc/proc/npc_on_downed()
	npc_surrendering = FALSE
	npc_bark(HUMAN_NPC_BARK_DOWNED, force = TRUE)
	npc_next_plead = world.time + HUMAN_NPC_PLEAD_INTERVAL
	SEND_SIGNAL(src, COMSIG_HUMAN_NPC_DOWNED)

/// It left crit, or got up from stamcrit.
/mob/living/carbon/human/npc/proc/npc_on_recovered()
	npc_bark(HUMAN_NPC_BARK_RECOVER)
	SEND_SIGNAL(src, COMSIG_HUMAN_NPC_RECOVERED)

/// It stopped being held. If it resisted its way out (this tick, or `within` that long ago), it pulled free.
/mob/living/carbon/human/npc/proc/npc_check_pulled_free(atom/movable/holder, within = 0)
	if(!npc_resisted_at || world.time > npc_resisted_at + within)
		return
	var/atom/movable/resisted = npc_resisted_hold?.resolve()
	npc_resisted_hold = null
	npc_resisted_at = 0
	if(holder && resisted != holder)
		return
	npc_bark(HUMAN_NPC_BARK_PULLED_FREE)

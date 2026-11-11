/**
 * # Outpost recovery: the trader stick-up
 *
 * Owner: R7 (spec-rehydrate.md section 10, M37, M38, M40). tg's own right-click hold-up
 * (/datum/component/gunpoint) on a trader at its counter: hands up, the till (or one cheap shelf item) handed
 * over when the hold steadies, and the alarm (OUTPOST_CRIME_ARMED_ROBBERY) when the robber leaves its sight,
 * 30 s after the hand-over, or the moment the robber fires or hits anyone. Takings count against the outpost's
 * shared loss cap (recovery.loss_room(), note_loss()). The gate emag (section 9) is R7's too, in
 * trade/outpost_checkpoint.dm.
 *
 * The trader's three procs are frozen one-line forwarders: R1's path rename changes their declaration lines and
 * R7 never edits them, so the two merge cleanly. R7's logic lives on the shop (the till is the shop's anyway) and
 * in outpost_holdup_hook(), below the forwarders.
 *
 * Frozen by R0: the vars and the proc names and signatures below. Behaviour at R0: none (nobody is ever robbed).
 */

/datum/outpost_shop
	/// world.time the till pays again; 0 = it is full (R7). On the shop, not the person: a replacement keeper
	/// has the same empty till (SU9).
	var/till_ready_at = 0
	/// Weakref to the mind that emptied the till last, or null (R7). A keeper robbed since the last convoy drops
	/// nothing when killed (R1 reads it in drop_from_shelf(), M37).
	var/datum/weakref/till_robbed_by

// =========================================================================
// THE TRADER'S SIDE: frozen forwarders (R0). R1 renames the path on these lines; R7 never edits them.
// =========================================================================

/// Called once from the trader's Initialize (trade/trader_npc.dm): registers what the stick-up listens to
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/hook_holdup()
	outpost_holdup_hook(src)

/// `robber` holds this trader up with `weapon` (the hold has just started)
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/on_held_up(mob/living/robber, obj/item/gun/weapon)
	shop?.held_up(src, robber, weapon)

/// The trader reports the robbery from its counter (OUTPOST_CRIME_ARMED_ROBBERY, the gun as source)
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/raise_alarm()
	shop?.raise_holdup_alarm(src)

// =========================================================================
// THE STICK-UP (R7)
// =========================================================================

/**
 * `trader` was just made: register what tells it it is held up (tg's /datum/status_effect/grouped/heldup lands on
 * it; COMSIG_LIVING_STATUS_APPLIED) and call trader.on_held_up() from there. A signal handler needs a datum to live
 * on: use the shop, or a small datum of R7's own. Runs from Initialize: never sleeps.
 */
/proc/outpost_holdup_hook(mob/living/trader)
	return

/// `trader`, keeping this shop, is held up by `robber` with `weapon`: hands up, then the hand-over when the hold steadies
/datum/outpost_shop/proc/held_up(mob/living/trader, mob/living/robber, obj/item/gun/weapon)
	return

/// `trader` reports the robbery of this shop: OUTPOST_CRIME_ARMED_ROBBERY against the robber, the gun as source
/datum/outpost_shop/proc/raise_holdup_alarm(mob/living/trader)
	return

/**
 * Voidcrew: dynamic never assigns an antagonist. Not at roundstart, not midround,
 * not on latejoin.
 *
 * All three of dynamic's selection entry points are replaced with hard refusals, so
 * no player is ever handed a traitor, changeling, heretic, cult, nukeop or wizard role
 * by the game. The threats in this fork come from the world instead - pirates, boarding
 * raids, hostile NPC ships, the lich, ruin mobs - not from the person next to you.
 *
 * These are deliberate full replacements with no ..() call, following the precedent in
 * voidcrew/edits/subsystem/job.dm. That matters here: /datum/controller/subsystem/dynamic
 * declares all three procs itself, so a redefinition on the same type discards the upstream
 * body rather than wrapping it, and any ..() would look for a parent version that does not
 * exist. Every caller already handles the empty/FALSE result as "nothing was selected" and
 * carries on - select_roundstart_antagonists() adds an empty list to its queue and its
 * following loop finds nothing, fire() falls through, and on_latejoin() returns after
 * having already drained any queued rulesets.
 *
 * Doing this in code rather than by zeroing config/dynamic.toml alone is load-bearing, not
 * belt and braces. load_config() early-returns when dynamic_config_enabled is off, and the
 * tier datums in _dynamic_tier.dm carry nonzero budgets as their code defaults - so a server
 * running without dynamic config would start spawning antagonists again. The toml is zeroed
 * to match anyway, so the admin panel and the roundstart telemetry report the same 0 that
 * actually happens.
 *
 * The Antagonists page was dropped from character setup (AntagsPage.tsx is no longer
 * mounted). Antagonist preferences default to all roles, including for existing accounts,
 * so ghost-role polls such as alien larvae can find volunteers. These selection gates
 * keep automatic antagonist assignment disabled regardless of those preferences.
 *
 * Tier selection is deliberately left running. It now only supplies the flavour text for
 * the roundstart threat advisory, and forcing Greenshift instead would trip the
 * `greenshift ? INFINITY : ...` branch in send_roundstart_report() and generate every
 * station goal in the game, every round.
 *
 * Admin tooling is left working on purpose. force_run_midround() is untouched - it backs the
 * comms console's pirate, fugitive and sleeper-agent calls as well as admin-forced rulesets,
 * and never routed through any of these procs. Rulesets an admin queues by hand also still
 * run: select_roundstart_antagonists() only calls pick_roundstart_rulesets() when the queue
 * is empty, and on_latejoin() drains its queue before reaching the block below.
 */
/datum/controller/subsystem/dynamic/pick_roundstart_rulesets(list/antag_candidates)
	return list()

/datum/controller/subsystem/dynamic/try_spawn_midround(range)
	return FALSE

/datum/controller/subsystem/dynamic/try_spawn_latejoin(mob/living/carbon/human/latejoiner)
	return FALSE

/**
 * The one automatic source that could hand dynamic its midround and latejoin budget back:
 * a hidden event that tops the counts up mid-shift. The procs above ignore the counts, so
 * this is genuinely just tidiness - but leaving a live event whose entire purpose is
 * "spawn more midrounds" is misleading to read. SSevents is already inert in this fork
 * (allow_random_events is FALSE, since scheduling moved to SSdynamic_events); weight 0
 * drops it out of pick_weight() while leaving it triggerable from the admin event panel.
 */
/datum/round_event_control/dynamic_tweak
	weight = 0

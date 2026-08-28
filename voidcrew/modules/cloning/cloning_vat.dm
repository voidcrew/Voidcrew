/**
 * # Vat cloning (Voidcrew)
 *
 * Phoenix-project style pre-paid respawns. A LIVING crewmember imprints their
 * genetic pattern onto a vat; the vat then slowly grows a mindless spare body.
 * If the imprinted player dies while a fully-grown clone exists, their ghost is
 * prompted and may click the vat to wake up in the clone (with a wake-up debuff,
 * naked, their old corpse left where it fell). The vat then regrows from scratch.
 * Multiple vats can each hold one imprint, so several vats = several stored lives.
 *
 * Rules:
 * * Imprinting requires the living, conscious original at the vat. No cloning corpses.
 * * The imprint binds to the MIND datum, so it keeps working if the mind changes bodies.
 * * No claiming while the imprinted mind's current body is still alive.
 * * Suicided/DNR'd ghosts may still claim - dead is dead, this is what you pre-paid for.
 * * The imprint expires if the mind is deleted, or if the player has moved on to
 *   playing a different (living) character.
 * * Re-imprinting a vat (by anyone) discards the old imprint and restarts growth.
 * * Growth only advances while the vat is anchored and powered; while it isn't,
 *   progress slowly decays, and a ready clone can decay back to "not ready".
 * * Deconstructing or destroying a vat with a part-grown clone leaves a mess.
 *
 * SPRITES: voidcrew/icons/obj/machines/cloning_vat.dmi is copied from /tg/station's
 * icons/obj/machines/cloning.dmi (github.com/tgstation/tgstation, sprites re-added in
 * PR #90754 "Readds Cloning"; also present in this repo at icons/obj/machines/cloning.dmi).
 * SS13 sprites are licensed CC-BY-SA 3.0. The "pod_ready" icon state is a Voidcrew
 * recolor of "pod_1".
 */

/// How long a clone takes to grow with tier-1 parts.
#define CLONING_VAT_GROWTH_TIME (12 MINUTES)
/// While unpowered/broken/unanchored, progress decays at this multiple of the growth rate.
#define CLONING_VAT_DECAY_MULT 0.5
/// A grown clone stays viable until decay drops it below this fraction of growth_time. Gives
/// brownouts a grace band, so a flickering powernet can't spam the "clone is ready" chime.
#define CLONING_VAT_READY_BAND 0.95
/// Fraction of growth above which deconstruction/destruction leaves a mess.
#define CLONING_VAT_MESS_THRESHOLD 0.25

/obj/machinery/cloning_vat
	name = "cloning vat"
	desc = "A tank of murky nutrient fluid that slowly grows a spare body from an imprinted genetic pattern. \
		The pattern has to be taken from someone who's still alive, so you need to plan ahead."
	icon = 'voidcrew/icons/obj/machines/cloning_vat.dmi'
	icon_state = "pod_0"
	base_icon_state = "pod"
	density = TRUE
	circuit = /obj/item/circuitboard/machine/cloning_vat
	interaction_flags_atom = parent_type::interaction_flags_atom | INTERACT_ATOM_REQUIRES_ANCHORED
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION * 2
	active_power_usage = BASE_MACHINE_ACTIVE_CONSUMPTION * 2

	/// Weakref to the mind this vat is imprinted with. Null when no imprint.
	var/datum/weakref/imprint_mind_ref
	/// Real name of the imprinted character at imprint time.
	var/imprint_name
	/// Age of the imprinted character at imprint time. Purely cosmetic.
	var/imprint_age = 30
	/// Holderless DNA snapshot taken at imprint time.
	var/datum/dna/imprint_dna
	/// Accumulated growth, in deciseconds of powered growth.
	var/growth_progress = 0
	/// Total growth needed. Lowered slightly by better matter bins.
	var/growth_time = CLONING_VAT_GROWTH_TIME
	/// TRUE once the clone is fully grown and claimable.
	var/body_ready = FALSE
	/// Whether we have successfully delivered a "your clone is ready" prompt for the holder's current death.
	var/death_notified = FALSE
	/// Whether we have already announced this clone finishing growth. Cleared once the clone
	/// decays out of the ready band, so only a real outage earns a second announcement.
	var/completion_announced = FALSE

/obj/machinery/cloning_vat/Initialize(mapload)
	. = ..()
	register_context()

/obj/machinery/cloning_vat/Destroy()
	QDEL_NULL(imprint_dna)
	imprint_mind_ref = null
	return ..()

/obj/machinery/cloning_vat/RefreshParts()
	. = ..()
	var/bin_tiers = 0
	var/bin_count = 0
	for(var/datum/stock_part/matter_bin/bin in component_parts)
		bin_tiers += bin.tier
		bin_count++
	// 5% faster growth per matter bin tier above stock, capped at 30%.
	var/bonus_tiers = bin_count ? clamp(bin_tiers - bin_count, 0, 6) : 0
	growth_time = CLONING_VAT_GROWTH_TIME * (1 - bonus_tiers * 0.05)

/obj/machinery/cloning_vat/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(isnull(held_item))
		if(isliving(user))
			context[SCREENTIP_CONTEXT_LMB] = "Imprint your pattern"
			return CONTEXTUAL_SCREENTIP_SET
		if(isobserver(user))
			context[SCREENTIP_CONTEXT_LMB] = "Claim your clone"
			return CONTEXTUAL_SCREENTIP_SET
		return NONE
	switch(held_item.tool_behaviour)
		if(TOOL_SCREWDRIVER)
			context[SCREENTIP_CONTEXT_LMB] = "[panel_open ? "Close" : "Open"] panel"
			return CONTEXTUAL_SCREENTIP_SET
		if(TOOL_WRENCH)
			context[SCREENTIP_CONTEXT_LMB] = "[anchored ? "Unan" : "An"]chor"
			return CONTEXTUAL_SCREENTIP_SET
		if(TOOL_CROWBAR)
			if(panel_open)
				context[SCREENTIP_CONTEXT_LMB] = "Deconstruct"
				return CONTEXTUAL_SCREENTIP_SET
	return NONE

/obj/machinery/cloning_vat/examine(mob/user)
	. = ..()
	if(isnull(imprint_mind_ref))
		. += span_notice("It has no genetic pattern imprinted. A living crewmember can press their hand to the scanner to imprint themselves.")
		return
	. += span_notice("It is imprinted with the genetic pattern of <b>[imprint_name]</b>. Re-imprinting it will discard that pattern.")
	if(body_ready)
		. += span_boldnotice("The clone inside is fully grown. If [imprint_name] dies, their ghost can click the vat to wake up in it.")
	else
		. += span_notice("The clone inside is [get_growth_percent()]% grown.")
	if(!is_operational || !anchored)
		. += span_warning("Its nutrient systems are offline - the clone is slowly dissolving!")

/obj/machinery/cloning_vat/update_icon_state()
	. = ..()
	if(isnull(imprint_mind_ref) || growth_progress <= 0)
		icon_state = "[base_icon_state]_0"
	else if(body_ready)
		icon_state = "[base_icon_state]_ready"
	else
		icon_state = "[base_icon_state]_1"

/// Current growth as a rounded percentage.
/obj/machinery/cloning_vat/proc/get_growth_percent()
	return round(growth_progress / growth_time * 100)

/// Resolves the imprinted mind, expiring the imprint if it is gone or the player
/// has moved on to a different character. Returns the mind or null.
/obj/machinery/cloning_vat/proc/validate_imprint()
	if(isnull(imprint_mind_ref))
		return null
	var/datum/mind/mind = imprint_mind_ref.resolve()
	if(isnull(mind))
		expire_imprint("The stored pattern has degraded into noise.")
		return null
	// If the player behind this mind is off being someone else (alive), the imprint is stale.
	var/client/holder_client = GLOB.directory[ckey(mind.key)]
	if(holder_client && isliving(holder_client.mob))
		var/mob/living/live_mob = holder_client.mob
		if(live_mob.stat != DEAD && live_mob.mind && live_mob.mind != mind)
			expire_imprint("The stored pattern no longer matches a living neural signature, and is purged.")
			return null
	return mind

/// Wipes the imprint entirely, with a visible message explaining why.
/obj/machinery/cloning_vat/proc/expire_imprint(reason)
	if(reason)
		visible_message(span_warning("[src] chimes sadly. [reason]"))
	wipe_imprint()

/// Clears all imprint state and dissolves any grown progress.
/obj/machinery/cloning_vat/proc/wipe_imprint()
	imprint_mind_ref = null
	imprint_name = null
	imprint_age = 30
	QDEL_NULL(imprint_dna)
	growth_progress = 0
	body_ready = FALSE
	death_notified = FALSE
	completion_announced = FALSE
	if(use_power != IDLE_POWER_USE)
		update_use_power(IDLE_POWER_USE)
	update_appearance(UPDATE_ICON_STATE)

/obj/machinery/cloning_vat/process(seconds_per_tick)
	if(isnull(imprint_mind_ref))
		return
	var/datum/mind/mind = validate_imprint()
	if(isnull(mind))
		return

	// Life support offline: progress slowly decays.
	if(!is_operational || !anchored)
		if(growth_progress <= 0)
			return
		growth_progress = max(0, growth_progress - seconds_per_tick * 10 * CLONING_VAT_DECAY_MULT)
		// A grown clone rides out short outages. Only once decay eats into the ready band is it
		// actually spoiled, so a browning-out powernet doesn't cycle ready/not-ready every tick.
		if(growth_progress < growth_time * CLONING_VAT_READY_BAND)
			completion_announced = FALSE
			if(body_ready)
				body_ready = FALSE
				visible_message(span_warning("The clone in [src] twitches as the nutrient feed cuts out."))
				update_appearance(UPDATE_ICON_STATE)
		if(growth_progress <= 0)
			visible_message(span_warning("The half-formed clone in [src] dissolves into the fluid."))
			update_appearance(UPDATE_ICON_STATE)
		return

	if(body_ready)
		// Top back up whatever a brief outage nibbled off; the clone is viable either way.
		growth_progress = growth_time
		if(use_power != IDLE_POWER_USE)
			update_use_power(IDLE_POWER_USE)
		check_death_notify(mind)
		return

	// Growing.
	if(use_power != ACTIVE_POWER_USE)
		update_use_power(ACTIVE_POWER_USE)
	var/was_zero = growth_progress <= 0
	growth_progress = min(growth_time, growth_progress + seconds_per_tick * 10)
	if(was_zero)
		update_appearance(UPDATE_ICON_STATE)
	if(growth_progress >= growth_time)
		finish_growth()

/// The clone has finished growing.
/obj/machinery/cloning_vat/proc/finish_growth()
	body_ready = TRUE
	// Announce (and re-arm the death prompt) only for a clone that genuinely regrew, never for
	// one that just topped back off after a power flicker.
	if(!completion_announced)
		completion_announced = TRUE
		death_notified = FALSE
		playsound(src, 'sound/machines/ping.ogg', vol = 40, vary = TRUE)
		visible_message(span_notice("[src] chimes; the clone inside has finished growing."))
	update_use_power(IDLE_POWER_USE)
	update_appearance(UPDATE_ICON_STATE)

/// If the imprinted player is dead and hasn't been prompted for this death yet, prompt them.
/obj/machinery/cloning_vat/proc/check_death_notify(datum/mind/mind)
	var/mob/living/current_body = mind.current
	if(current_body && current_body.stat != DEAD)
		death_notified = FALSE // Alive again - re-arm the prompt for their next death.
		return
	if(death_notified)
		return
	// Find whoever is holding the player right now: their ghost, or their corpse if still in it.
	var/mob/target = mind.get_ghost(even_if_they_cant_reenter = TRUE, ghosts_with_clients = TRUE)
	if(isnull(target) && current_body?.client)
		target = current_body
	if(isnull(target)) // Player is logged out; keep trying until they return.
		return
	death_notified = TRUE
	to_chat(target, span_ghostalert("A clone of you is ready in [get_area_name(src, format_text = TRUE)]. [isobserver(target) ? "Click the vat (or the alert) to be reborn." : "Ghost, then click the vat to be reborn."]"))
	SEND_SOUND(target, sound('sound/machines/chime.ogg', volume = 50))
	window_flash(target.client)
	if(!isobserver(target))
		return
	var/mob/dead/observer/ghost = target
	var/mutable_appearance/alert_overlay = get_small_overlay(src)
	alert_overlay.appearance_flags |= TILE_BOUND
	alert_overlay.layer = FLOAT_LAYER
	alert_overlay.plane = FLOAT_PLANE
	var/atom/movable/screen/alert/notify_action/toast = ghost.throw_alert(
		category = "[REF(src)]_vat_clone_ready",
		type = /atom/movable/screen/alert/notify_action,
	)
	toast.add_overlay(alert_overlay)
	toast.name = "Clone Ready"
	toast.desc = "A clone of you is fully grown. Click to claim it."
	toast.click_interact = TRUE
	toast.target_ref = WEAKREF(src)

// ---------------------------------------------------------------------------
// Imprinting (living players)
// ---------------------------------------------------------------------------

/obj/machinery/cloning_vat/interact(mob/user)
	if(!isliving(user))
		return
	try_imprint(user)

/// A living mob wants to imprint themselves onto the vat.
/obj/machinery/cloning_vat/proc/try_imprint(mob/living/user)
	if(!ishuman(user))
		balloon_alert(user, "incompatible lifeform!")
		return
	if(IS_UNCONSCIOUS_OR_CRIT(user))
		return
	if(isnull(user.mind) || isnull(user.client))
		balloon_alert(user, "no neural signature!")
		return
	if(!user.has_dna() || HAS_TRAIT(user, TRAIT_GENELESS) || HAS_TRAIT(user, TRAIT_BADDNA))
		balloon_alert(user, "unreadable genetic pattern!")
		return

	var/datum/mind/existing = imprint_mind_ref?.resolve()
	var/prompt
	if(existing == user.mind)
		if(body_ready || growth_progress > 0)
			prompt = "Refresh your imprint? The current clone will dissolve and growth will restart from nothing."
		else
			prompt = "Refresh your imprint with your current appearance?"
	else if(existing)
		prompt = "The vat holds the pattern of [imprint_name]. Overwrite it with your own[growth_progress > 0 ? ", dissolving the clone inside" : ""]?"
	else
		prompt = "Imprint your genetic pattern? The vat will start growing a mindless spare body for you to wake up in if you die."

	if(tgui_alert(user, prompt, name, list("Imprint", "Cancel")) != "Imprint")
		return
	// Revalidate after the blocking prompt.
	if(QDELETED(src) || QDELETED(user) || IS_UNCONSCIOUS_OR_CRIT(user) || isnull(user.mind) || !user.can_perform_action(src))
		return
	do_imprint(user)

/// Actually stores the imprint and starts growth.
/obj/machinery/cloning_vat/proc/do_imprint(mob/living/carbon/human/user)
	var/had_clone = growth_progress > 0
	wipe_imprint()
	imprint_mind_ref = WEAKREF(user.mind)
	imprint_name = user.real_name
	imprint_age = user.age
	imprint_dna = new
	user.dna.copy_dna(imprint_dna)
	update_use_power(ACTIVE_POWER_USE)
	update_appearance(UPDATE_ICON_STATE)
	user.log_message("imprinted their genetic pattern onto [src].", LOG_GAME)
	playsound(src, 'sound/machines/chime.ogg', vol = 40, vary = TRUE)
	if(had_clone)
		visible_message(span_warning("The old clone in [src] dissolves as a new pattern is imprinted."))
	balloon_alert(user, "pattern imprinted")
	to_chat(user, span_notice("[src] hums to life and starts growing a new body. It'll take about [DisplayTimeText(growth_time)], and just as long to regrow after every use."))

// ---------------------------------------------------------------------------
// Claiming (ghosts)
// ---------------------------------------------------------------------------

/obj/machinery/cloning_vat/attack_ghost(mob/dead/observer/user)
	var/datum/mind/mind = imprint_mind_ref?.resolve()
	if(mind && user.mind == mind)
		try_claim(user, mind)
		return TRUE
	return ..()

/// The imprinted player's ghost wants to wake up in the clone.
/obj/machinery/cloning_vat/proc/try_claim(mob/dead/observer/user, datum/mind/mind)
	if(!body_ready)
		if(growth_progress > 0)
			balloon_alert(user, "clone only [get_growth_percent()]% grown!")
		else
			balloon_alert(user, "no clone grown!")
		return
	if(!is_operational || !anchored)
		balloon_alert(user, "vat is offline!")
		return
	var/mob/living/current_body = mind.current
	if(current_body && current_body.stat != DEAD)
		balloon_alert(user, "you are still alive!")
		return
	if(tgui_alert(user, "Wake up in your clone? Your old body and everything on it stays where it is.", name, list("Wake Up", "Not Yet")) != "Wake Up")
		return
	// Revalidate after the blocking prompt.
	if(QDELETED(src) || QDELETED(user) || !body_ready || !is_operational || !anchored)
		return
	if(user.mind != mind || imprint_mind_ref?.resolve() != mind)
		return
	current_body = mind.current
	if(current_body && current_body.stat != DEAD)
		balloon_alert(user, "you are still alive!")
		return
	claim(user, mind)

/// Decants the clone and moves the player into it.
/obj/machinery/cloning_vat/proc/claim(mob/dead/observer/user, datum/mind/mind)
	var/mob/living/carbon/human/clone = create_clone_body()
	mind.transfer_to(clone, force_key_move = TRUE)
	clone.forceMove(drop_location())
	playsound(src, 'sound/effects/splash.ogg', vol = 60, vary = TRUE)
	visible_message(span_warning("[src] flushes open and disgorges [clone] in a wave of nutrient fluid!"))

	// Wake-up debuff: rough, but survivable without help.
	clone.Paralyze(4 SECONDS)
	clone.adjust_oxy_loss(40)
	clone.adjust_tox_loss(15)
	clone.adjust_confusion(20 SECONDS)
	clone.adjust_dizzy(30 SECONDS)
	clone.adjust_eye_blur(20 SECONDS)
	clone.emote("gasp")
	to_chat(clone, span_boldnotice("You wake up in a brand-new body, gasping and retching as the vat's fluid drains out of your lungs."))
	to_chat(clone, span_notice("Everything you were carrying is still on your old corpse."))
	clone.log_message("was reborn from a cloning vat imprint.", LOG_GAME)

	// Back to square one - the vat has to regrow before it can be used again.
	growth_progress = 0
	body_ready = FALSE
	death_notified = FALSE
	completion_announced = FALSE
	update_use_power(ACTIVE_POWER_USE)
	update_appearance(UPDATE_ICON_STATE)

/// Builds the fresh body from the stored imprint. Holds no mind until transfer.
/obj/machinery/cloning_vat/proc/create_clone_body()
	var/mob/living/carbon/human/clone = new(src)
	// No mutation blocks are passed: vat clones come out with a clean genome.
	clone.hardset_dna(
		unique_identity = imprint_dna.unique_identity,
		newreal_name = imprint_name,
		newblood_type = imprint_dna.blood_type,
		mrace = imprint_dna.species,
		newfeatures = imprint_dna.features.Copy(),
	)
	clone.fully_replace_character_name(clone.real_name, imprint_name)
	clone.age = imprint_age
	clone.underwear = "Nude"
	clone.undershirt = "Nude"
	clone.socks = "Nude"
	clone.update_body(is_creating = TRUE)
	return clone

// ---------------------------------------------------------------------------
// Construction / destruction
// ---------------------------------------------------------------------------

/obj/machinery/cloning_vat/wrench_act(mob/living/user, obj/item/tool)
	. = ..()
	if(default_unfasten_wrench(user, tool))
		return ITEM_INTERACT_SUCCESS

/obj/machinery/cloning_vat/screwdriver_act(mob/living/user, obj/item/tool)
	. = ..()
	return default_deconstruction_screwdriver(user, tool)

/obj/machinery/cloning_vat/crowbar_act(mob/living/user, obj/item/tool)
	. = ..()
	return default_deconstruction_crowbar(user, tool)

/obj/machinery/cloning_vat/on_deconstruction(disassembled)
	if(growth_progress >= growth_time * CLONING_VAT_MESS_THRESHOLD)
		new /obj/effect/gibspawner/human(drop_location())

// ---------------------------------------------------------------------------
// Board, design, research
// ---------------------------------------------------------------------------

/obj/item/circuitboard/machine/cloning_vat
	name = "Cloning Vat"
	greyscale_colors = CIRCUIT_COLOR_MEDICAL
	build_path = /obj/machinery/cloning_vat
	req_components = list(
		/datum/stock_part/matter_bin = 2,
		/datum/stock_part/servo = 1,
		/obj/item/stack/cable_coil = 2,
		/obj/item/stack/sheet/glass = 4,
	)

/datum/design/board/cloning_vat
	name = "Machine Design (Cloning Vat)"
	desc = "The circuit board for a cloning vat, which grows a pre-imprinted spare body over time."
	build_path = /obj/item/circuitboard/machine/cloning_vat
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_MEDICAL
	)
	departmental_flags = DEPARTMENT_BITFLAG_MEDICAL

/datum/techweb_node/vat_cloning
	display_name = "Vat Cloning"
	description = "Grows a mindless spare body from a genetic imprint, ready to wake up in when you die. The imprint has to be taken while you're still alive."
	prerequisite_nodes = list(/datum/techweb_node/medbay_equip_adv)
	unlocked_designs = list(/datum/design/board/cloning_vat)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

#undef CLONING_VAT_GROWTH_TIME
#undef CLONING_VAT_DECAY_MULT
#undef CLONING_VAT_READY_BAND
#undef CLONING_VAT_MESS_THRESHOLD

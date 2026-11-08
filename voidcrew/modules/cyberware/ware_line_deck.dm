/**
 * # The deck line
 *
 * Cortex decks: head chrome that pushes quickhacks into machines and people's
 * gear in sight. They run the Machine Communion boon's own hacks
 * (voidcrew/modules/quickhacks/), through a [/datum/quickhack_kit] each deck
 * builds from its vars, with a few hacks of their own written below.
 *
 * Every model sits in its own head slot, ORGAN_SLOT_CYBERWARE_DECK, so a
 * better deck evicts the old one. Higher models carry everything the model
 * below them does; the two service decks split at T3, one for doors, radios and
 * turrets, one for people and their gear, and the flagship carries both.
 *
 * Model       tier  load  range  upload  cooldowns  adds
 * Junker       T1     2     5     2 s      x1.5     Bolts, Burst the Lights, Ping
 * Street       T2     4     6     1.5 s    x1.5     Kill the Power
 * Facilities   T3     6     7     1 s      x1       Cutout, Electrify, Silence, Reboot Turret
 * Breacher     T3     6     7     1 s      x1       Overload, Feedback Surge, Glitch
 * Blackbox     T4     9     8     0.5 s    x1       both T3 sets, and Arc Flash
 *
 * What a deck never does, whatever its tier: grant TRAIT_SILICON_ACCESS or
 * TRAIT_AI_ACCESS or skip an ID lock (no hack here opens a door), run Cut the
 * Safeties (the emag effect) or Wake the Machines. Those are the boon's alone;
 * the kit refuses them even if a model lists one.
 *
 * The counterplay is all on show:
 * - Range and a clear line from the hacker to the target, checked when the
 *   hack is picked and on every tick of the upload.
 * - The upload: a trace line from hacker to target and a chirp the target
 *   hears, for a model's upload time. Moving, losing sight, an EMP or a stun
 *   loses the upload at no cost.
 * - One shared cooldown, set by the hack that landed, like the boon's.
 * - EMP and brownout kill the deck (the cyberware action bridge); Chrome Read
 *   shows it.
 * - Outpost property and outpost prison doors (cells and staff doors) refuse
 *   every hack outright, and so do a prison wing's APC and lights (Kill the
 *   Power, Burst the Lights), so a deck never springs a prisoner. Overload refuses any
 *   machine on an outpost, trader or player (owner, D12: decks never blow up
 *   outpost machines). A person hacked at a trader outpost counts as an attack
 *   on them there, the same as a punch, and Arc Flash does not run there at all.
 *
 * Activation (owner, 11-08): using the deck, from its button, its chrome
 * wheel slice or Use chrome, arms targeting. The next click picks the target,
 * and the hack radial opens on that target listing only what it would take,
 * the way the boon's does. Hacks are deliberately NOT on the chrome wheel's
 * outer ring. Clicking yourself opens the room hacks. While zoomed through
 * optics, a click on what you see through the zoom reaches here through
 * COMSIG_CYBERWARE_ZOOM_CLICK.
 */

// The optics zoom (voidcrew/_DEFINES/cyberware.dm on phase2/zoom) owns these.
// Copies with the same names and values, until both are on one branch.
#ifndef COMSIG_CYBERWARE_ZOOM_CLICK
/// Sent on the bearer for every click made while zoomed, before the click
/// intercept chain: (mob/living/carbon/bearer, atom/target, list/modifiers).
#define COMSIG_CYBERWARE_ZOOM_CLICK "cyberware_zoom_click"
#endif
#ifndef COMPONENT_CYBERWARE_ZOOM_CLICK_HANDLED
/// Return from a COMSIG_CYBERWARE_ZOOM_CLICK handler that took the click.
#define COMPONENT_CYBERWARE_ZOOM_CLICK_HANDLED (1<<0)
#endif

// =========================================================================
// THE DECKS
// =========================================================================

/// T1: a dead terminal and a cracked handheld, soldered into a cortex socket.
/obj/item/organ/cyberimp/cyberware/deck
	name = "\improper Junker deck"
	desc = "A cortex deck soldered together from a dead terminal and a cracked handheld. Doors and light panels still answer it, mostly."
	icon_state = "deck"
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_CYBERWARE_DECK
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 2
	tier = CYBERWARE_TIER_1
	actions_types = list(/datum/action/cooldown/cyberware/deck)
	/// Quickhacks this deck carries, subtypes of /datum/machine_quickhack.
	/// Every model carries everything the model below it does.
	var/list/quickhacks = list(
		/datum/machine_quickhack/bolts,
		/datum/machine_quickhack/burst_lights,
	)
	/// Room hacks this deck carries, subtypes of /datum/machine_masshack. Run by
	/// pointing the deck at yourself.
	var/list/masshacks = list(
		/datum/machine_masshack/ping,
	)
	/// Tiles a quickhack reaches. Line of sight is always needed as well.
	var/hack_range = 5
	/// How long a hack uploads before it lands.
	var/upload_time = 2 SECONDS
	/// Multiplier on every hack's own cooldown.
	var/cooldown_mult = 1.5
	/// What the deck's menu and action read. Built from the vars above.
	var/datum/quickhack_kit/kit

/obj/item/organ/cyberimp/cyberware/deck/Initialize(mapload)
	. = ..()
	kit = new /datum/quickhack_kit(quickhacks, masshacks, hack_range, upload_time, cooldown_mult)

/obj/item/organ/cyberimp/cyberware/deck/Destroy()
	QDEL_NULL(kit)
	return ..()

/// T2: the same idea in a real shell, with someone else's maintenance codes.
/obj/item/organ/cyberimp/cyberware/deck/street
	name = "\improper Street deck"
	desc = "A cortex deck in a scuffed polymer shell, flashed with somebody else's maintenance codes."
	icon_state = "deck_street"
	chrome_load = 4
	tier = CYBERWARE_TIER_2
	quickhacks = list(
		/datum/machine_quickhack/bolts,
		/datum/machine_quickhack/burst_lights,
		/datum/machine_quickhack/kill_power,
	)
	hack_range = 6
	upload_time = 1.5 SECONDS
	cooldown_mult = 1.5

/// T3, infrastructure: doors, radios and turrets.
/obj/item/organ/cyberimp/cyberware/deck/control
	name = "\improper Facilities deck"
	desc = "A facilities engineer's cortex deck, built to run a station's doors, radios and turrets from the corridor. The asset tag has been filed off."
	icon_state = "deck_control"
	chrome_load = 6
	tier = CYBERWARE_TIER_3
	quickhacks = list(
		/datum/machine_quickhack/bolts,
		/datum/machine_quickhack/burst_lights,
		/datum/machine_quickhack/kill_power,
		/datum/machine_quickhack/cutout,
		/datum/machine_quickhack/electrify,
		/datum/machine_quickhack/silence,
		/datum/machine_quickhack/reboot_turret,
	)
	hack_range = 7
	upload_time = 1 SECONDS
	cooldown_mult = 1

/// T3, offensive: people, their gear and the chrome inside them.
/obj/item/organ/cyberimp/cyberware/deck/assault
	name = "\improper Breacher deck"
	desc = "A boarding team's cortex deck, built to shut down a defender's gear and the chrome inside them. It runs warm."
	icon_state = "deck_assault"
	chrome_load = 6
	tier = CYBERWARE_TIER_3
	quickhacks = list(
		/datum/machine_quickhack/bolts,
		/datum/machine_quickhack/burst_lights,
		/datum/machine_quickhack/kill_power,
		/datum/machine_quickhack/overload,
		/datum/machine_quickhack/feedback_surge,
		/datum/machine_quickhack/glitch,
	)
	hack_range = 7
	upload_time = 1 SECONDS
	cooldown_mult = 1

/// T4: everything both service decks carry, and a room hack.
/obj/item/organ/cyberimp/cyberware/deck/flagship
	name = "\improper Blackbox deck"
	desc = "A sealed cortex deck in a flat black casing with no maker's mark. Every machine in a room seems to know when it's there."
	icon_state = "deck_flagship"
	chrome_load = 9
	tier = CYBERWARE_TIER_4
	quickhacks = list(
		/datum/machine_quickhack/bolts,
		/datum/machine_quickhack/burst_lights,
		/datum/machine_quickhack/kill_power,
		/datum/machine_quickhack/cutout,
		/datum/machine_quickhack/electrify,
		/datum/machine_quickhack/silence,
		/datum/machine_quickhack/reboot_turret,
		/datum/machine_quickhack/overload,
		/datum/machine_quickhack/feedback_surge,
		/datum/machine_quickhack/glitch,
	)
	masshacks = list(
		/datum/machine_masshack/ping,
		/datum/machine_masshack/arc_flash,
	)
	hack_range = 8
	upload_time = 0.5 SECONDS
	cooldown_mult = 1

// =========================================================================
// THE ACTION
// =========================================================================

/**
 * The deck's one button. Click-to-target on the cyberware bridge, so an EMP'd
 * or browned-out deck goes dark like any other ware.
 *
 * Using it arms targeting. Clicking a target checks reach, then opens a radial
 * on that target of the hacks it would take. The pick uploads
 * ([proc/upload_quickhack]) and lands. Clicking yourself does the same with the
 * room hacks. Activate() only starts all that and returns at once; the menu and
 * the upload sleep in their own call chain, guarded by [busy].
 *
 * The cooldown is one timer for the whole deck, set by whichever hack landed,
 * times the deck's multiplier: the boon's model, and the one the chrome wheel
 * draws on the deck's slice. Backing out of the menu or losing the upload
 * costs nothing.
 */
/datum/action/cooldown/cyberware/deck
	name = "Quickhack"
	desc = "Push a quickhack into a machine or someone's gear in sight, or into the room around you."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "bci_network"
	ranged_mousepointer = 'icons/effects/mouse_pointers/override_machine_target.dmi'
	cooldown_time = 0
	click_to_activate = TRUE
	/// Set while a menu or an upload is open, so neither can stack.
	var/busy = FALSE
	/// The trace line drawn while an upload runs.
	var/datum/beam/trace

/datum/action/cooldown/cyberware/deck/Destroy()
	QDEL_NULL(trace)
	return ..()

/datum/action/cooldown/cyberware/deck/Grant(mob/grant_to)
	. = ..()
	if(owner)
		RegisterSignal(owner, COMSIG_CYBERWARE_ZOOM_CLICK, PROC_REF(on_zoom_click), override = TRUE)

/datum/action/cooldown/cyberware/deck/Remove(mob/removed_from)
	if(removed_from)
		UnregisterSignal(removed_from, COMSIG_CYBERWARE_ZOOM_CLICK)
	QDEL_NULL(trace)
	return ..()

/// The deck this button belongs to, or null.
/datum/action/cooldown/cyberware/deck/proc/get_deck()
	var/obj/item/organ/cyberimp/cyberware/deck/deck = organ
	return istype(deck) && deck.kit ? deck : null

/datum/action/cooldown/cyberware/deck/Activate(atom/target)
	var/obj/item/organ/cyberimp/cyberware/deck/deck = get_deck()
	var/mob/living/carbon/bearer = deck?.owner
	if(!deck || !iscarbon(bearer) || isnull(target))
		return FALSE
	// HUD clicks are never targets. A click made through the zoom arrives with
	// its real target through on_zoom_click() instead.
	if(istype(target, /atom/movable/screen))
		return FALSE
	if(busy)
		bearer.balloon_alert(bearer, "deck busy!")
		return FALSE
	if(target == bearer)
		return start_room_hack(bearer)
	if(!can_reach(bearer, target, feedback = TRUE))
		return FALSE
	var/list/available = offered_hacks(bearer, target)
	if(!length(available))
		target.balloon_alert(bearer, "nothing to talk to!")
		return FALSE
	busy = TRUE
	INVOKE_ASYNC(src, PROC_REF(run_quickhack), bearer, target, available)
	return TRUE

/// Starts the room hack flow on the bearer's own tile.
/datum/action/cooldown/cyberware/deck/proc/start_room_hack(mob/living/carbon/bearer)
	var/obj/item/organ/cyberimp/cyberware/deck/deck = get_deck()
	if(bearer.is_blind())
		bearer.balloon_alert(bearer, "can't see!")
		return FALSE
	var/list/available = list()
	for(var/datum/machine_masshack/hack as anything in deck.kit.applicable_masshacks(bearer, get_turf(bearer)))
		if(deck_allows_room(hack, bearer))
			available += hack
	if(!length(available))
		bearer.balloon_alert(bearer, "nothing here answers!")
		return FALSE
	busy = TRUE
	INVOKE_ASYNC(src, PROC_REF(run_room_hack), bearer, available)
	return TRUE

// ---- Reach -------------------------------------------------------------

/// Whether the deck can work on this target from here: the bearer can see,
/// the target is not outpost property or part of a prison wing (a door, its APC
/// or a light in it), and it is in range and in a clear line.
/datum/action/cooldown/cyberware/deck/proc/can_reach(mob/living/carbon/bearer, atom/target, feedback = FALSE)
	var/obj/item/organ/cyberimp/cyberware/deck/deck = get_deck()
	if(!deck || QDELETED(target))
		return FALSE
	if(bearer.is_blind())
		if(feedback)
			bearer.balloon_alert(bearer, "can't see!")
		return FALSE
	// Prison doors too, cells and staff doors alike, and the wing's own APC and
	// lights: no prison break by deck.
	if(HAS_TRAIT(target, TRAIT_OUTPOST_PROPERTY) || is_outpost_prison_airlock(target) || is_outpost_prison_fixture(target))
		if(feedback)
			target.balloon_alert(bearer, "hardened firmware!")
		return FALSE
	if(deck.kit.in_reach(bearer, target))
		return TRUE
	if(feedback)
		var/turf/here = get_turf(bearer)
		var/turf/there = get_turf(target)
		var/too_far = !here || !there || here.z != there.z || get_dist(here, there) > deck.kit.hack_range
		target.balloon_alert(bearer, too_far ? "out of range!" : "no line of sight!")
	return FALSE

/// What the deck offers on this target: the kit's hacks it would take, minus
/// anything a deck may not do there.
/datum/action/cooldown/cyberware/deck/proc/offered_hacks(mob/living/carbon/bearer, atom/target)
	RETURN_TYPE(/list)
	. = list()
	var/obj/item/organ/cyberimp/cyberware/deck/deck = get_deck()
	if(!deck)
		return
	for(var/datum/machine_quickhack/hack as anything in deck.kit.applicable_quickhacks(target, bearer))
		if(deck_allows(hack, target))
			. += hack

/// The deck's own limits on top of a hack's: nothing a deck runs blows up a
/// machine on an outpost, a trader's or a player's (owner, D12). The boon has
/// no such limit.
/datum/action/cooldown/cyberware/deck/proc/deck_allows(datum/machine_quickhack/hack, atom/target)
	if(istype(hack, /datum/machine_quickhack/overload))
		return !get_outpost_from_atom(target) && !is_trader_outpost_protected(target)
	return TRUE

/// The same for room hacks: inside a trader outpost's protected ground, docked
/// ships included, a deck runs nothing that hurts the people around it. Arc
/// Flash's shocks come out of the machines and would never count as an attack
/// there, so it simply does not answer.
/datum/action/cooldown/cyberware/deck/proc/deck_allows_room(datum/machine_masshack/hack, mob/living/carbon/bearer)
	if(istype(hack, /datum/machine_masshack/ping))
		return TRUE
	return !is_trader_outpost_protected(bearer)

/// The deck is still in this body, still this body's button, and usable.
/datum/action/cooldown/cyberware/deck/proc/still_linked(mob/living/carbon/bearer)
	return !QDELETED(src) && !QDELETED(bearer) && owner == bearer && organ?.owner == bearer && IsAvailable(feedback = FALSE)

/// Menu and upload check for a quickhack: linked, and the target still in reach.
/datum/action/cooldown/cyberware/deck/proc/target_holds(mob/living/carbon/bearer, atom/target)
	return still_linked(bearer) && can_reach(bearer, target)

/// Menu and upload check for a room hack: linked, and still able to see.
/datum/action/cooldown/cyberware/deck/proc/room_holds(mob/living/carbon/bearer)
	return still_linked(bearer) && !bearer.is_blind()

// ---- Quickhacks ----------------------------------------------------------

/// The radial on the target, then the upload, then the hack. Sleeps.
/datum/action/cooldown/cyberware/deck/proc/run_quickhack(mob/living/carbon/bearer, atom/target, list/available)
	var/datum/machine_quickhack/hack = pick_quickhack(bearer, target, available)
	if(hack)
		upload_quickhack(bearer, target, hack)
	if(!QDELETED(src))
		busy = FALSE

/// The radial over the target. Returns the pick, or null.
/datum/action/cooldown/cyberware/deck/proc/pick_quickhack(mob/living/carbon/bearer, atom/target, list/available)
	var/obj/item/organ/cyberimp/cyberware/deck/deck = get_deck()
	if(!deck)
		return null
	var/list/options = list()
	var/list/by_name = list()
	for(var/datum/machine_quickhack/hack as anything in available)
		options[hack.name] = deck.kit.menu_option(hack)
		by_name[hack.name] = hack
	// Single options are not auto-picked: a stray click must never fire a hack.
	var/choice = choose_quickhack(bearer, target, options)
	if(!choice || !target_holds(bearer, target))
		return null
	var/datum/machine_quickhack/chosen = by_name[choice]
	if(!chosen?.valid_for(target, bearer) || !deck_allows(chosen, target))
		target.balloon_alert(bearer, "it stopped answering!")
		return null
	return chosen

/// Keep the sleeping input separate from the checks around it.
/datum/action/cooldown/cyberware/deck/proc/choose_quickhack(mob/living/carbon/bearer, atom/target, list/options)
	return show_radial_menu(bearer, target, options, custom_check = CALLBACK(src, PROC_REF(target_holds), bearer, target), tooltips = TRUE, autopick_single_option = FALSE)

/**
 * The upload, then the hack. The trace line and the chirp go out first, so
 * the target has the whole upload to react; moving, losing sight, an EMP or a
 * stun loses it at no cost.
 */
/datum/action/cooldown/cyberware/deck/proc/upload_quickhack(mob/living/carbon/bearer, atom/target, datum/machine_quickhack/hack)
	var/obj/item/organ/cyberimp/cyberware/deck/deck = get_deck()
	if(!deck || !target_holds(bearer, target))
		return FALSE
	var/datum/quickhack_kit/kit = deck.kit
	QDEL_NULL(trace)
	trace = bearer.Beam(target, icon_state = "infrared", time = kit.upload_time + 1 SECONDS, maxdistance = kit.hack_range + 1)
	playsound(target, 'sound/machines/beep/twobeep_high.ogg', 40, FALSE, MEDIUM_RANGE_SOUND_EXTRARANGE)
	if(ismob(target))
		to_chat(target, span_warning("Something in your gear chirps."))
	var/landed = do_after(bearer, kit.upload_time, target, timed_action_flags = IGNORE_TARGET_LOC_CHANGE|IGNORE_HELD_ITEM|IGNORE_SLOWDOWNS, extra_checks = CALLBACK(src, PROC_REF(target_holds), bearer, target), interaction_key = "cyberdeck_upload")
	if(QDELETED(src))
		return FALSE
	QDEL_NULL(trace)
	if(!landed || !target_holds(bearer, target))
		if(!QDELETED(bearer))
			bearer.balloon_alert(bearer, "upload lost")
		return FALSE
	if(!hack.valid_for(target, bearer) || !deck_allows(hack, target))
		target.balloon_alert(bearer, "it stopped answering!")
		return FALSE
	if(!hack.execute(target, bearer))
		return FALSE
	if(isliving(target))
		var/mob/living/victim = target
		log_combat(bearer, victim, "quickhacked", null, "with [hack.name] from [deck]")
		// Counts as an attack at a trader outpost, like any other.
		GLOB.outpost_pvp_enforcement?.register_pvp_aggression(victim, bearer)
		// And like any other attack, it drops the hacker's camo.
		drop_bearer_camo(bearer)
	else
		bearer.log_message("used the [hack.name] quickhack on [target] ([target.type]) with [deck].", LOG_ATTACK)
	cyberware_ink_pulse(bearer, CYBERWARE_INK_HARD)
	StartCooldown(kit.hack_cooldown(hack))
	return TRUE

/// A hack that hurts someone is an attack, and an attack collapses the
/// hacker's Ghostskin field the way a punch or a shot does (ware_military_body.dm).
/datum/action/cooldown/cyberware/deck/proc/drop_bearer_camo(mob/living/carbon/bearer)
	var/obj/item/organ/cyberimp/cyberware/ghostskin/weave = bearer?.get_organ_slot(ORGAN_SLOT_CYBERWARE_SKIN)
	if(istype(weave) && weave.camo_active)
		weave.break_camo(bearer, reason = "field contact")

// ---- Room hacks ----------------------------------------------------------

/// The radial on the bearer, then the upload, then the room hack. Sleeps.
/datum/action/cooldown/cyberware/deck/proc/run_room_hack(mob/living/carbon/bearer, list/available)
	var/datum/machine_masshack/hack = pick_room_hack(bearer, available)
	if(hack)
		upload_room_hack(bearer, hack)
	if(!QDELETED(src))
		busy = FALSE

/datum/action/cooldown/cyberware/deck/proc/pick_room_hack(mob/living/carbon/bearer, list/available)
	var/obj/item/organ/cyberimp/cyberware/deck/deck = get_deck()
	if(!deck)
		return null
	var/list/options = list()
	var/list/by_name = list()
	for(var/datum/machine_masshack/hack as anything in available)
		options[hack.name] = deck.kit.menu_option(hack)
		by_name[hack.name] = hack
	var/choice = choose_room_hack(bearer, options)
	if(!choice || !room_holds(bearer))
		return null
	return by_name[choice]

/datum/action/cooldown/cyberware/deck/proc/choose_room_hack(mob/living/carbon/bearer, list/options)
	return show_radial_menu(bearer, bearer, options, custom_check = CALLBACK(src, PROC_REF(room_holds), bearer), tooltips = TRUE, autopick_single_option = FALSE)

/// A room hack uploads where the bearer stands, and the room hears it.
/datum/action/cooldown/cyberware/deck/proc/upload_room_hack(mob/living/carbon/bearer, datum/machine_masshack/hack)
	var/obj/item/organ/cyberimp/cyberware/deck/deck = get_deck()
	if(!deck || !room_holds(bearer))
		return FALSE
	var/datum/quickhack_kit/kit = deck.kit
	playsound(bearer, 'sound/machines/beep/twobeep_high.ogg', 40, FALSE)
	do_sparks(1, FALSE, bearer)
	var/landed = do_after(bearer, kit.upload_time, bearer, timed_action_flags = IGNORE_HELD_ITEM|IGNORE_SLOWDOWNS, extra_checks = CALLBACK(src, PROC_REF(room_holds), bearer), interaction_key = "cyberdeck_upload")
	if(QDELETED(src))
		return FALSE
	if(!landed || !room_holds(bearer))
		if(!QDELETED(bearer))
			bearer.balloon_alert(bearer, "upload lost")
		return FALSE
	var/turf/here = get_turf(bearer)
	if(isnull(here) || !hack.available(bearer, here) || !deck_allows_room(hack, bearer))
		bearer.balloon_alert(bearer, "nothing here answers!")
		return FALSE
	if(!hack.execute(bearer, here))
		return FALSE
	bearer.log_message("used the [hack.name] room hack with [deck].", LOG_ATTACK)
	if(!istype(hack, /datum/machine_masshack/ping))
		message_admins("[ADMIN_LOOKUPFLW(bearer)] used the [hack.name] room hack from [deck] at [ADMIN_VERBOSEJMP(here)].")
		// Arc Flash hurts everyone in the room: an attack, so the camo goes.
		drop_bearer_camo(bearer)
	cyberware_ink_pulse(bearer, CYBERWARE_INK_HARD)
	StartCooldown(kit.hack_cooldown(hack))
	return TRUE

// ---- Zoom ----------------------------------------------------------------

/**
 * A click made through the optics zoom, with what it landed on. The zoom sends
 * this before the click intercept chain and drops any click nobody handles, so
 * an armed deck takes it here, exactly as a plain click: InterceptClickOn()
 * checks the deck is usable, runs the target-first flow (the radial opens on
 * the target) and disarms once it has started. The zoom checks no range, so
 * reach is the deck's own range from the bearer, with line of sight, as ever.
 * A target out of reach is refused with feedback and the deck stays armed, the
 * same as a plain click on it. An unarmed deck leaves the click alone.
 */
/datum/action/cooldown/cyberware/deck/proc/on_zoom_click(mob/living/carbon/source, atom/target, list/modifiers)
	SIGNAL_HANDLER
	if(source != owner || source.click_intercept != src || QDELETED(target))
		return NONE
	INVOKE_ASYNC(src, PROC_REF(InterceptClickOn), source, null, target)
	return COMPONENT_CYBERWARE_ZOOM_CLICK_HANDLED

// =========================================================================
// THE DECK'S OWN HACKS
// The deck line's additions to voidcrew/modules/quickhacks/. The boon's kit
// lists its hacks by hand, so none of these reach it.
// =========================================================================

/**
 * Ping: everything in the area that answers a handshake lights up for the
 * hacker alone, walls and all, for a few seconds. Cameras, turrets and
 * powered doors only. Room hack, so it runs from where the hacker stands.
 */
/datum/machine_masshack/ping
	name = "Ping"
	desc = "Every camera, turret and powered door nearby answers the handshake and shows through the walls for a moment."
	radial_icon = 'icons/mob/actions/actions_items.dmi'
	radial_icon_state = "bci_wireless"
	cooldown = 20 SECONDS
	/// How far the handshake carries, walls and all.
	var/reach = 7
	/// How long the marks stay up.
	var/mark_time = 5 SECONDS

/datum/machine_masshack/ping/available(mob/living/user, turf/center)
	return !isnull(center)

/datum/machine_masshack/ping/execute(mob/living/user, turf/center)
	var/marked = 0
	for(var/obj/machinery/machine in range(reach, center))
		var/mark_color = ping_color(machine)
		if(mark_color && cyberware_hud_mark(user, machine, mark_color, mark_time))
			marked++
	if(!marked)
		user.balloon_alert(user, "nothing answers")
		return FALSE
	user.playsound_local(center, 'sound/machines/sonar-ping.ogg', 40, FALSE)
	return TRUE

/// The mark colour for a machine that answers a ping, or null if it doesn't.
/datum/machine_masshack/ping/proc/ping_color(obj/machinery/machine)
	if(istype(machine, /obj/machinery/porta_turret) || istype(machine, /obj/machinery/ship_combat/laser_turret))
		return "#ff4f4f"
	if(istype(machine, /obj/machinery/camera))
		var/obj/machinery/camera/camera = machine
		return camera.camera_enabled ? "#ffb347" : null
	if(istype(machine, /obj/machinery/door/airlock))
		var/obj/machinery/door/airlock/door = machine
		return door.hasPower() ? "#4dd8e6" : null
	return null

/**
 * Reboot Turret: a cold boot that takes a turret off the line for a few
 * seconds, then lets it come back as it was. The Icepick Jack's suppress is
 * the stronger, contact-range version of this; it stays that way.
 *
 * Same refusals as the Icepick: outpost security firmware never answers. A
 * turret on a player's ship trips that crew's intrusion alarm.
 */
/datum/machine_quickhack/reboot_turret
	name = "Reboot Turret"
	desc = "Force a turret through a cold boot. It goes quiet for a few seconds."
	radial_icon = 'icons/obj/weapons/turrets.dmi'
	radial_icon_state = "standard_off"
	cooldown = 20 SECONDS
	/// How long the turret stays down.
	var/downtime = 8 SECONDS

/// The turret behind what was clicked: a closed turret's cover stands in for it.
/datum/machine_quickhack/reboot_turret/proc/resolve_turret(atom/target)
	if(istype(target, /obj/machinery/porta_turret_cover))
		var/obj/machinery/porta_turret_cover/cover = target
		return cover.parent_turret
	return target

/datum/machine_quickhack/reboot_turret/valid_for(atom/target, mob/living/user)
	var/atom/turret = resolve_turret(target)
	if(istype(turret, /obj/machinery/porta_turret))
		if(istype(turret, /obj/machinery/porta_turret/outpost))
			return FALSE
		var/obj/machinery/porta_turret/porta = turret
		return porta.on && !(porta.machine_stat & BROKEN)
	return istype(turret, /obj/machinery/ship_combat/laser_turret)

/datum/machine_quickhack/reboot_turret/execute(atom/target, mob/living/user)
	var/obj/machinery/turret = resolve_turret(target)
	if(istype(turret, /obj/machinery/porta_turret))
		var/obj/machinery/porta_turret/porta = turret
		porta.set_disabled(downtime)
	else if(istype(turret, /obj/machinery/ship_combat/laser_turret))
		var/obj/machinery/ship_combat/laser_turret/laser = turret
		if(laser.fire_cooldown < world.time + downtime)
			COOLDOWN_START(laser, fire_cooldown, downtime)
	else
		return FALSE
	do_sparks(2, TRUE, turret)
	playsound(turret, 'sound/effects/magic/disable_tech.ogg', 50, TRUE)
	turret.visible_message(span_warning("[turret] powers down with a falling whine."))
	cyberware_turret_intrusion_alarm(turret, user)
	return TRUE

/**
 * Glitch: one piece of the target's running chrome, picked at random, takes
 * the ordinary cyberware EMP reboot. Chrome is balanced around EMP, so this is
 * the hacker's answer to a chromed-up fighter, one piece at a time.
 */
/datum/machine_quickhack/glitch
	name = "Glitch"
	desc = "Throw one piece of a person's chrome into a reboot. Which piece is anyone's guess."
	radial_icon = 'icons/mob/actions/actions_spells.dmi'
	radial_icon_state = "emp"
	cooldown = 60 SECONDS

/// The target's chrome that is up and running right now.
/datum/machine_quickhack/glitch/proc/running_chrome(mob/living/carbon/victim)
	RETURN_TYPE(/list)
	. = list()
	for(var/obj/item/organ/ware as anything in get_installed_cyberware(victim))
		var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
		if(chrome?.is_running())
			. += ware

/datum/machine_quickhack/glitch/valid_for(atom/target, mob/living/user)
	if(!iscarbon(target) || target == user)
		return FALSE
	var/mob/living/carbon/victim = target
	return victim.stat != DEAD && length(running_chrome(victim))

/datum/machine_quickhack/glitch/execute(atom/target, mob/living/user)
	var/mob/living/carbon/victim = target
	var/list/running = running_chrome(victim)
	if(!length(running))
		return FALSE
	var/obj/item/organ/ware = pick(running)
	var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
	chrome.start_emp_reboot(EMP_HEAVY)
	victim.balloon_alert(victim, "[ware.name] glitches out!")
	do_sparks(2, TRUE, victim)
	to_chat(user, span_notice("Something in [victim] drops into a reboot."))
	return TRUE

// =========================================================================
// SPLICE SKUS: on the Chop Shop's sku_types, the two credit decks on the
// street doc's too, and the gated ones pinned in voidcrew_zone_shops' catalog.
// =========================================================================

/datum/shop_sku/ripperdoc/deck_junker
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/deck
	price_credits = 1500
	stock_min = 1
	stock_max = 2

/datum/shop_sku/ripperdoc/deck_street
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/deck/street
	price_credits = 3500

/datum/shop_sku/ripperdoc/deck_control
	zone_permission = ZONE_PERMISSION_ADVANCED
	category = "Military Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/deck/control
	price_vouchers = 4

/datum/shop_sku/ripperdoc/deck_assault
	zone_permission = ZONE_PERMISSION_ADVANCED
	category = "Military Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/deck/assault
	price_vouchers = 4

/datum/shop_sku/ripperdoc/deck_flagship
	zone_permission = ZONE_PERMISSION_ELITE
	category = "Legend Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/deck/flagship
	price_vouchers = 7
	stock_min = 1
	stock_max = 1

// =========================================================================
// TRADE-IN: the two credit decks at half list, credits only. Not listed on
// any buyback_types yet. Voucher decks are never bought back.
// =========================================================================

/datum/shop_buyback/ripperdoc/deck_junker
	name = "Junker deck (pulled)"
	desc = "A soldered-up cortex deck, pulled."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/deck
	match_subtypes = FALSE
	pay_credits = 750
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/deck_street
	name = "Street deck (pulled)"
	desc = "A street cortex deck, pulled."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/deck/street
	match_subtypes = FALSE
	pay_credits = 1750
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/deck_junker/street_doc
	desc = "A used junker deck. Solder's holding, just."

/datum/shop_buyback/ripperdoc/deck_street/street_doc
	desc = "A used street deck. Somebody else's codes still on it."

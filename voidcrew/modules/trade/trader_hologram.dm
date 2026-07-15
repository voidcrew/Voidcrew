/**
 * # Trader Hologram
 *
 * The outpost's "shopkeeper": a hard-light projection with a personality, not
 * a killable mob. The machine is the projector pad; the visible figure is a
 * holo_pad_hologram effect built from a per-shop preset holoimage (same
 * pattern as the pirate negotiation holograms in modules/npc_ships).
 *
 * Attacking either the pad or the projection is aggression and gets your ship
 * embargoed like attacking anything else here.
 *
 * Speech lines come from the outpost's shop datum, so each shop type has its
 * own voice (see the trader_lines lists on the /datum/outpost_shop subtypes).
 */
/obj/machinery/outpost_trader
	name = "holographic trader"
	desc = "A heavy-duty holopad projecting a hard-light merchant. The projector housing looks like it could survive a direct torpedo hit. It probably has."
	icon = 'icons/obj/machines/floor.dmi'
	icon_state = "holopad0"
	base_icon_state = "holopad"
	density = FALSE
	anchored = TRUE
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

	/// The outpost this trader fronts for (set by the outpost on interior load)
	var/obj/structure/overmap/trader_outpost/outpost
	/// The projected merchant figure
	var/obj/effect/overlay/holo_pad_hologram/outpost_trader/hologram
	/// Minimum delay between idle chatter lines
	COOLDOWN_DECLARE(idle_line_cooldown)
	/// Minimum delay between any spoken lines (don't spam on bulk purchases)
	COOLDOWN_DECLARE(speak_cooldown)

/obj/machinery/outpost_trader/Destroy()
	QDEL_NULL(hologram)
	outpost = null
	return ..()

/**
 * Projects the merchant figure and lights the pad. Called by the outpost once
 * it has linked this machine (the appearance depends on the shop datum).
 */
/obj/machinery/outpost_trader/proc/activate_hologram()
	if(hologram || !outpost?.shop)
		return
	hologram = new(get_turf(src))
	hologram.trader_machine = src
	hologram.set_trader_appearance(outpost.shop)
	icon_state = "holopad1"
	set_light(2, 1, LIGHT_COLOR_CYAN)

/obj/machinery/outpost_trader/update_name(updates)
	. = ..()
	if(outpost?.shop)
		name = "[outpost.shop.trader_name], holographic trader"

/obj/machinery/outpost_trader/examine(mob/user)
	. = ..()
	if(outpost?.shop)
		. += span_notice("The projection introduces itself as <b>[outpost.shop.trader_name]</b>.")
	if(outpost?.is_user_barred(user))
		. += span_warning("It is pointedly ignoring you.")

/obj/machinery/outpost_trader/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	if(outpost?.is_user_barred(user))
		speak_line(TRADER_LINE_REFUSAL)
		return TRUE
	speak_line(TRADER_LINE_IDLE)
	return TRUE

/**
 * Says a random personality line from the given TRADER_LINE_* category,
 * through the projection when it exists. Rate-limited except for aggression
 * lines, which always go through. Lines fire voice barks (same system as the
 * pirate negotiation holograms) so each trader has an audible voice.
 */
/obj/machinery/outpost_trader/proc/speak_line(category)
	if(!outpost?.shop)
		return
	if(category != TRADER_LINE_AGGRESSION && !COOLDOWN_FINISHED(src, speak_cooldown))
		return
	var/line = outpost.shop.get_line(category)
	if(!line)
		return
	COOLDOWN_START(src, speak_cooldown, 3 SECONDS)
	var/atom/movable/speaker = hologram || src
	speaker.say(line)

	// Audible bark through the projection, in the shop's configured voice
	if(GLOB.voices_enabled && hologram)
		var/datum/atom_voice/bark_voice = hologram.get_bark_voice()
		if(bark_voice?.voicepack)
			var/list/hearers = get_hearers_in_view(7, hologram)
			bark_voice.start_barking(line, hearers, 7, say_test(line), FALSE, hologram)

// Idle chatter on the machinery tick, roughly once every few minutes
/obj/machinery/outpost_trader/process()
	if(!outpost?.shop)
		return
	if(!COOLDOWN_FINISHED(src, idle_line_cooldown))
		return
	if(!prob(15))
		return
	// Only chatter when someone's around to hear it
	var/audience = FALSE
	for(var/mob/living/visitor in view(7, src))
		if(visitor.client)
			audience = TRUE
			break
	if(!audience)
		return
	COOLDOWN_START(src, idle_line_cooldown, 2 MINUTES)
	speak_line(TRADER_LINE_IDLE)

// Attacking the projector pad is aggression like anything else here
/obj/machinery/outpost_trader/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force && outpost)
		outpost.register_aggression(user)
	return ..()

/obj/machinery/outpost_trader/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	if(outpost && isliving(hitting_projectile.firer))
		outpost.register_aggression(hitting_projectile.firer)
	return ..()

/**
 * # The projected merchant
 *
 * Visible hard-light figure standing on the pad. Built from a per-shop
 * /datum/preset_holoimage (outfit + species), like the pirate captains.
 */
/obj/effect/overlay/holo_pad_hologram/outpost_trader
	name = "holographic trader"
	desc = "A hard-light merchant. Swinging at it would only insult the projector."
	mouse_opacity = MOUSE_OPACITY_ICON
	anchored = TRUE

	/// The projector pad this figure belongs to
	var/obj/machinery/outpost_trader/trader_machine

/obj/effect/overlay/holo_pad_hologram/outpost_trader/Destroy()
	if(trader_machine?.hologram == src)
		trader_machine.hologram = null
	trader_machine = null
	return ..()

/**
 * Builds the figure's appearance from the shop's preset holoimage, and tunes
 * its bark voice to the shop's configured pack and pitch.
 */
/obj/effect/overlay/holo_pad_hologram/outpost_trader/proc/set_trader_appearance(datum/outpost_shop/shop)
	name = "[shop.trader_name] (Hologram)"
	var/datum/preset_holoimage/preset = new shop.trader_holoimage_type
	var/image/merchant_image = preset.build_image()
	if(merchant_image)
		icon = merchant_image.icon
		icon_state = merchant_image.icon_state
		copy_overlays(merchant_image, TRUE)
		makeHologram()
	mouse_opacity = MOUSE_OPACITY_ICON
	layer = FLY_LAYER
	if(shop.trader_voice_pack)
		set_bark_voice_pack(shop.trader_voice_pack)
		var/datum/atom_voice/bark_voice = get_bark_voice()
		if(bark_voice)
			bark_voice.pitch = shop.trader_voice_pitch

/obj/effect/overlay/holo_pad_hologram/outpost_trader/examine(mob/user)
	. = ..()
	if(trader_machine?.outpost?.is_user_barred(user))
		. += span_warning("[name] is pointedly ignoring you.")

// Clicking the figure talks to the trader, same as clicking the pad
/obj/effect/overlay/holo_pad_hologram/outpost_trader/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(. || !trader_machine)
		return
	var/obj/structure/overmap/trader_outpost/outpost = trader_machine.outpost
	if(outpost?.is_user_barred(user))
		trader_machine.speak_line(TRADER_LINE_REFUSAL)
		return TRUE
	trader_machine.speak_line(TRADER_LINE_IDLE)
	return TRUE

// Swinging at the projection counts as aggression; the swing itself whiffs
/obj/effect/overlay/holo_pad_hologram/outpost_trader/attackby(obj/item/attacking_item, mob/living/user, list/modifiers)
	if(attacking_item.force)
		user.visible_message(
			span_warning("[user]'s [attacking_item.name] passes straight through [name]."),
			span_warning("Your [attacking_item.name] passes straight through [name]."),
		)
		trader_machine?.outpost?.register_aggression(user)
		return TRUE
	return ..()

/obj/effect/overlay/holo_pad_hologram/outpost_trader/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	if(isliving(hitting_projectile.firer))
		trader_machine?.outpost?.register_aggression(hitting_projectile.firer)
	return ..()

// ========== PRESET HOLOIMAGES FOR THE TRADERS ==========

/// Vex, the black-market fence: trenchcoat and bad intentions
/datum/preset_holoimage/outpost_trader/black_market
	outfit_type = /datum/outfit/job/detective

/// Sarge, the outfitter: looks like the kit she sells
/datum/preset_holoimage/outpost_trader/outfitter
	outfit_type = /datum/outfit/job/hos

/// Barnaby, the general-store keeper: tweed and patience
/datum/preset_holoimage/outpost_trader/general
	outfit_type = /datum/outfit/job/curator

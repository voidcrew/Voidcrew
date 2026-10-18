/**
 * # Checkpoint guards and weapons permits
 *
 * Each trader outpost's lobby checkpoint has a guard in a sealed glass booth. The guard is an ordinary
 * outpost trader (godmode, Trade and Talk radial, the TraderShop window) whose only stock is the
 * weapons permit, and is the checkpoint's voice (outpost_checkpoint.dm announce()).
 *
 * The permit is a record the outpost keeps against the buyer's mind (grant_weapons_permit(),
 * outpost_trespass.dm); the paper the guard hands over is a receipt and proves nothing by itself.
 * It is sold like any SKU, so barred customers (aggressors, embargoed crews, armed trespassers) are
 * refused by the shop flow before it gets this far.
 */

/mob/living/basic/outpost_trader/checkpoint_guard
	name = "guard"
	desc = "Outpost security, behind armored glass."
	/// The checkpoint this guard keeps: matches its doors' and arches' checkpoint_id
	var/checkpoint_id
	/// Set when the outpost links its interior
	var/datum/outpost_checkpoint/checkpoint

/mob/living/basic/outpost_trader/checkpoint_guard/Destroy()
	if(checkpoint?.guard == src)
		checkpoint.guard = null
	checkpoint = null
	return ..()

/mob/living/basic/outpost_trader/checkpoint_guard/halcyon
	shop_type = /datum/outpost_shop/vendor/checkpoint/halcyon

/mob/living/basic/outpost_trader/checkpoint_guard/quartermain
	shop_type = /datum/outpost_shop/vendor/checkpoint/quartermain

/mob/living/basic/outpost_trader/checkpoint_guard/undertow
	shop_type = /datum/outpost_shop/vendor/checkpoint/undertow

// =========================================================================
// THE DESKS
// =========================================================================

/// Abstract: a checkpoint guard's desk. Sells nothing but the permit.
/datum/outpost_shop/vendor/checkpoint
	outpost_name = "\improper Checkpoint"
	trader_name = "Guard"
	categories = list("Permits")
	sku_types = list(/datum/shop_sku/weapons_permit)

/// Hollis keeps Halcyon's arrivals hall: polite, patient, unarmed-looking and very much not
/datum/outfit/checkpoint_guard_halcyon
	name = "Halcyon checkpoint guard"
	uniform = /obj/item/clothing/under/rank/security/officer/blueshirt
	suit = /obj/item/clothing/suit/armor/vest/blueshirt
	head = /obj/item/clothing/head/helmet/blueshirt
	gloves = /obj/item/clothing/gloves/color/black
	shoes = /obj/item/clothing/shoes/jackboots

/datum/outpost_shop/vendor/checkpoint/halcyon
	outpost_name = "\improper Halcyon Arrivals"
	trader_name = "Hollis"
	trader_outfit = /datum/outfit/checkpoint_guard_halcyon
	trader_gender = MALE
	trader_voice_pack = "goon.speak_2"
	trader_voice_pitch = 0.95
	trader_lines = list(
		CHECKPOINT_LINE_PASS = list(
			"You're clear. Enjoy your stay.",
			"Step through.",
			"All clear. Welcome to Halcyon.",
		),
		CHECKPOINT_LINE_ARMED = list(
			"Weapon on the scan. Back out, please.",
			"Scanner's flagged a weapon. Back out.",
		),
		CHECKPOINT_LINE_BARRED = list(
			"Not today. Back out, please.",
			"You're not coming in. Back out.",
		),
		CHECKPOINT_LINE_FORCING = list(
			"Step away from that door!",
			"Hey! Hands off the gate!",
		),
		CHECKPOINT_LINE_INTRUDER = list(
			"Armed intruder!",
		),
		TRADER_LINE_SALE = list(
			"Permit's good for twenty minutes.",
			"There you go. Twenty minutes. Keep it pointed at the floor.",
		),
		TRADER_LINE_REFUSAL = list(
			"No permit for you, friend.",
			"Not after that. Move along.",
		),
		TRADER_LINE_IDLE = list(
			"Quiet shift. I like quiet shifts.",
			"Keep the line moving, folks.",
			"Wipe your boots. The janitor's been on at me about the floors.",
			"Fourteen hours of nobody, then six crews at once. Every time.",
		),
	)

/// Ruck works the depot gate: the same hard hat as everyone else at the Quartermain, plus a vest
/datum/outfit/checkpoint_guard_quartermain
	name = "Quartermain checkpoint guard"
	uniform = /obj/item/clothing/under/rank/security/officer/grey
	suit = /obj/item/clothing/suit/armor/vest
	head = /obj/item/clothing/head/helmet/sec
	gloves = /obj/item/clothing/gloves/color/black
	shoes = /obj/item/clothing/shoes/jackboots

/datum/outpost_shop/vendor/checkpoint/quartermain
	outpost_name = "\improper Depot Gate"
	trader_name = "Ruck"
	trader_outfit = /datum/outfit/checkpoint_guard_quartermain
	trader_gender = MALE
	trader_voice_pack = "goon.speak_4"
	trader_voice_pitch = 0.85
	trader_lines = list(
		CHECKPOINT_LINE_PASS = list(
			"Clear. Go on.",
			"Through you go.",
			"Next.",
		),
		CHECKPOINT_LINE_ARMED = list(
			"Weapon on the scan. Back out.",
			"Iron on the scan. Back out and stow it.",
		),
		CHECKPOINT_LINE_BARRED = list(
			"You're not getting in. Back out.",
			"Not you. Out.",
		),
		CHECKPOINT_LINE_FORCING = list(
			"Get off that door!",
			"Somebody's on the gate!",
		),
		CHECKPOINT_LINE_INTRUDER = list(
			"Armed intruder!",
		),
		TRADER_LINE_SALE = list(
			"Permit's good for twenty minutes.",
			"Twenty minutes. Don't make me regret it.",
		),
		TRADER_LINE_REFUSAL = list(
			"No. Not you.",
			"You've had your chance today.",
		),
		TRADER_LINE_IDLE = list(
			"Line up. One crew at a time.",
			"Sarge says nobody gets past me with iron. Nobody does.",
			"You'd be amazed what people try to walk through that scanner.",
			"Convoy days are the worst. Everybody's in a hurry.",
		),
	)

/// Brick works the Undertow's door. Black suit, dark glasses, never seen sitting down.
/datum/outfit/checkpoint_guard_undertow
	name = "Undertow checkpoint guard"
	uniform = /obj/item/clothing/under/suit/black
	glasses = /obj/item/clothing/glasses/sunglasses
	gloves = /obj/item/clothing/gloves/color/black
	shoes = /obj/item/clothing/shoes/jackboots

/datum/outpost_shop/vendor/checkpoint/undertow
	outpost_name = "\improper The Door"
	trader_name = "Brick"
	trader_outfit = /datum/outfit/checkpoint_guard_undertow
	trader_gender = MALE
	trader_voice_pack = "goon.speak_3"
	trader_voice_pitch = 0.75
	trader_lines = list(
		CHECKPOINT_LINE_PASS = list(
			"Go on.",
			"In.",
			"Behave yourself in there.",
		),
		CHECKPOINT_LINE_ARMED = list(
			"Weapon on the scan. Back out.",
			"Nice try. Back out.",
		),
		CHECKPOINT_LINE_BARRED = list(
			"You're done here. Back out.",
			"Not tonight.",
		),
		CHECKPOINT_LINE_FORCING = list(
			"Off the door. Now.",
			"Bad idea. Real bad idea.",
		),
		CHECKPOINT_LINE_INTRUDER = list(
			"Armed intruder!",
		),
		TRADER_LINE_SALE = list(
			"Permit's good for twenty minutes.",
			"Twenty minutes. Vex doesn't do refunds and neither do I.",
		),
		TRADER_LINE_REFUSAL = list(
			"Your money's no good here.",
			"No.",
		),
		TRADER_LINE_IDLE = list(
			"Everybody's carrying something. Not past me, they aren't.",
			"I don't care who you work for.",
			"Keep it moving.",
		),
	)

// =========================================================================
// THE PERMIT
// =========================================================================

/// Sold only at a checkpoint desk. The record lives on the outpost; the paper is a receipt.
/datum/shop_sku/weapons_permit
	name = "weapons permit"
	desc = "A personal permit to go armed past the checkpoint, for a while."
	category = "Permits"
	item_path = /obj/item/paper/weapons_permit
	price_credits = OUTPOST_WEAPONS_PERMIT_PRICE
	fixed_price = TRUE
	contract_reward = FALSE
	// Never sells out: the desk prints as many as people pay for
	stock_min = 1
	stock_max = 1

/datum/shop_sku/weapons_permit/get_denial_reason(mob/living/user)
	. = ..()
	if(.)
		return
	if(!user.mind || !shop?.outpost)
		return "No permit for you."

/datum/shop_sku/weapons_permit/dispense(mob/living/user, mob/living/basic/outpost_trader/vendor)
	stock = 1
	var/obj/structure/overmap/trader_outpost/outpost = shop?.outpost
	var/runs_out = outpost?.grant_weapons_permit(user)
	var/obj/item/paper/weapons_permit/receipt = ..()
	if(istype(receipt))
		receipt.fill_in(user, outpost, runs_out)
	return receipt

/// A receipt for a weapons permit. Who is allowed to carry arms is the outpost's record, not this paper.
/obj/item/paper/weapons_permit
	name = "weapons permit"
	desc = "A stamped slip from a checkpoint desk."

/obj/item/paper/weapons_permit/proc/fill_in(mob/living/holder, obj/structure/overmap/trader_outpost/outpost, runs_out)
	var/holder_name = holder?.real_name || "the bearer"
	name = "weapons permit ([holder_name])"
	var/where = outpost?.name || "this outpost"
	var/until = runs_out ? station_time_timestamp("hh:mm", runs_out) : "--:--"
	add_raw_text("<center><b>WEAPONS PERMIT</b><br>[where]</center><hr>Issued to: <b>[holder_name]</b><br>Valid until: <b>[until]</b> station time<br>Valid at this outpost only. Not transferable.")
	update_appearance()

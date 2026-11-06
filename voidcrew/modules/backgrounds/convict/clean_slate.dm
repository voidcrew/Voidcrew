/// Backgrounds: owned by P2.

/**
 * # Clean Slate
 *
 * Vex's back-room service at the Undertow: a convict's or a pirate's own open warrant closed, for
 * BACKGROUND_CLEAN_SLATE_COST. Vex deals face to face [ECO-15]: the buyer must be recognised as
 * themselves, and must have a file to close. It completes the Fraud convict's goal. A credit sink
 * for stolen money; the receipt is paper and worth nothing.
 */

/datum/shop_sku/black_market/clean_slate
	name = "expunged record"
	desc = "A stamped receipt from the Undertow. The file it names is closed."
	category = "Back Room"
	item_path = /obj/item/paper/fluff/clean_slate
	price_credits = BACKGROUND_CLEAN_SLATE_COST
	favor_required = 0
	crew_limit = 0

/datum/shop_sku/black_market/clean_slate/get_denial_reason(mob/living/user)
	if(!background_warrant_for_mind(user?.mind))
		return "Your file's already closed."
	if(!clean_slate_recognised(user))
		return "I deal with faces, not masks."
	return ..()

/// Whether Vex sees `user` as the convict or pirate they are: their own mind, by face or by name [MP-2]
/datum/shop_sku/black_market/clean_slate/proc/clean_slate_recognised(mob/living/user)
	var/mob/living/carbon/human/person = user
	if(!ishuman(person) || !person.mind)
		return FALSE
	return background_recognised_mind(person, BACKGROUND_CONVICT) == person.mind || background_recognised_mind(person, BACKGROUND_PIRATE) == person.mind

/datum/shop_sku/black_market/clean_slate/try_purchase(mob/living/user, mob/living/basic/outpost_trader/vendor)
	if(get_denial_reason(user))
		return FALSE
	return ..()

/datum/shop_sku/black_market/clean_slate/dispense(mob/living/user, mob/living/basic/outpost_trader/vendor)
	. = ..()
	var/datum/mind/buyer = user?.mind
	background_close_warrant(buyer, "clean_slate")
	var/datum/background_state/state = buyer?.background_state
	if(state && !state.ended && state.key == BACKGROUND_CONVICT && state.goal == CONVICT_GOAL_CLEAN_SLATE)
		state.complete("Bought a clean file.")
	record_metric(METRIC_BACKGROUND, "clean_slate", ckey = user?.ckey, ship = get_crew_ship(user), subject = state?.key, credits = -get_credit_price(user))
	log_game("BACKGROUNDS: [key_name(user)] bought a clean slate from Vex")

/obj/item/paper/fluff/clean_slate
	name = "expunged record"
	desc = "A stamped receipt from the Undertow. The file it names is closed."

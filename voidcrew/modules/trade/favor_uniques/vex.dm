/**
 * # Vex's favor uniques: the Undertow's back shelf
 *
 * Two one-of-a-kind rewards Vex keeps under the counter for crews who have
 * earned real standing (the favor shelf: SHELF_FAVOR and
 * FAVOR_UNIQUE_CREW_LIMIT, voidcrew/_DEFINES/trade.dm). Late-round favor
 * prizes: polished, genuinely useful, none of them round-breaking. The shop
 * SKUs live with the catalog files; this file is items only.
 *
 * Both prizes carry TRAIT_NO_REPLICATE (voidcrew/_DEFINES/loot.dm) so the
 * Helios pattern stamp (and any future duplicator) can never copy them.
 * Favor uniques stay unique.
 */

/// How long Vex's insurance telegraphs its recall before pulling the body home
#define VEX_INSURANCE_RECALL_DELAY (10 SECONDS) // PROVISIONAL BALANCE
/// Oxygen damage cleared the moment the policy triggers. Crit deaths are mostly oxygen deaths
#define VEX_INSURANCE_OXY_HEAL 40 // PROVISIONAL BALANCE
/// Toxin damage cleared on trigger
#define VEX_INSURANCE_TOX_HEAL 10 // PROVISIONAL BALANCE
/// Brute damage healed on trigger: takes the edge off, nowhere near a full patch
#define VEX_INSURANCE_BRUTE_HEAL 15 // PROVISIONAL BALANCE
/// Burn damage healed on trigger
#define VEX_INSURANCE_BURN_HEAL 15 // PROVISIONAL BALANCE
/// Units of epinephrine released on trigger, the exact payload of a stock epinephrine medipen
#define VEX_INSURANCE_EPINEPHRINE 10

// =============================================================================
// Vex's insurance: one-shot crit rescue implant
// =============================================================================

/**
 * # Vex's insurance
 *
 * A passive implant that watches the wearer's vitals over COMSIG_MOB_STATCHANGE
 * (sent by /mob/proc/set_stat, code/modules/mob/mob.dm) and fires exactly once,
 * the first time the wearer drops into SOFT_CRIT or HARD_CRIT. UNCONSCIOUS is
 * deliberately not a trigger (that's every nap and every sleeper), and neither
 * is going straight to DEAD. A corpse gets no payout, only a customer does.
 *
 * On trigger it stabilizes on the spot (flat heals scaled against what an
 * epinephrine medipen accomplishes over its whole runtime, plus the medipen's
 * own 10u epinephrine payload for the ongoing crit regulation), announces
 * itself, and starts a telegraphed recall. Ten seconds later the body, alive
 * or not by then; retrieval is the product. Is do_teleport()ed to the crew's
 * ship, cryopod-side if the hull has pods, any open deck tile otherwise.
 *
 * No registered crew ship at trigger time = stabilization only, with an
 * apology. Either way the implant burns out after one claim.
 */
/obj/item/implant/vex_insurance
	name = "Vex's insurance implant"
	desc = "A one-shot vitals monitor wired to a bluespace recall beacon, sold with a straight face and a payment plan. If the wearer's body starts shutting down, it floods them with stabilizer and pulls them back to their registered ship. It pays out exactly once."
	icon_state = "reagents"
	implant_color = "b"
	actions_types = null // entirely passive, no activate button
	uses = 1
	/// One-shot guard: TRUE once the policy has paid out. Stat can keep changing
	/// under us (SOFT_CRIT to HARD_CRIT and back), so this must latch immediately.
	var/triggered = FALSE

/obj/item/implant/vex_insurance/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/implant/vex_insurance/implant(mob/living/target, mob/user, silent = FALSE, force = FALSE)
	. = ..()
	if(.)
		RegisterSignal(target, COMSIG_MOB_STATCHANGE, PROC_REF(on_stat_change))

/obj/item/implant/vex_insurance/removed(mob/living/source, silent = FALSE, special = 0)
	. = ..()
	if(.)
		UnregisterSignal(source, COMSIG_MOB_STATCHANGE)

/obj/item/implant/vex_insurance/get_data()
	return "<b>Implant Specifications:</b><BR> \
		<b>Name:</b> Undertow 'Full Coverage' Casualty Policy<BR> \
		<b>Life:</b> One claim.<BR> \
		<HR> \
		<b>Implant Details:</b> <BR> \
		<b>Function:</b> Monitors the holder's vital signs. On circulatory collapse, administers \
		emergency stabilizer compounds and initiates a one-time bluespace recall to the holder's \
		registered vessel.<BR> \
		<b>Disclaimer:</b> Coverage void where no vessel is registered. Premiums are not refunded."

/**
 * Signal handler for [COMSIG_MOB_STATCHANGE]. Signature matches the sender in
 * /mob/proc/set_stat: (source, new_stat, old_stat).
 */
/obj/item/implant/vex_insurance/proc/on_stat_change(mob/living/source, new_stat, old_stat)
	SIGNAL_HANDLER

	if(triggered)
		return
	// Crit only. UNCONSCIOUS alone is sleep/sedation, and DEAD without passing
	// through crit is an instant kill the policy explicitly doesn't cover.
	if(new_stat != SOFT_CRIT && new_stat != HARD_CRIT)
		return
	triggered = TRUE

	stabilize(source)
	source.visible_message(
		span_warning("Something under [source]'s skin whirs and hisses."),
		span_boldnotice("Your insurance implant snaps awake and floods your bloodstream with stabilizer."),
	)
	playsound(source, 'sound/machines/chime.ogg', 30, TRUE)

	var/obj/structure/overmap/ship/home = get_crew_ship(source)
	if(!home)
		to_chat(source, span_warning("A flat recorded voice plays from inside your chest: \"No registered vessel on file. Coverage limited to on-site stabilization. Vex thanks you for your business.\""))
		burn_out()
		return

	to_chat(source, span_notice("A flat recorded voice plays from inside your chest: \"Policy conditions met. Recall to [home.display_name || home.name] in [DisplayTimeText(VEX_INSURANCE_RECALL_DELAY)].\""))
	addtimer(CALLBACK(src, PROC_REF(recall_home)), VEX_INSURANCE_RECALL_DELAY)

/**
 * The immediate payout: enough to stop the wearer dying where they fell, not
 * enough to put them back in the fight. Scaled against the epinephrine
 * medipen (code/modules/reagents/reagent_containers/hypospray.dm), whose 10u
 * payload only drip-heals in crit. This front-loads the oxygen recovery the
 * pen would take minutes to manage, then hands over the same 10u for the
 * ongoing regulation.
 */
/obj/item/implant/vex_insurance/proc/stabilize(mob/living/patient)
	patient.adjustOxyLoss(-VEX_INSURANCE_OXY_HEAL, updating_health = FALSE)
	patient.adjustToxLoss(-VEX_INSURANCE_TOX_HEAL, updating_health = FALSE)
	patient.heal_overall_damage(brute = VEX_INSURANCE_BRUTE_HEAL, burn = VEX_INSURANCE_BURN_HEAL, updating_health = FALSE)
	patient.updatehealth()
	patient.reagents?.add_reagent(/datum/reagent/medicine/epinephrine, VEX_INSURANCE_EPINEPHRINE)

/**
 * The delayed half of the claim: haul the body home. Runs off a timer, so
 * everything gets re-checked. The implant may have been cut out, the ship
 * may have been lost. Fires whether or not the wearer survived the wait;
 * bringing the body back to the crew is half the point of the policy.
 */
/obj/item/implant/vex_insurance/proc/recall_home()
	if(QDELETED(src) || !imp_in)
		return
	var/mob/living/body = imp_in

	var/turf/destination
	var/obj/structure/overmap/ship/home = get_crew_ship(body)
	if(home?.shuttle)
		// Same placement latejoiners get (voidcrew/edits/mobs/new_player.dm):
		// beside a cryopod if the hull has any, failing that any open deck tile.
		if(length(home.shuttle.spawn_points))
			destination = get_turf(pick(home.shuttle.spawn_points))
		if(!destination)
			destination = home.get_random_open_ship_turf()

	if(!destination)
		to_chat(body, span_warning("The implant pings twice and falls silent. No registered vessel answered the recall."))
		burn_out()
		return

	if(do_teleport(body, destination, 0, channel = TELEPORT_CHANNEL_BLUESPACE, asoundin = 'sound/effects/phasein.ogg', asoundout = 'sound/effects/phasein.ogg'))
		body.visible_message(
			span_warning("[body] materializes in a flare of blue light!"),
			span_notice("Cold blue light folds around you, and you're back aboard your ship."),
		)
	else
		to_chat(body, span_warning("The implant strains against something blocking the recall, then gives up."))
	burn_out()

/// One claim, then the hardware is spent. Mirrors the freedom implant's
/// burn-out messaging (the timer targets the mob, so the qdel is safe).
/obj/item/implant/vex_insurance/proc/burn_out()
	if(imp_in)
		addtimer(CALLBACK(imp_in, TYPE_PROC_REF(/atom, balloon_alert), imp_in, "implant burnt out!"), 1 SECONDS)
	qdel(src)

/obj/item/implanter/vex_insurance
	name = "implanter (Vex's insurance)"
	// update_icon_state() hardcodes implanter0/1, so the dmi keeps those names
	icon = 'voidcrew/icons/obj/favor_uniques.dmi'
	imp_type = /obj/item/implant/vex_insurance

/obj/item/implanter/vex_insurance/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

// =============================================================================
// The Quiet Word: integrally suppressed 10mm sidearm
// =============================================================================

/**
 * # The Quiet Word
 *
 * An Ansem (10mm clandestine pistol) rebuilt around an integral suppressor,
 * following the exact pattern of the Ansem/SC Fisher
 * (code/modules/projectiles/guns/ballistic/pistol.dm): suppressed = TRUE with
 * can_suppress and can_unsuppress both FALSE, which the base ballistic code
 * reads as "the suppressor is part of the gun", no overlay, no alt-click
 * removal, and examine reports it as integral. No underbarrel gadget; this is
 * just the gun.
 *
 * Damage ladder (all existing rounds, nothing invented): the 9mm Makarov's
 * bullet is 30, 10mm is 40, a .357 is 60. Chambering it in stock 10mm lands it
 * exactly in the commissioned slot, better than a suppressed 9mm, nowhere
 * near a revolver. Carried weight matches a Makarov with a suppressor screwed
 * on (install_suppressor() bumps the class for the same reason): it does not
 * fit in a pocket.
 */
/obj/item/gun/ballistic/automatic/pistol/clandestine/quiet_word
	name = "\improper Quiet Word"
	desc = "A slab-sided 10mm pistol with a suppressor machined straight into the slide. There's no maker's mark anywhere on it and the serial well was never stamped. It fires with a flat cough instead of a bang, and the suppressor doesn't come off."
	// The whole overlay family ([icon_state]_bolt/_bolt_locked/_empty/_mag)
	// lives in the voidcrew dmi under the quiet_word name
	icon = 'voidcrew/icons/obj/favor_uniques.dmi'
	icon_state = "quiet_word"
	w_class = WEIGHT_CLASS_NORMAL // PROVISIONAL BALANCE, carries like a suppressed pistol, no pocket concealment
	suppressed = TRUE
	can_suppress = FALSE
	can_unsuppress = FALSE
	spawn_magazine_type = /obj/item/ammo_box/magazine/m10mm/quiet_word

/obj/item/gun/ballistic/automatic/pistol/clandestine/quiet_word/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/**
 * The Quiet Word's magazine. Its own typepath so it can sit on a shelf as its
 * own SKU, but it stays inside the stock 10mm family: it feeds anything that
 * accepts /obj/item/ammo_box/magazine/m10mm, and the Quiet Word happily takes
 * plain Ansem magazines back.
 */
/obj/item/ammo_box/magazine/m10mm/quiet_word
	name = "Quiet Word magazine (10mm)"
	desc = "A slim double-stack 10mm magazine cut for the Quiet Word. Standard caliber. It feeds any 10mm pistol, and the Quiet Word isn't fussy about whose magazines it eats."
	max_ammo = 10 // PROVISIONAL BALANCE, Ansem carries 8, stechkin APS 15

/obj/item/ammo_box/magazine/m10mm/quiet_word/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

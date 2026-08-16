/**
 * # Toolkit-arm street chrome (Tier 1)
 *
 * The two T1 wares on tg's arm-aug toolkit pattern: a deployable item
 * folds out of the forearm (Extend/Retract/radial/dropkey all inherited
 * from /obj/item/organ/cyberimp/arm/toolkit via the cyberware toolkit
 * base). Rockjaw is the mining fist, Fixer's is the speed toolset. The
 * T2 toolkit arms live in ware_pro_utility.dm.
 */

/// How long after the mined signal the Rockjaw waits before sweeping the
/// tile. COMSIG_MOB_MINED fires at the TOP of gets_drilled(), before the
/// ore exists (minerals.dm:213 vs :217). Sweeping immediately finds rock.
#define CYBERWARE_ROCKJAW_SWEEP_DELAY (0.2 SECONDS)

// ---- 4. Rockjaw Drill Fist --------------------------------------------

/**
 * # Rockjaw Drill Fist (T1, arm aug, load 2)
 *
 * A folding mining drill in the forearm, faster than the store-bought
 * hand drill, with the trick that sells it: while the drill is out, ore
 * from walls you crack auto-pockets into an internal hopper instead of
 * scattering at your feet. Dump the hopper as stacks on command.
 *
 * The auto-pocket rides COMSIG_MOB_MINED on the bearer; the signal
 * precedes the ore spawn, so the sweep runs on a short timer and gathers
 * whatever stacks the wall left behind.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw
	name = "\improper Rockjaw drill fist"
	desc = "A compact mining drill that folds out of the forearm. Anything it cracks gets vacuumed straight into an internal hopper, so you aren't crawling around the floor picking up your own ore."
	icon_state = "rockjaw"
	chrome_load = 2
	tier = CYBERWARE_TIER_1
	items_to_create = list(/obj/item/pickaxe/drill/cyberware)
	actions_types = list(
		/datum/action/item_action/organ_action/toggle,
		/datum/action/item_action/organ_action/rockjaw_hopper,
	)
	/// Ore stacks riding in the hopper.
	var/list/obj/item/stack/ore/hopper = list()

/**
 * Subtyped straight off organ_action so the /use New() doesn't rename it.
 *
 * The explicit button art matters: item_action falls back to the TARGET's
 * icon when button_icon_state is null (item_action.dm:11), which would hand
 * the dump button the same drill-fist sprite as the deploy button sitting
 * right next to it. A satchel reads as "empty the bag" at a glance.
 */
/datum/action/item_action/organ_action/rockjaw_hopper
	name = "Dump Ore Hopper"
	button_icon = 'icons/obj/mining.dmi'
	button_icon_state = "satchel"

/// The drill the fist deploys. Between the store drill (0.6) and the
/// diamond drill (0.2). The speed is part of what the 1,200 cr buys.
/obj/item/pickaxe/drill/cyberware
	name = "rockjaw drill"
	desc = "The business end of a Rockjaw drill fist. It only comes off the arm at a Chrome Cradle."
	toolspeed = 0.5

/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw/Destroy()
	// The toolkit parent qdels its created items but leaves other contents
	// to vanish with us. The hopper is a player's paycheck, drop it.
	var/turf/drop_turf = get_turf(src)
	if(drop_turf)
		for(var/obj/item/stack/ore/nugget as anything in hopper)
			nugget.forceMove(drop_turf)
	hopper.Cut()
	return ..()

/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw/examine(mob/user)
	. = ..()
	var/nugget_count = 0
	for(var/obj/item/stack/ore/nugget as anything in hopper)
		nugget_count += nugget.amount
	if(nugget_count)
		. += span_notice("The hopper holds <b>[nugget_count]</b> pieces of ore.")

/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw/Exited(atom/movable/gone, direction)
	. = ..()
	hopper -= gone

/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw/on_mob_insert(mob/living/carbon/arm_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(arm_owner, COMSIG_MOB_MINED, PROC_REF(on_mined))

/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw/on_mob_remove(mob/living/carbon/arm_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(arm_owner, COMSIG_MOB_MINED)

/// Signal proc for [COMSIG_MOB_MINED]: queue a sweep of the drilled tile.
/// Only counts when the drill itself is doing the mining, pickaxe work
/// with the fist stowed scatters ore like it always did.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw/proc/on_mined(mob/living/source, turf/rock, give_exp)
	SIGNAL_HANDLER
	if(organ_flags & ORGAN_FAILING)
		return
	if(!active_item || (active_item in src)) // drill stowed
		return
	addtimer(CALLBACK(src, PROC_REF(pocket_ore), rock), CYBERWARE_ROCKJAW_SWEEP_DELAY)

/// Hoover every ore stack off the drilled tile into the hopper, merging
/// into stacks we already hold.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw/proc/pocket_ore(turf/spot)
	if(QDELETED(src) || !owner || isnull(spot))
		return
	var/pocketed = FALSE
	for(var/obj/item/stack/ore/nugget in spot)
		var/merged = FALSE
		for(var/obj/item/stack/ore/held as anything in hopper)
			if(nugget.can_merge(held))
				nugget.merge(held)
				merged = TRUE
				break
		if(!merged && !QDELETED(nugget))
			nugget.forceMove(src)
			hopper += nugget
		pocketed = TRUE
	if(pocketed)
		owner.balloon_alert(owner, "ore pocketed")
		cyberware_ink_pulse(owner, CYBERWARE_INK_SOFT)

/// Toggle action = the toolkit deploy (parent); hopper action = the dump.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw/ui_action_click(mob/user, datum/action/action)
	if(istype(action, /datum/action/item_action/organ_action/rockjaw_hopper))
		dump_hopper()
		return
	return ..()

/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw/proc/dump_hopper()
	if(!length(hopper))
		owner.balloon_alert(owner, "hopper empty!")
		return
	var/turf/drop_turf = owner.drop_location()
	for(var/obj/item/stack/ore/nugget as anything in hopper.Copy())
		nugget.forceMove(drop_turf)
	hopper.Cut()
	owner.balloon_alert(owner, "hopper dumped")
	playsound(owner, 'sound/machines/click.ogg', 40, TRUE)
	cyberware_ink_pulse(owner, CYBERWARE_INK_SOFT)

// ---- 8. Fixer's Fingers ------------------------------------------------

/// The 25% tool-speed bonus Fixer's Fingers grants while installed.
/datum/actionspeed_modifier/cyberware_fixers
	multiplicative_slowdown = -0.25

/**
 * # Fixer's Fingers (T1, arm aug, load 2)
 *
 * The free printable toolset's premium cousin: cyborg screwdriver, wrench
 * and wirecutters fold out of the fingertips, and servo-assisted hands
 * run every timed action a quarter faster while the implant is in, the
 * speed is the part the fab can't print. The actionspeed modifier applies
 * whenever the ware is running, tools out or not; your hands are simply
 * better now (until an EMP or a brownout takes the servos offline).
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/fixers
	name = "\improper Fixer's Fingers"
	desc = "A fingertip omnitool suite. Driver, wrench and cutters fold out of the knuckles, and the servo tendons behind them run any tool job about a quarter faster than bare hands."
	icon_state = "fixers"
	chrome_load = 2
	tier = CYBERWARE_TIER_1
	actions_types = list(/datum/action/item_action/organ_action/toggle/toolkit)
	items_to_create = list(
		/obj/item/screwdriver/cyborg,
		/obj/item/wrench/cyborg,
		/obj/item/wirecutters/cyborg,
	)

// The tool-speed bonus rides the failing-gated passive layer (BAL-4): servo
// tendons with an EMP reboot or a brownout are just fingers until the ware
// comes back. Actionspeed modifiers are keyed by type, so add/remove is
// idempotent and needs no applied-state guard.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/fixers/chrome_passives_on(mob/living/carbon/bearer)
	. = ..()
	bearer?.add_actionspeed_modifier(/datum/actionspeed_modifier/cyberware_fixers)

/obj/item/organ/cyberimp/arm/toolkit/cyberware/fixers/chrome_passives_off(mob/living/carbon/bearer)
	. = ..()
	bearer?.remove_actionspeed_modifier(/datum/actionspeed_modifier/cyberware_fixers)

#undef CYBERWARE_ROCKJAW_SWEEP_DELAY

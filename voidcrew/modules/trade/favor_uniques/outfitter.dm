/**
 * # Outfitter favor uniques: Quartermain Depot's back-room stock
 *
 * Three one-of-a-kind rewards Sarge keeps for crews who've done real work for
 * the depot (see /datum/outpost_shop/outfitter in
 * voidcrew/modules/trade/shop_catalog_outfitter.dm). Late-round favor prizes:
 * polished, genuinely useful, none of them round-breaking. The shop SKUs
 * live with the rest of the outfitter catalog; this file is items only.
 *
 * Every item carries TRAIT_NO_REPLICATE (voidcrew/_DEFINES/loot.dm) so the
 * Helios pattern stamp (and any future duplicator) can never copy them.
 * Favor uniques stay unique.
 */

/**
 * # Skunkworks cell
 *
 * A high-capacity cell that slowly recharges itself. There's no self-charging
 * cell left in upstream tg. The mechanism lives on energy guns now
 * (selfcharge in code/modules/projectiles/guns/energy.dm), so this mirrors
 * that: SSobj processing that give()s a trickle each tick, with the same
 * post-charge bookkeeping the base power store does after a magic recharge
 * (rechamber a host gun, refresh the host's appearance).
 *
 * The trickle is deliberately far below the energy-gun rate
 * (STANDARD_ENERGY_GUN_SELF_CHARGE_RATE, 500 W): at 150 W it wins you a
 * laser shot back every six seconds or so, which keeps a tool or suit topped
 * up across a round but never out-paces swapping cells in a firefight.
 */
/obj/item/stock_parts/power_store/cell/skunkworks
	name = "skunkworks cell"
	desc = "A high-capacity power cell rebuilt around a radiothermal slug by somebody in a depot workshop. It trickle-charges itself off its own decay heat, so it never needs a charger. It just needs time."
	icon = 'voidcrew/icons/obj/favor_uniques.dmi'
	icon_state = "skunkworks_cell"
	maxcharge = STANDARD_CELL_CHARGE * 12 // PROVISIONAL BALANCE, above a high-capacity cell (10x), well below bluespace (40x)
	chargerate = STANDARD_CELL_RATE // PROVISIONAL BALANCE, a wall charger still beats waiting by a mile
	/// Watts fed back into the cell by its own radiothermal slug, every tick, wherever it is
	var/self_charge_rate = STANDARD_CELL_RATE * 0.015 // PROVISIONAL BALANCE, 150 W, ~13 minutes empty-to-full

/obj/item/stock_parts/power_store/cell/skunkworks/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)
	START_PROCESSING(SSobj, src)

/obj/item/stock_parts/power_store/cell/skunkworks/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/stock_parts/power_store/cell/skunkworks/examine(mob/user)
	. = ..()
	. += span_notice("It recharges itself slowly wherever it sits. A charger is still much faster.")

/obj/item/stock_parts/power_store/cell/skunkworks/process(seconds_per_tick)
	var/gained = give(self_charge_rate * seconds_per_tick)
	if(gained <= 0)
		return
	update_appearance()
	// Same bookkeeping the base power store runs after a magic recharge:
	// an empty energy gun should rechamber, and whatever we're inside may
	// have charge overlays of its own to refresh.
	if(isgun(loc))
		var/obj/item/gun/gun_loc = loc
		gun_loc.process_chamber()
	if(!ismob(loc))
		loc.update_appearance()

/**
 * # Fitter's gauntlets
 *
 * Subtypes the tinker's gloves (code/modules/clothing/gloves/special.dm) for
 * their sprite and their TRAIT_QUICK_BUILD pedigree, and adds
 * TRAIT_QUICKER_CARRY on top: both delivered through the stock
 * clothing_traits equip/drop hook, no custom plumbing.
 *
 * Honest coverage: TRAIT_QUICK_BUILD is the only real construction-speed
 * trait in this codebase. It speeds up plating girders and foamed-metal
 * walls (0.7x time) and every stack recipe flagged with it as a
 * trait_booster (wall girders, platforms, steps, at 0.75x). It does not
 * touch pipes, machine frames, or tool-driven deconstruction, tool speed
 * lives on the tool's own toolspeed var and has no clothing hook.
 * TRAIT_QUICKER_CARRY takes two full seconds off a fireman carry.
 */
/obj/item/clothing/gloves/tinkerer/fitter
	name = "fitter's gauntlets"
	desc = "Powered rigger's gloves with servo-assisted knuckles and a torque readout stitched into the cuff. Plating goes up faster in them than bare hands could ever manage, and the assist grip makes getting a casualty over your shoulders quicker too."
	// Safety orange through GAGS, so ground/worn/inhand all recolor together
	// (the parent tinker's gloves are brass #996e23)
	greyscale_colors = "#bf4e1e"
	clothing_traits = list(TRAIT_QUICK_BUILD, TRAIT_QUICKER_CARRY)

/obj/item/clothing/gloves/tinkerer/fitter/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/gloves/tinkerer/fitter/examine(mob/user)
	. = ..()
	. += span_notice("Walls, plating, and platforms go up noticeably faster while wearing these.")
	. += span_notice("The assist grip also makes carrying people over your shoulder much quicker.")

/**
 * # Prototype maneuvering harness
 *
 * Subtypes the oxygen jet harness (code/game/objects/items/tanks/jetpack.dm),
 * its own onboard gas reserve, refilled like any tank. Keeps the base
 * jetpack's full_speed = TRUE, so drifting on it carries no speed penalty
 * (/datum/movespeed_modifier/jetpack/full_speed), and the harness frame
 * means normal w_class with no wear slowdown.
 *
 * Handling beats everything printable: more than double the stock harness's
 * gas, stronger thrust and stabilization than a standard jetpack, and it
 * rides in the suit-storage slot like the captain's pack does. Still finite.
 * Run it dry in a red zone and you're drifting home the slow way.
 */
/obj/item/tank/jetpack/oxygen/harness/prototype
	name = "prototype maneuvering harness"
	desc = "A pre-production EVA maneuvering rig strapped around a compact oxygen reserve. The nozzles answer faster and push harder than anything on the open market, and the frame is light enough to forget you're wearing it."
	icon = 'voidcrew/icons/obj/favor_uniques.dmi'
	icon_state = "maneuver_harness" // jetpack code derives "maneuver_harness-on"
	slot_flags = ITEM_SLOT_BACK | ITEM_SLOT_SUITSTORE
	volume = 85 // PROVISIONAL BALANCE — stock harness is 40, standard jetpack 70, captain's steal-objective pack 90
	drift_force = 2 NEWTONS // PROVISIONAL BALANCE — standard jetpack is 1.5
	// The 2026 upstream merge dropped stabilizer_force: stabilization is now a plain
	// on/off (configure_jetpack's `stabilize`), with no separate force to tune. The
	// harness's "nozzles answer faster" edge lives entirely in drift_force now.

/obj/item/tank/jetpack/oxygen/harness/prototype/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/tank/jetpack/oxygen/harness/prototype/examine(mob/user)
	. = ..()
	. += span_notice("It moves you at full speed while drifting, and it fits in a suit's storage slot.")
	. += span_notice("The reserve refills like any oxygen tank.")

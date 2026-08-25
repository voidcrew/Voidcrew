/**
 * # MOD Fitting Bench
 *
 * The suit stall's centrepiece at Quartermain Depot: a powered frame you back
 * into while still wearing your MOD. The frame shuts, a UI comes up, and you
 * work on the suit without stripping it off.
 *
 * Four things happen here:
 * - Modules go in and come out for free, with no screwdriver and no complexity
 *   maths done by hand.
 * - Permanent upgrades are bought: plating, module capacity, actuator tuning,
 *   power regulation and cell swaps. Credits at the low rungs, vouchers at the
 *   top, same money plumbing as every other shop counter (see shop.dm).
 * - Servicing is bought per visit: repeatable jobs like shell reconditioning
 *   that fix the suit's state rather than permanently changing it.
 * - Paint, skins and engraving are free, and the frame trickle-charges the
 *   suit's cell the whole time it's shut.
 *
 * Deliberately NOT here: theme conversion. A civilian suit stays a civilian
 * suit; money makes it a better civilian suit.
 *
 * Occupancy uses the sealed-chamber idiom (open_machine/close_machine plus
 * GLOB.contained_state) rather than a step-on pad, because the chamber gets
 * every hard case for free: tgui's contained_state closes the window the
 * instant the occupant stops being inside us, and shared_ui_interaction closes
 * it when they log out and disables it when they drop unconscious. A pad would
 * need hand-rolled signal bookkeeping for all of that. It also matches the
 * neural imprinter next door, which is the same shape of machine.
 *
 * The suit is never cached. Every read and every action re-resolves it off the
 * occupant, so a suit that gets stripped, dropped or deleted mid-session just
 * stops being there.
 */

/// Paint colours the bench can spray, name -> hex. The UI sends the name.
GLOBAL_LIST_INIT(modsuit_bench_paints, list(
	"Ash" = "#4c4c52",
	"Bone" = "#d8d2c2",
	"Rust" = "#8f4b2a",
	"Hazard" = "#d4a02a",
	"Forest" = "#3f6b3a",
	"Deep Blue" = "#2f4f7a",
	"Plum" = "#5a3a6b",
	"Crimson" = "#8f2b2b",
))

/// Cached base64 skin previews for the UI, keyed "[theme type]-[skin name]".
GLOBAL_LIST_EMPTY(modsuit_bench_skin_icons)

/// Every bench upgrade as a singleton, id -> datum, in ladder order.
GLOBAL_LIST_INIT(modsuit_bench_upgrades, build_modsuit_bench_upgrades())

/proc/build_modsuit_bench_upgrades()
	var/list/built = list()
	for(var/datum/mod_upgrade/upgrade_type as anything in subtypesof(/datum/mod_upgrade))
		if(!initial(upgrade_type.id))
			continue // abstract rung of the tree
		var/datum/mod_upgrade/upgrade = new upgrade_type
		built[upgrade.id] = upgrade
	return built

/**
 * # MOD upgrade record
 *
 * Which bench upgrades a given suit has already bought. Lives on the suit as a
 * component rather than as vars on /obj/item/mod/control, so the record travels
 * with the suit between benches, outposts and owners, and dies with it, a
 * list on the machine would forget everything the moment you shopped somewhere
 * else, and an element is a shared singleton with nowhere to put per-suit state.
 */
/datum/component/mod_upgrades
	/// Upgrade id -> TRUE for everything this suit has bought.
	var/list/purchased = list()

/datum/component/mod_upgrades/Initialize()
	if(!istype(parent, /obj/item/mod/control))
		return COMPONENT_INCOMPATIBLE

/**
 * # MOD upgrade
 *
 * One purchasable, permanent modification. Singletons: all per-suit state
 * lives in the /datum/component/mod_upgrades record on the suit itself.
 */
/datum/mod_upgrade
	/// Stable key for the UI and the purchase record. Never reuse an id.
	var/id
	/// Display name
	var/name
	/// One or two plain sentences. Say the numbers.
	var/desc
	/// UI grouping tab
	var/category = "Plating"
	/// Price in credits (0 = credits play no part)
	var/price_credits = 0
	/// Price in trade vouchers (0 = vouchers play no part)
	var/price_vouchers = 0
	/// id of the upgrade that has to be installed first, if any
	var/requires
	/// A service rather than a modification: charged every time, never recorded
	/// on the suit, never shows as installed.
	var/repeatable = FALSE

/**
 * Human-readable price tag, e.g. "1 voucher + 900 cr".
 */
/datum/mod_upgrade/proc/get_price_text()
	var/list/parts = list()
	if(price_vouchers > 0)
		parts += "[price_vouchers] voucher[price_vouchers > 1 ? "s" : ""]"
	if(price_credits > 0)
		parts += "[price_credits] cr"
	if(!length(parts))
		return "free"
	return parts.Join(" + ")

/**
 * Whether this suit already has the upgrade. Defaults to the purchase record;
 * subtypes that can read the answer off the suit directly override it.
 */
/datum/mod_upgrade/proc/is_installed(obj/item/mod/control/mod)
	var/datum/component/mod_upgrades/record = mod.GetComponent(/datum/component/mod_upgrades)
	if(!record)
		return FALSE
	return !isnull(record.purchased[id])

/**
 * Why this suit can't take the upgrade right now, or null if it can.
 */
/datum/mod_upgrade/proc/get_denial(obj/item/mod/control/mod)
	if(is_installed(mod))
		return "Already installed."
	if(requires)
		var/datum/mod_upgrade/prerequisite = GLOB.modsuit_bench_upgrades[requires]
		if(prerequisite && !prerequisite.is_installed(mod))
			return "Needs [prerequisite.name] first."
	return null

/**
 * Whether the buyer can cover the price right now. Does not charge.
 */
/datum/mod_upgrade/proc/can_afford(mob/living/user, datum/bank_account/account)
	if(price_vouchers > 0 && count_trade_vouchers(user) < price_vouchers)
		return FALSE
	if(price_credits > 0 && (!account || !account.has_money(price_credits)))
		return FALSE
	return TRUE

/**
 * Mutates the live suit. Returns TRUE if anything actually changed; a FALSE
 * here refunds the buyer.
 */
/datum/mod_upgrade/proc/apply(obj/item/mod/control/mod, mob/living/user)
	return FALSE

// --- Plating ------------------------------------------------------------

/**
 * Armor is a datum in this codebase, not a list. The supported way to bend one
 * is generate_new_with_modifiers(), which hands back a fresh /datum/armor with
 * our deltas folded in; set_armor() then cleans up the old generated datum and
 * leaves cached theme armor alone. /datum/armor/immune returns itself from
 * that call, so anything genuinely unhittable stays unhittable.
 */
/datum/mod_upgrade/plating
	category = "Plating"
	/// Armor rating -> points added, passed straight to generate_new_with_modifiers()
	var/list/armor_modifiers = list()

/datum/mod_upgrade/plating/apply(obj/item/mod/control/mod, mob/living/user)
	if(!length(armor_modifiers))
		return FALSE
	// all = TRUE so the control unit itself is plated too, matching how the
	// theme armors the suit in set_up_parts().
	for(var/obj/item/part as anything in mod.get_parts(all = TRUE))
		part.set_armor(part.get_armor().generate_new_with_modifiers(armor_modifiers))
	return TRUE

/datum/mod_upgrade/plating/ablative
	id = "plating_ablative"
	name = "Ablative plating"
	desc = "Bonded panels over the shell. Adds 5 melee, bullet, laser and energy armor."
	price_credits = 300
	armor_modifiers = list(MELEE = 5, BULLET = 5, LASER = 5, ENERGY = 5)

/datum/mod_upgrade/plating/reinforced
	id = "plating_reinforced"
	name = "Reinforced plating"
	desc = "A second layer with a blast liner under it. Another 5 to the four combat ratings, plus 10 bomb."
	price_credits = 800
	requires = "plating_ablative"
	armor_modifiers = list(MELEE = 5, BULLET = 5, LASER = 5, ENERGY = 5, BOMB = 10)

/datum/mod_upgrade/plating/composite
	id = "plating_composite"
	name = "Composite plating"
	desc = "Ceramic composite across the whole shell. Another 5 to the four combat ratings, plus 5 wound resistance."
	price_credits = 900
	price_vouchers = 1
	requires = "plating_reinforced"
	armor_modifiers = list(MELEE = 5, BULLET = 5, LASER = 5, ENERGY = 5, WOUND = 5)

// --- Module capacity ----------------------------------------------------

/datum/mod_upgrade/capacity
	category = "Capacity"
	/// Points of module complexity this adds to the suit's ceiling
	var/complexity_bonus = 2

/datum/mod_upgrade/capacity/apply(obj/item/mod/control/mod, mob/living/user)
	mod.complexity_max += complexity_bonus
	// The suit's own TGUI keeps complexity_max in static data, so nudge it.
	mod.update_static_data_for_all_viewers()
	return TRUE

/datum/mod_upgrade/capacity/expanded
	id = "capacity_expanded"
	name = "Expanded module bus"
	desc = "Extra sockets soldered onto the control unit. Raises module capacity by 2."
	price_credits = 400
	complexity_bonus = 2

/datum/mod_upgrade/capacity/rewired
	id = "capacity_rewired"
	name = "Rewired module bus"
	desc = "The control unit's whole harness, replaced. Raises module capacity by another 4."
	price_credits = 600
	price_vouchers = 1
	requires = "capacity_expanded"
	complexity_bonus = 4

// --- Actuators ----------------------------------------------------------

/datum/mod_upgrade/servo
	id = "servo_tuning"
	name = "Servo tuning"
	desc = "Rebalances the leg and back actuators. Takes 0.25 off the suit's slowdown while it's sealed."
	category = "Actuators"
	price_credits = 500
	/// How much slowdown_deployed this shaves off, floored at zero
	var/slowdown_reduction = 0.25

/datum/mod_upgrade/servo/get_denial(obj/item/mod/control/mod)
	. = ..()
	if(.)
		return .
	if(mod.slowdown_deployed <= 0)
		return "This suit already moves at full speed."
	return null

/datum/mod_upgrade/servo/apply(obj/item/mod/control/mod, mob/living/user)
	mod.slowdown_deployed = max(mod.slowdown_deployed - slowdown_reduction, 0)
	mod.update_speed()
	return TRUE

/datum/mod_upgrade/servo/overdrive
	id = "servo_overdrive"
	name = "Actuator overdrive"
	desc = "Replaces the actuators outright rather than tuning them. Takes another 0.25 off the sealed slowdown."
	price_credits = 700
	price_vouchers = 1
	requires = "servo_tuning"

/datum/mod_upgrade/servo/suspension
	id = "servo_suspension"
	name = "Magnetic suspension"
	desc = "Floats the frame's whole weight on magnetic bearings instead of your hips. Another 0.25 off the sealed slowdown."
	price_credits = 1600
	price_vouchers = 2
	requires = "servo_overdrive"

/**
 * The ladder's capstone clears whatever slowdown is left rather than another
 * fixed slice, so a heavy chassis gets a real payoff at the end of the climb
 * instead of needing rungs that don't exist. Light suits usually hit zero on
 * the cheap rungs first and are refused this one, the denial from the servo
 * parent handles that.
 */
/datum/mod_upgrade/servo/nullweight
	id = "servo_nullweight"
	name = "Nullweight rebuild"
	desc = "The bay strips the suit to the frame and rebuilds every joint to carry itself. Removes all of the suit's remaining sealed slowdown, however much that is."
	price_credits = 4000
	price_vouchers = 5
	requires = "servo_suspension"

/datum/mod_upgrade/servo/nullweight/apply(obj/item/mod/control/mod, mob/living/user)
	mod.slowdown_deployed = 0
	mod.update_speed()
	return TRUE

/**
 * Seal tuning works on the suit's own step time rather than a flat delta, so a
 * sluggish civilian frame gains more real seconds than a nimble one. Themes
 * that already seal in half the standard time or better (rescue, apocalypse
 * ready) are refused instead of shaved further.
 */
/datum/mod_upgrade/seal
	id = "seal_tuning"
	name = "Seal tuning"
	desc = "Recalibrates the part clamps. Every piece of the suit deploys and seals in half the time."
	category = "Actuators"
	price_credits = 350

/datum/mod_upgrade/seal/get_denial(obj/item/mod/control/mod)
	. = ..()
	if(.)
		return .
	if(mod.activation_step_time <= MOD_ACTIVATION_STEP_TIME * 0.5)
		return "This suit already seals faster than the bench's tooling can manage."
	return null

/datum/mod_upgrade/seal/apply(obj/item/mod/control/mod, mob/living/user)
	mod.activation_step_time *= 0.5
	return TRUE

// --- Power --------------------------------------------------------------

/datum/mod_upgrade/efficiency
	id = "cell_efficiency"
	name = "Draw regulator"
	desc = "A smarter regulator between the core and the hardware. Cuts the suit's standing power draw by 25%."
	category = "Power"
	price_credits = 400
	/// Multiplier applied to charge_drain
	var/drain_multiplier = 0.75

/datum/mod_upgrade/efficiency/apply(obj/item/mod/control/mod, mob/living/user)
	mod.charge_drain = round(mod.charge_drain * drain_multiplier, 0.01)
	return TRUE

/datum/mod_upgrade/efficiency/superconductive
	id = "cell_superconductive"
	name = "Superconductive harness"
	desc = "Rewires the whole power train in superconductor. Cuts the standing draw by another 25%."
	price_credits = 800
	price_vouchers = 1
	requires = "cell_efficiency"

// --- Servicing ----------------------------------------------------------

/**
 * Suit shells shred zone by zone under fire (see clothing.dm take_damage_zone),
 * and a shredded part stops armoring the limb entirely. The normal fix is
 * patching each piece by hand with cloth; the bench does the whole shell in
 * one paid job. Repeatable. It repairs state, it doesn't add anything.
 */
/datum/mod_upgrade/recondition
	id = "recondition"
	name = "Shell recondition"
	desc = "Hammers out, patches and reseals every part of the shell, however bad it's gotten. Charged per visit."
	category = "Servicing"
	price_credits = 200
	repeatable = TRUE

/datum/mod_upgrade/recondition/proc/part_needs_work(obj/item/part)
	if(part.uses_integrity && part.atom_integrity < part.max_integrity)
		return TRUE
	var/obj/item/clothing/cloth = part
	if(istype(cloth) && (cloth.damaged_clothes || LAZYLEN(cloth.damage_by_parts)))
		return TRUE
	return FALSE

/datum/mod_upgrade/recondition/get_denial(obj/item/mod/control/mod)
	. = ..()
	if(.)
		return .
	for(var/obj/item/part as anything in mod.get_parts(all = TRUE))
		if(part_needs_work(part))
			return null
	return "Nothing on this suit needs mending."

/datum/mod_upgrade/recondition/apply(obj/item/mod/control/mod, mob/living/user)
	var/fixed_anything = FALSE
	for(var/obj/item/part as anything in mod.get_parts(all = TRUE))
		if(!part_needs_work(part))
			continue
		fixed_anything = TRUE
		var/obj/item/clothing/cloth = part
		if(istype(cloth))
			// Full clothing repair: integrity, per-limb damage, covered zones.
			// The wearer goes along so the shredded-zone movement warning
			// (bristle) is unregistered from them.
			cloth.repair(mod.wearer)
			// repair() and the damage prefixes both reset to initial(name),
			// which loses the theme prefix set_up_parts stitched on. Rebuild it
			// the same way. repair() also never resets the zone counter, so a
			// reconditioned part would skip straight to "mangy" next time.
			cloth.name = "[mod.theme.name] [initial(cloth.name)]"
			cloth.zones_disabled = 0
		else if(part.uses_integrity)
			part.repair_damage(part.max_integrity)
	return fixed_anything

/**
 * Cell swaps read "installed" straight off the core instead of off the
 * purchase record, so a suit that shipped with a big cell doesn't get offered
 * a downgrade it would then be charged for.
 */
/datum/mod_upgrade/cell
	category = "Power"
	/// The cell fitted by this rung
	var/obj/item/stock_parts/power_store/cell/cell_path

/datum/mod_upgrade/cell/is_installed(obj/item/mod/control/mod)
	var/obj/item/mod/core/standard/core = mod.core
	if(!istype(core) || !core.cell)
		return FALSE
	return core.cell.maxcharge >= initial(cell_path.maxcharge)

/datum/mod_upgrade/cell/get_denial(obj/item/mod/control/mod)
	var/obj/item/mod/core/standard/core = mod.core
	if(!istype(core))
		return "This core doesn't run off a power cell."
	if(!core.cell)
		return "There's no cell in the core to swap out."
	return ..()

/datum/mod_upgrade/cell/apply(obj/item/mod/control/mod, mob/living/user)
	var/obj/item/mod/core/standard/core = mod.core
	if(!istype(core) || !core.cell)
		return FALSE
	// Leaving the core fires its Exited(), which clears core.cell for us.
	var/obj/item/stock_parts/power_store/old_cell = core.cell
	old_cell.forceMove(mod.drop_location())
	user?.put_in_hands(old_cell)
	core.install_cell(new cell_path(null))
	mod.update_charge_alert()
	return TRUE

/datum/mod_upgrade/cell/high
	id = "cell_high"
	name = "High-capacity cell"
	desc = "Swaps the core's cell for a high-capacity one. Ten times a standard cell's charge. The old cell comes back to you."
	price_credits = 400
	cell_path = /obj/item/stock_parts/power_store/cell/high

/datum/mod_upgrade/cell/super
	id = "cell_super"
	name = "Super-capacity cell"
	desc = "Twenty times a standard cell's charge, and it recharges faster than the high-capacity."
	price_credits = 900
	cell_path = /obj/item/stock_parts/power_store/cell/super

/datum/mod_upgrade/cell/hyper
	id = "cell_hyper"
	name = "Hyper-capacity cell"
	desc = "Thirty times a standard cell's charge. About as much as anyone sells over a counter."
	price_credits = 1200
	price_vouchers = 1
	cell_path = /obj/item/stock_parts/power_store/cell/hyper

/datum/mod_upgrade/cell/bluespace
	id = "cell_bluespace"
	name = "Bluespace cell"
	desc = "Forty times a standard cell's charge, on the fastest recharge curve made. Priced accordingly."
	price_credits = 1500
	price_vouchers = 3
	cell_path = /obj/item/stock_parts/power_store/cell/bluespace

// --- The bench ----------------------------------------------------------

/obj/machinery/modsuit_bench
	name = "MOD fitting bench"
	desc = "A powered frame you back into while still wearing your suit. It swaps modules, bolts on plating and repaints the shell without you taking anything off."
	// Reused sprite: the oldstation MOD installator frame, which already has
	// open/shut states and status lamps and is the only MODsuit-themed piece of
	// machinery art in the tree. 32x64, single dir, so no directional subtypes.
	icon = 'icons/obj/machines/mod_installer.dmi'
	icon_state = "mod_installer_open"
	base_icon_state = "mod_installer"
	layer = ABOVE_WINDOW_LAYER
	anchored = TRUE
	density = FALSE // dense only while the frame is shut
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	occupant_typecache = list(/mob/living/carbon/human)
	state_open = TRUE
	// Only opens for the occupant, and works while they're lying down
	interaction_flags_atom = parent_type::interaction_flags_atom | INTERACT_ATOM_IGNORE_MOBILITY
	// Only processes while the frame is shut on someone; close_machine starts it
	processing_flags = NONE

/obj/machinery/modsuit_bench/Initialize(mapload)
	. = ..()
	update_appearance()

/obj/machinery/modsuit_bench/Destroy()
	if(occupant)
		dump_inventory_contents()
	return ..()

/obj/machinery/modsuit_bench/examine(mob/user)
	. = ..()
	. += span_notice("Step in wearing a MOD control unit, then click the frame to shut it.")
	. += span_notice("Module swaps, paint and engraving are free. Plating, module capacity, actuator work, cell swaps and shell repairs are paid: credits off your ID, vouchers off your person.")
	. += span_notice("The frame charges the suit's cell the whole time it's shut.")

// --- Occupancy ----------------------------------------------------------

// Only usable by the person inside. Closes itself the moment they aren't.
/obj/machinery/modsuit_bench/ui_state(mob/user)
	return GLOB.contained_state

/obj/machinery/modsuit_bench/relaymove(mob/living/user, direction)
	open_machine()

// No lock on the frame; resisting pops it without having to walk out.
/obj/machinery/modsuit_bench/container_resist_act(mob/living/user)
	open_machine()

/obj/machinery/modsuit_bench/Exited(atom/movable/gone, direction)
	. = ..()
	// Anything that yanks the occupant out without going through us, a
	// teleport, a gib, an admin. Would otherwise leave a dangling ref.
	if(gone == occupant)
		set_occupant(null)
		update_appearance()

/obj/machinery/modsuit_bench/open_machine(drop = TRUE, density_to_set = FALSE)
	end_processing()
	return ..()

/obj/machinery/modsuit_bench/close_machine(atom/movable/target, density_to_set = TRUE)
	. = ..()
	if(!occupant)
		return .
	if(!get_suit())
		balloon_alert(occupant, "no MOD detected!")
		playsound(src, 'sound/machines/scanner/scanbuzz.ogg', 25, TRUE)
		open_machine()
		return .
	begin_processing()
	ui_interact(occupant)
	return .

/**
 * While the frame is shut it trickle-charges the suit's core off the outpost
 * grid, at the cell's own charge rate. The same pit-stop treatment a wall
 * charger gives a handheld.
 */
/obj/machinery/modsuit_bench/process(seconds_per_tick)
	if(!occupant)
		return PROCESS_KILL
	var/obj/item/mod/control/mod = get_suit()
	if(!mod)
		return
	var/obj/item/stock_parts/power_store/source = mod.get_charge_source()
	if(!istype(source) || source.charge >= source.maxcharge)
		return
	mod.add_charge(source.chargerate * seconds_per_tick)

/// Whether the frame is actively putting charge into the occupant's suit.
/obj/machinery/modsuit_bench/proc/is_charging_suit()
	if(state_open)
		return FALSE
	var/obj/item/mod/control/mod = get_suit()
	if(!mod)
		return FALSE
	var/obj/item/stock_parts/power_store/source = mod.get_charge_source()
	return istype(source) && source.charge < source.maxcharge

/obj/machinery/modsuit_bench/interact(mob/user)
	// Machinery carries INTERACT_ATOM_UI_INTERACT, so the parent chain opens
	// the window on its own. Only the occupant should ever get that far.
	if(user == occupant)
		return ..()
	add_fingerprint(user)
	if(state_open && !get_worn_control(user))
		balloon_alert(user, "not wearing a MOD!")
		playsound(src, 'sound/machines/scanner/scanbuzz.ogg', 25, TRUE)
		return FALSE
	state_open ? close_machine() : open_machine()
	return TRUE

/**
 * The MOD control unit a given mob is wearing, or null. Never cached, the
 * suit can be stripped, dropped or destroyed at any point in a session.
 */
/obj/machinery/modsuit_bench/proc/get_worn_control(mob/living/carbon/human/target)
	RETURN_TYPE(/obj/item/mod/control)
	if(!istype(target))
		return null
	for(var/obj/item/mod/control/mod in target.get_equipped_items())
		if(mod.wearer == target)
			return mod
	return null

/// The occupant's suit, if they're in here wearing one.
/obj/machinery/modsuit_bench/proc/get_suit()
	RETURN_TYPE(/obj/item/mod/control)
	return get_worn_control(occupant)

/**
 * Why install() would refuse this module on this suit, or null if it wouldn't.
 * Mirrors install()'s checks in its order (mod_control.dm), because install()
 * itself only reports failure as a balloon on the suit, from inside the frame
 * the occupant would just hear a buzz with no reason attached.
 */
/obj/machinery/modsuit_bench/proc/get_module_denial(obj/item/mod/control/mod, obj/item/mod/module/module)
	for(var/obj/item/mod/module/other as anything in mod.modules)
		if(is_type_in_list(module, other.incompatible_modules) || is_type_in_list(other, module.incompatible_modules))
			return "Incompatible with the installed [other.name]."
	if(mod.complexity + module.complexity > mod.complexity_max)
		return "Needs [mod.complexity + module.complexity - mod.complexity_max] more module capacity."
	if(!module.has_required_parts(mod.mod_parts))
		return "This suit doesn't have the parts it mounts to."
	if(!module.can_install(mod))
		return "Won't take on this suit."
	return null

/// The bank account on the occupant's ID card.
/obj/machinery/modsuit_bench/proc/get_occupant_account()
	RETURN_TYPE(/datum/bank_account)
	var/mob/living/carbon/human/human_occupant = occupant
	if(!istype(human_occupant))
		return null
	var/obj/item/card/id/id_card = human_occupant.get_idcard(TRUE)
	return id_card?.registered_account

// --- Icon ---------------------------------------------------------------

/obj/machinery/modsuit_bench/update_icon_state()
	icon_state = "[base_icon_state][state_open ? "_open" : ""]"
	return ..()

/obj/machinery/modsuit_bench/update_overlays()
	. = ..()
	. += (!state_open && get_suit()) ? "green" : "red"

// --- Purchases ----------------------------------------------------------

/**
 * Validates, charges and applies one upgrade. Payment mirrors
 * /datum/shop_sku/try_purchase(): the credit half is checked before any
 * vouchers are consumed, so a half-paid purchase can't happen.
 */
/obj/machinery/modsuit_bench/proc/try_buy_upgrade(mob/living/carbon/human/user, obj/item/mod/control/mod, datum/mod_upgrade/upgrade)
	var/denial = upgrade.get_denial(mod)
	if(denial)
		balloon_alert(user, "unavailable!")
		to_chat(user, span_warning("[denial]"))
		return FALSE

	var/datum/bank_account/account
	if(upgrade.price_credits > 0)
		account = get_occupant_account()
		if(!account)
			balloon_alert(user, "no ID account!")
			return FALSE
		if(!account.has_money(upgrade.price_credits))
			balloon_alert(user, "needs [upgrade.price_credits] cr!")
			return FALSE
	if(upgrade.price_vouchers > 0 && count_trade_vouchers(user) < upgrade.price_vouchers)
		balloon_alert(user, "needs [upgrade.price_vouchers] voucher[upgrade.price_vouchers > 1 ? "s" : ""]!")
		return FALSE

	if(upgrade.price_vouchers > 0 && !consume_trade_vouchers(user, upgrade.price_vouchers))
		return FALSE
	if(upgrade.price_credits > 0 && !account.adjust_money(-upgrade.price_credits, "MOD Fitting Bench: [upgrade.name]"))
		return FALSE

	if(!upgrade.apply(mod, user))
		// Nothing changed on the suit, so hand the money back rather than eat it.
		if(upgrade.price_credits > 0)
			account.adjust_money(upgrade.price_credits, "MOD Fitting Bench: refund")
		if(upgrade.price_vouchers > 0)
			new /obj/item/stack/trade_voucher(drop_location(), upgrade.price_vouchers)
		balloon_alert(user, "fitting failed!")
		return FALSE

	if(!upgrade.repeatable)
		var/datum/component/mod_upgrades/record = mod.LoadComponent(/datum/component/mod_upgrades)
		record.purchased[upgrade.id] = TRUE

	playsound(src, 'sound/items/tools/rped.ogg', 40, TRUE)
	balloon_alert(user, "[upgrade.name] [upgrade.repeatable ? "done" : "fitted"]")
	user.log_message("bought MOD bench upgrade '[upgrade.id]' for [mod] at [upgrade.get_price_text()]", LOG_GAME)
	return TRUE

// --- UI -----------------------------------------------------------------

/obj/machinery/modsuit_bench/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ModsuitBench", name)
		ui.open()

/obj/machinery/modsuit_bench/ui_data(mob/user)
	var/list/data = list()
	var/mob/living/carbon/human/human_occupant = occupant
	data["has_occupant"] = istype(human_occupant)

	var/list/paints = list()
	for(var/paint_name in GLOB.modsuit_bench_paints)
		paints += list(list(
			"name" = paint_name,
			"hex" = GLOB.modsuit_bench_paints[paint_name],
		))
	data["paints"] = paints

	var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
	data["barred"] = outpost?.is_user_barred(human_occupant) ? TRUE : FALSE

	var/datum/bank_account/account = get_occupant_account()
	data["account_credits"] = account ? account.account_balance : null
	data["held_vouchers"] = istype(human_occupant) ? count_trade_vouchers(human_occupant) : 0

	var/obj/item/mod/control/mod = get_suit()
	data["has_suit"] = !!mod
	if(!mod)
		return data

	data["suit"] = list(
		"name" = mod.name,
		"theme" = mod.theme.name,
		"skin" = mod.skin,
		"sealed" = (mod.active || mod.activating) ? TRUE : FALSE,
		"complexity" = mod.complexity,
		"complexity_max" = mod.complexity_max,
		"charge_drain" = round(mod.charge_drain, 0.01),
		"slowdown" = mod.slowdown_deployed,
		"seal_time" = round(mod.activation_step_time / (1 SECONDS), 0.1),
		"core_name" = mod.core?.name,
		"charge_text" = mod.get_chargebar_string(),
	)
	data["charging"] = is_charging_suit() ? TRUE : FALSE

	var/list/installed_modules = list()
	for(var/obj/item/mod/module/module as anything in mod.modules)
		installed_modules += list(list(
			"ref" = REF(module),
			"name" = module.name,
			"desc" = module.desc,
			"complexity" = module.complexity,
			"removable" = module.removable ? TRUE : FALSE,
		))
	data["installed_modules"] = installed_modules

	// "Loose" means anything the occupant brought in with them, hands, belt,
	// bag. There is no separate hopper on the bench to lose modules inside.
	var/list/loose_modules = list()
	for(var/obj/item/mod/module/module in human_occupant.get_all_contents())
		if(module.mod)
			continue
		loose_modules += list(list(
			"ref" = REF(module),
			"name" = module.name,
			"desc" = module.desc,
			"complexity" = module.complexity,
			"denial" = get_module_denial(mod, module),
		))
	data["loose_modules"] = loose_modules

	var/list/upgrades = list()
	for(var/upgrade_id in GLOB.modsuit_bench_upgrades)
		var/datum/mod_upgrade/upgrade = GLOB.modsuit_bench_upgrades[upgrade_id]
		upgrades += list(list(
			"id" = upgrade.id,
			"name" = upgrade.name,
			"desc" = upgrade.desc,
			"category" = upgrade.category,
			"price_text" = upgrade.get_price_text(),
			"price_credits" = upgrade.price_credits,
			"price_vouchers" = upgrade.price_vouchers,
			"repeatable" = upgrade.repeatable ? TRUE : FALSE,
			"installed" = upgrade.is_installed(mod) ? TRUE : FALSE,
			"denial" = upgrade.get_denial(mod),
			"affordable" = upgrade.can_afford(human_occupant, account) ? TRUE : FALSE,
		))
	data["upgrades"] = upgrades

	var/list/skins = list()
	for(var/skin_name in mod.theme.variants)
		skins += list(list(
			"skin" = skin_name,
			"icon" = get_skin_icon(mod, skin_name),
			"current" = (skin_name == mod.skin) ? TRUE : FALSE,
		))
	data["skins"] = skins

	return data

/**
 * Base64 preview of one of the theme's skins, cached globally, the icon()
 * call is far too expensive to redo every UI tick.
 */
/obj/machinery/modsuit_bench/proc/get_skin_icon(obj/item/mod/control/mod, skin_name)
	var/key = "[mod.theme.type]-[skin_name]"
	var/cached = GLOB.modsuit_bench_skin_icons[key]
	if(cached)
		return cached
	var/list/variant = mod.theme.variants[skin_name]
	// Same fallback set_skin() uses, rather than mod.icon, which may already
	// have been swapped out by whatever skin is on the suit now.
	var/icon_file = variant?[MOD_ICON_OVERRIDE] || 'icons/obj/clothing/modsuit/mod_clothing.dmi'
	cached = icon2base64(icon(icon_file, "[skin_name]-control", SOUTH, frame = 1))
	GLOB.modsuit_bench_skin_icons[key] = cached
	return cached

/obj/machinery/modsuit_bench/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	// Taken off the ui, never off a tracked var. Ui.close() nulls those.
	var/mob/acting = ui.user
	if(acting != occupant)
		return TRUE

	if(action == "open_frame")
		open_machine()
		return TRUE

	var/mob/living/carbon/human/user = occupant
	var/obj/item/mod/control/mod = get_suit()
	if(!mod)
		balloon_alert(user, "no MOD detected!")
		return TRUE

	var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
	if(outpost?.is_user_barred(user))
		outpost.trader?.speak_line(TRADER_LINE_REFUSAL)
		balloon_alert(user, "trade embargo!")
		return TRUE

	if(mod.active || mod.activating)
		balloon_alert(user, "suit is sealed!")
		return TRUE

	switch(action)
		if("install_module")
			// install() does the compatibility, complexity, parts and
			// can_install checks and moves the module in itself, so nothing
			// gets stranded inside the suit when it refuses.
			var/obj/item/mod/module/module = locate(params["ref"]) in user.get_all_contents()
			if(!istype(module) || module.mod)
				return TRUE
			mod.install(module, user)
			if(module.mod == mod)
				SEND_SIGNAL(mod, COMSIG_MOD_MODULE_ADDED, user)
			return TRUE

		if("remove_module")
			var/obj/item/mod/module/module = locate(params["ref"]) in mod.modules
			if(!istype(module))
				return TRUE
			if(!module.removable)
				balloon_alert(user, "fixed in place!")
				return TRUE
			if(SEND_SIGNAL(mod, COMSIG_MOD_MODULE_REMOVAL, user) & MOD_CANCEL_REMOVAL)
				balloon_alert(user, "removal blocked!")
				playsound(src, 'sound/machines/scanner/scanbuzz.ogg', 25, TRUE)
				return TRUE
			mod.uninstall(module)
			module.forceMove(drop_location())
			user.put_in_hands(module)
			balloon_alert(user, "[module.name] removed")
			playsound(src, 'sound/machines/click.ogg', 50, TRUE)
			SEND_SIGNAL(mod, COMSIG_MOD_MODULE_REMOVED, user)
			return TRUE

		if("buy_upgrade")
			var/datum/mod_upgrade/upgrade = GLOB.modsuit_bench_upgrades[params["id"]]
			if(!upgrade)
				return TRUE
			try_buy_upgrade(user, mod, upgrade)
			return TRUE

		if("set_skin")
			var/skin = params["skin"]
			if(!(skin in mod.theme.variants) || skin == mod.skin)
				return TRUE
			mod.theme.set_skin(mod, skin)
			balloon_alert(user, "refitted")
			playsound(src, 'sound/machines/click.ogg', 50, TRUE)
			return TRUE

		if("set_paint")
			// The client sends the swatch name; the hex is looked up here.
			var/hex = GLOB.modsuit_bench_paints[params["paint"]]
			if(!hex)
				return TRUE
			mod.set_mod_color(hex)
			balloon_alert(user, "painted")
			playsound(src, 'sound/effects/spray.ogg', 40, TRUE)
			return TRUE

		if("custom_paint")
			// The picker blocks until the client answers, so everything checked
			// above has to be re-checked below. They can step out, strip the
			// suit or seal it while the dialog sits open.
			var/hex = input(user, "Pick a paint colour", name, mod.color || COLOR_WHITE) as color|null
			if(!hex || QDELETED(src) || QDELETED(mod) || user != occupant || mod != get_suit())
				return TRUE
			if(mod.active || mod.activating)
				balloon_alert(user, "suit is sealed!")
				return TRUE
			mod.set_mod_color(hex)
			balloon_alert(user, "painted")
			playsound(src, 'sound/effects/spray.ogg', 40, TRUE)
			return TRUE

		if("rename")
			var/new_name = tgui_input_text(user, "Engrave a new designation", name, mod.name, max_length = MAX_NAME_LEN)
			if(!new_name || QDELETED(src) || QDELETED(mod) || user != occupant || mod != get_suit())
				return TRUE
			new_name = trim(new_name)
			if(!new_name)
				return TRUE
			mod.name = new_name
			balloon_alert(user, "engraved")
			playsound(src, 'sound/machines/click.ogg', 50, TRUE)
			user.log_message("engraved MOD control unit as '[new_name]' at the fitting bench", LOG_GAME)
			return TRUE

		if("clear_paint")
			if(HAS_TRAIT(mod, TRAIT_SPEED_POTIONED))
				balloon_alert(user, "won't come off!")
				return TRUE
			for(var/obj/item/part as anything in mod.get_parts(all = TRUE))
				part.remove_atom_colour(FIXED_COLOUR_PRIORITY)
			mod.wearer?.regenerate_icons()
			balloon_alert(user, "paint stripped")
			playsound(src, 'sound/effects/spray.ogg', 40, TRUE)
			return TRUE

	return TRUE

// --- Outpost aggression -------------------------------------------------

// Attacking outpost property is aggression, the bench included.
/obj/machinery/modsuit_bench/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force)
		var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
		outpost?.register_aggression(user)
	return ..()

/obj/machinery/modsuit_bench/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE, blocked = 0)
	if(isliving(hitting_projectile.firer))
		var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
		outpost?.register_aggression(hitting_projectile.firer)
	return ..()

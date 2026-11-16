/**
 * # Chrome test kit
 *
 * One admin verb for trying the cyberware lines without a shopping trip. It drops a Chrome
 * Cradle beside the admin with a stack of trade vouchers and a holochip of credits, then offers
 * a short list of ready-made builds (see GLOB.chrome_test_loadouts) that either go straight into
 * the admin's own body or into a crate at their feet, plus a chromed human to point Chrome Read
 * at. The dummy is a human NPC body (voidcrew/modules/human_npcs/) with no
 * AI, so it is the same kind of body as the NPCs players meet: its chrome works, and burns out
 * to scrap when it dies or a piece leaves it.
 *
 * Installs here are special inserts, the same door the unit tests use: no cradle sequence, no
 * boot splash, no install context. They still obey the body's rules in two ways. A piece whose
 * limb is missing is not forced into a body that cannot hold it, and a piece that would push the
 * body past its neural capacity goes into the crate instead of browning the whole build out
 * (the Cascade and Redline cores share the OS slot with the Governors, so the heavy builds do
 * not fit on a stock body). The chat report lists what went where and the final load.
 *
 * Admin only (R_ADMIN|R_DEBUG), logged like the other feature-testing verbs. The loadouts are
 * plain typepath lists so they are easy to retune.
 */

/**
 * The ready-made builds, in install order. Order matters twice: a piece is skipped when the
 * body no longer has headroom, so the ones listed first are the ones that stay; and pairs list
 * the right arm first, its left twin after.
 */
GLOBAL_LIST_INIT(chrome_test_loadouts, list(
	"Blade dancer" = list(
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left,
		/obj/item/organ/cyberimp/cyberware/cascade,
		/obj/item/organ/cyberimp/cyberware/slipwire,
	),
	"Tank" = list(
		/obj/item/organ/cyberimp/cyberware/gorilla_arms,
		/obj/item/organ/cyberimp/cyberware/gorilla_arms/left,
		/obj/item/organ/cyberimp/cyberware/slabskin,
		/obj/item/organ/cyberimp/cyberware/atlas,
		/obj/item/organ/cyberimp/cyberware/redline,
	),
	"Street kid" = list(
		/obj/item/organ/cyberimp/cyberware/cascade/street,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/street,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/street/left,
		/obj/item/organ/cyberimp/cyberware/ghostskin/street,
		/obj/item/organ/cyberimp/cyberware/hopper/street,
		/obj/item/organ/eyes/robotic/cyberware/spyglass,
		/obj/item/organ/cyberimp/cyberware/clotter_node,
		/obj/item/organ/cyberimp/cyberware/medic_palms,
		/obj/item/organ/cyberimp/cyberware/subvocal_mic,
		/obj/item/organ/cyberimp/cyberware/muffler_ear,
	),
))

/// The kit's menu entries that are not loadouts.
#define CHROME_KIT_EVERYTHING "Everything (one of each, in a crate)"
#define CHROME_KIT_DUMMY "Chrome dummy (a chromed human to test on)"
#define CHROME_KIT_BASICS "Cradle, vouchers and credits only"

/// Vouchers and credits the kit hands out per use.
#define CHROME_KIT_VOUCHERS 30
#define CHROME_KIT_CREDITS 20000

/**
 * Every piece of chrome a ripperdoc shelf sells, one of each, as typepaths: the loose organs,
 * and the cased pairs as the case (cracking it open spills both halves). Read off the shop's
 * own SKU datums so it follows the roster by itself, plus the one piece no shelf sells.
 */
/proc/chrome_kit_everything_types()
	var/list/found = list()
	for(var/datum/shop_sku/sku_type as anything in subtypesof(/datum/shop_sku/ripperdoc))
		var/item_path = initial(sku_type.item_path)
		if(!item_path || found[item_path])
			continue
		if(ispath(item_path, /obj/item/organ) || ispath(item_path, /obj/item/cyberware_pair_case) || ispath(item_path, /obj/item/storage/case/cyberware))
			found[item_path] = TRUE
	// The Meteor Piledriver is a mission prize, not on any shelf.
	found[/obj/item/organ/cyberimp/cyberware/piledriver] = TRUE
	return assoc_to_keys(found)

/// A free turf beside the user for a prop: open floor with nothing solid on it, nearest first.
/proc/chrome_kit_adjacent_turf(atom/user)
	var/turf/origin = get_turf(user)
	if(!origin)
		return null
	for(var/direction in GLOB.cardinals)
		var/turf/candidate = get_step(origin, direction)
		if(!candidate || candidate.density || isspaceturf(candidate))
			continue
		var/blocked = FALSE
		for(var/atom/movable/occupant as anything in candidate)
			if(occupant.density || istype(occupant, /obj/machinery/chrome_cradle))
				blocked = TRUE
				break
		if(!blocked)
			return candidate
	return origin

/**
 * Seats a build into a body with special inserts, in order. A piece stays out when the body has
 * no limb for it, when it would not fit under the body's neural capacity (the same netted check
 * the cradle uses, so a same-slot swap counts) or when the insert is refused. Returns the
 * organs left over, ready for a crate; `report` collects a plain line per piece for the chat
 * report.
 */
/proc/chrome_kit_install(mob/living/carbon/target, list/ware_types, list/report)
	var/list/left_over = list()
	var/turf/here = get_turf(target)
	for(var/ware_type in ware_types)
		var/obj/item/organ/ware = new ware_type(here)
		var/reason
		if(!target.get_bodypart(deprecise_zone(ware.zone)))
			reason = "no limb for it"
		else if(!cyberware_insert_check(ware, target, silent = TRUE))
			reason = "no neural headroom"
		else if(!ware.Insert(target, special = TRUE))
			reason = "the body refused it"
		if(reason)
			report += "[ware.name] left out ([reason])"
			left_over += ware
	return left_over

/**
 * The kit's dummy: a human NPC body with no AI (it never moves, fights or barks), in a grey
 * jumpsuit, on no side anyone fights for. Being an NPC body is the point: its chrome burns out at
 * death and when a piece leaves it, as on every NPC players meet.
 */
/mob/living/carbon/human/npc/chrome_dummy
	ai_controller = null
	npc_name = "Chrome dummy"
	npc_outfit = /datum/outfit/chrome_dummy
	faction = list(FACTION_NEUTRAL)
	npc_voice = null
	npc_surrender = null

/datum/outfit/chrome_dummy
	name = "Chrome dummy"
	uniform = /obj/item/clothing/under/color/grey

/**
 * A chrome dummy at `where` carrying what fits of `ware_types` (chrome_kit_install(); pieces that
 * don't fit are deleted, so the dummy keeps only what fits). Returns the dummy.
 */
/proc/chrome_kit_make_dummy(turf/where, list/ware_types, list/report)
	var/mob/living/carbon/human/npc/chrome_dummy/dummy = new(where)
	var/list/dummy_spare = chrome_kit_install(dummy, ware_types, report)
	QDEL_LIST(dummy_spare)
	return dummy

/// A crate of loose chrome at a turf. Items placed straight into the crate, so its slot count
/// never turns the big builds away.
/proc/chrome_kit_crate(turf/where, list/contents_list, crate_name = "chrome crate")
	var/obj/structure/closet/crate/crate = new(where)
	crate.name = crate_name
	for(var/obj/item/spare in contents_list)
		spare.forceMove(crate)
	return crate

/// The admin's chrome status line: load against capacity and any piece that is dark.
/proc/chrome_kit_status_line(mob/living/carbon/target)
	var/load = get_chrome_load(target)
	var/capacity = get_chrome_capacity(target)
	var/dark = 0
	for(var/obj/item/organ/ware as anything in get_installed_cyberware(target))
		if(ware.organ_flags & ORGAN_FAILING)
			dark++
	return "[length(get_installed_cyberware(target))] pieces, load [load]/[capacity][dark ? ", [dark] dark" : ""]"

ADMIN_VERB(chrome_test_kit, R_ADMIN|R_DEBUG, "Chrome: Test Kit", "Drop a Chrome Cradle with vouchers and credits beside you, then take a ready-made chrome build (into your body or a crate) or a chromed dummy to test on.", ADMIN_CATEGORY_DEBUG)
	var/mob/admin_mob = user.mob
	var/turf/origin = get_turf(admin_mob)
	if(!origin)
		to_chat(user, span_warning("You need a physical location to drop the kit at."))
		return

	var/list/menu = list()
	for(var/loadout_name in GLOB.chrome_test_loadouts)
		menu += loadout_name
	menu += CHROME_KIT_EVERYTHING
	menu += CHROME_KIT_DUMMY
	menu += CHROME_KIT_BASICS
	var/choice = tgui_input_list(user, "Which build?", "Chrome Test Kit", menu)
	if(!choice)
		return

	// Where it goes, for the two choices that have a body to put it in.
	var/into_body = FALSE
	if(GLOB.chrome_test_loadouts[choice])
		if(iscarbon(admin_mob))
			var/where = tgui_input_list(user, "Install it where?", "Chrome Test Kit", list("Into my body", "Into a crate at my feet"))
			if(!where)
				return
			into_body = where == "Into my body"
		else
			to_chat(user, span_notice("You have no body to install into, so the build goes in a crate."))

	// The dummy takes any one of the builds, or a random one.
	var/dummy_build
	if(choice == CHROME_KIT_DUMMY)
		var/list/builds = list("Random")
		for(var/loadout_name in GLOB.chrome_test_loadouts)
			builds += loadout_name
		dummy_build = tgui_input_list(user, "Which build does the dummy carry?", "Chrome Test Kit", builds)
		if(!dummy_build)
			return
		if(dummy_build == "Random")
			dummy_build = pick(GLOB.chrome_test_loadouts)

	// The bench. One cradle per kit spot; asking twice does not stack them.
	var/obj/machinery/chrome_cradle/cradle = locate() in view(5, origin)
	var/made_cradle = FALSE
	if(!cradle)
		cradle = new(chrome_kit_adjacent_turf(admin_mob))
		made_cradle = TRUE
	new /obj/item/stack/trade_voucher(origin, CHROME_KIT_VOUCHERS)
	new /obj/item/holochip(origin, CHROME_KIT_CREDITS)

	var/list/report = list()
	var/summary = "[made_cradle ? "a cradle" : "the cradle already here"], [CHROME_KIT_VOUCHERS] vouchers and [CHROME_KIT_CREDITS] cr"
	switch(choice)
		if(CHROME_KIT_BASICS)
			EMPTY_BLOCK_GUARD // the bench, vouchers and credits are the whole kit
		if(CHROME_KIT_EVERYTHING)
			var/list/everything = list()
			for(var/ware_type in chrome_kit_everything_types())
				everything += new ware_type(origin)
			chrome_kit_crate(origin, everything, "chrome crate (everything)")
			summary += ", a crate with [length(everything)] items"
		if(CHROME_KIT_DUMMY)
			var/mob/living/carbon/human/npc/chrome_dummy/dummy = chrome_kit_make_dummy(chrome_kit_adjacent_turf(admin_mob), GLOB.chrome_test_loadouts[dummy_build], report)
			summary += ", a chrome dummy carrying the [dummy_build] build ([chrome_kit_status_line(dummy)])"
		else
			var/list/ware_types = GLOB.chrome_test_loadouts[choice]
			if(into_body)
				var/list/spare = chrome_kit_install(admin_mob, ware_types, report)
				summary += ", the [choice] build installed ([chrome_kit_status_line(admin_mob)])"
				if(length(spare))
					chrome_kit_crate(origin, spare, "chrome crate ([choice], left over)")
					summary += ", [length(spare)] left over in a crate"
			else
				var/list/boxed = list()
				for(var/ware_type in ware_types)
					boxed += new ware_type(origin)
				chrome_kit_crate(origin, boxed, "chrome crate ([choice])")
				summary += ", the [choice] build in a crate"

	to_chat(user, span_notice("Chrome test kit: [summary]."))
	for(var/line in report)
		to_chat(user, span_notice("  [line]."))
	message_admins("[key_name_admin(user)] used the chrome test kit ([choice]) at [ADMIN_VERBOSEJMP(origin)].")
	log_admin("[key_name(user)] used the chrome test kit ([choice]): [summary].")
	BLACKBOX_LOG_ADMIN_VERB("Chrome Test Kit")

#undef CHROME_KIT_EVERYTHING
#undef CHROME_KIT_DUMMY
#undef CHROME_KIT_BASICS

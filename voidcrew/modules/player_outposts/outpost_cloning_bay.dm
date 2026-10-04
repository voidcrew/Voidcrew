/**
 * # Cloning bay
 *
 * An outpost service room with eight outpost cloning vats and a free wardrobe for the naked clones
 * that step out of them. A visitor pays the outpost's imprint
 * price (OUTPOST_PRICE_CLONE_IMPRINT) from the ID they present, and gets one life: waking in the
 * clone uses the imprint up. Members (outpost_market.dm) imprint free. Rules on top of a ship vat:
 * * an imprinted vat refuses every new imprint, the holder's own included;
 * * one imprint per player per outpost;
 * * while the outpost is owned, a visitor cannot wake here during a LOCKDOWN, or while their crew
 *   is banned. The imprint is kept.
 *
 * The vat finds its outpost by where it stands. Off an outpost it is a free, regrowing vat.
 * Deleting the outpost deletes the vats and their imprints; nothing is refunded.
 */

/datum/map_template/outpost_upgrade/cloning_bay
	name = "Outpost Cloning Bay"

/datum/map_template/outpost_upgrade/cloning_bay/rundown
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_cloning_bay_rundown.dmm"
	outpost_style = OUTPOST_STYLE_RUNDOWN

/datum/map_template/outpost_upgrade/cloning_bay/clean
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_cloning_bay_clean.dmm"
	outpost_style = OUTPOST_STYLE_CLEAN

/datum/outpost_upgrade/service/cloning_bay
	id = "cloning_bay"
	name = "Cloning Bay"
	desc = "Eight cloning vats and a wardrobe."
	price = OUTPOST_CLONING_BAY_COST
	template_type = /datum/map_template/outpost_upgrade/cloning_bay
	area_type = /area/voidcrew/player_outpost/service_room/cloning_bay
	/// The room's vats, found at install
	var/list/datum/weakref/vat_refs

/datum/outpost_upgrade/service/cloning_bay/Destroy()
	vat_refs = null
	return ..()

/datum/outpost_upgrade/service/cloning_bay/on_service_installed(mob/user)
	vat_refs = list()
	for(var/turf/tile as anything in room_turfs())
		for(var/obj/machinery/cloning_vat/outpost/vat in tile)
			vat_refs += WEAKREF(vat)
	if(length(vat_refs) != OUTPOST_CLONING_BAY_VATS)
		log_mapping("OUTPOST CLONING BAY: the room at '[outpost?.name]' loaded with [length(vat_refs)] vats, not [OUTPOST_CLONING_BAY_VATS]")

/// The room's vats that still exist
/datum/outpost_upgrade/service/cloning_bay/proc/room_vats()
	. = list()
	for(var/datum/weakref/vat_ref as anything in vat_refs)
		var/obj/machinery/cloning_vat/outpost/vat = vat_ref.resolve()
		if(!QDELETED(vat))
			. += vat

// ===== THE WARDROBE =====

/// Clones wake with nothing on. This one gives its clothes away.
/obj/machinery/vending/clothing/outpost
	all_products_free = TRUE
	tiltable = FALSE

// ===== THE VAT =====

/obj/machinery/cloning_vat/outpost
	name = "outpost cloning vat"
	desc = "A tank of murky nutrient fluid that grows a spare body. This one belongs to the outpost."
	circuit = null
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	overwrite_allowed = FALSE
	/// What the holder paid for the imprint, for the logs. 0 when it was free.
	var/paid_amount = 0
	/// The player who imprinted, for the one-imprint-per-outpost rule and the logs
	var/imprint_ckey

/obj/machinery/cloning_vat/outpost/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)
	flags_1 |= PREVENT_CONTENTS_EXPLOSION_1

// A bag-of-holding rift deletes objects whatever their resistance flags
/obj/machinery/cloning_vat/outpost/singularity_act()
	return 0

/obj/machinery/cloning_vat/outpost/singularity_pull(atom/singularity, current_size)
	return

/// The player outpost this vat stands in, or null
/obj/machinery/cloning_vat/outpost/proc/host_outpost()
	return get_outpost_from_atom(src)

/obj/machinery/cloning_vat/outpost/is_single_use()
	return !!host_outpost()

/obj/machinery/cloning_vat/outpost/examine(mob/user)
	. = ..()
	var/obj/structure/overmap/dynamic/player_outpost/home = host_outpost()
	if(!home)
		return
	var/owed = home.service_price_for(user, home.get_price(OUTPOST_PRICE_CLONE_IMPRINT))
	. += span_notice("Imprint: [owed > 0 ? "[owed] cr" : "free"].")

/obj/machinery/cloning_vat/outpost/wipe_imprint()
	paid_amount = 0
	imprint_ckey = null
	return ..()

/obj/machinery/cloning_vat/outpost/after_claim(mob/living/carbon/human/clone)
	if(!is_single_use())
		return ..()
	log_game("PLAYER OUTPOST: [key_name(clone)] woke in a clone at [src] ([AREACOORD(src)]); the imprint was used up (paid [paid_amount] cr)")
	wipe_imprint()

// ===== IMPRINTING =====

/// Why this body cannot be imprinted, or null. The client check is for the interactive path only.
/obj/machinery/cloning_vat/outpost/proc/imprint_body_denial(mob/living/user, need_client = TRUE)
	if(!ishuman(user))
		return "Incompatible lifeform."
	if(user.stat != CONSCIOUS)
		return "You must be awake."
	if(isnull(user.mind) || (need_client && isnull(user.client)))
		return "No neural signature."
	if(!user.has_dna() || HAS_TRAIT(user, TRAIT_GENELESS) || HAS_TRAIT(user, TRAIT_BADDNA))
		return "Unreadable genetic pattern."
	return null

/// Why this player cannot imprint this vat at `home`, or null
/obj/machinery/cloning_vat/outpost/proc/imprint_denial(mob/living/user, obj/structure/overmap/dynamic/player_outpost/home)
	// No overwriting another player's paid life, and no refreshing your own
	if(imprint_mind_ref)
		return "Occupied."
	var/player_key = ckey(user.mind?.key) || user.ckey
	for(var/obj/machinery/cloning_vat/outpost/other in LAZYACCESS(GLOB.imprinted_vats_by_ckey, player_key))
		if(other != src && other.host_outpost() == home)
			return "You already have a clone here."
	return null

/obj/machinery/cloning_vat/outpost/try_imprint(mob/living/user)
	var/obj/structure/overmap/dynamic/player_outpost/home = host_outpost()
	if(!home)
		return ..()
	var/denial = imprint_body_denial(user) || imprint_denial(user, home)
	if(denial)
		balloon_alert(user, LOWER_TEXT(denial))
		return
	var/owed = home.service_price_for(user, home.get_price(OUTPOST_PRICE_CLONE_IMPRINT))
	var/datum/bank_account/account = user.get_idcard(TRUE)?.registered_account
	if(owed > 0 && !account)
		balloon_alert(user, "no bank account on your id!")
		return
	var/prompt = owed > 0 \
		? "Imprint for [owed] cr from [account.account_holder]'s account? Single use." \
		: "Imprint your genetic pattern? Single use."
	if(tgui_alert(user, prompt, name, list("Imprint", "Cancel")) != "Imprint")
		return
	if(QDELETED(src) || QDELETED(user) || !user.can_perform_action(src) || host_outpost() != home)
		return
	var/refusal = paid_imprint(user, home, owed)
	if(refusal)
		balloon_alert(user, "refused!")
		to_chat(user, span_warning(refusal))
		return
	if(owed > 0)
		to_chat(user, span_notice("[owed] cr paid to [home.name] from [account.account_holder]."))

/**
 * Checks everything again, charges, then imprints. Never sleeps, so nothing can fill the vat or
 * change the price between the check and the charge. `shown_price` is the fee the player saw:
 * what they owe here, 0 for a member. Returns null on success, else a refusal.
 */
/obj/machinery/cloning_vat/outpost/proc/paid_imprint(mob/living/carbon/human/user, obj/structure/overmap/dynamic/player_outpost/home, shown_price)
	if(QDELETED(src) || QDELETED(home))
		return "Service unavailable."
	var/denial = imprint_body_denial(user, need_client = FALSE) || imprint_denial(user, home)
	if(denial)
		return denial
	var/listed = home.get_price(OUTPOST_PRICE_CLONE_IMPRINT)
	var/owed = home.service_price_for(user, listed)
	if(!isnum(shown_price) || shown_price != owed)
		return "Price changed to [owed] cr."
	var/datum/bank_account/account
	if(owed > 0)
		account = user.get_idcard(TRUE)?.registered_account
		var/refusal = home.charge_service(user, OUTPOST_PRICE_CLONE_IMPRINT, listed, owed, "Cloning imprint")
		if(refusal)
			return refusal
	do_imprint(user)
	paid_amount = owed
	imprint_ckey = user.ckey
	log_game("PLAYER OUTPOST: [key_name(user)] imprinted [src] at '[home.name]' for [owed] cr[account ? " from [account.account_holder]" : ""]")
	return null

// ===== WAKING =====

/// Whether the imprinted player counts as a member here. A ghost from suicide, DNR or the Ghost
/// verb has no mind, so its character is judged by the mind's body, or by being a resident.
/obj/machinery/cloning_vat/outpost/proc/holder_is_member(obj/structure/overmap/dynamic/player_outpost/home, mob/dead/observer/ghost, datum/mind/mind)
	if(home.playtest_visitor_ckey && ghost?.ckey == home.playtest_visitor_ckey)
		return FALSE
	if(home.is_owner(ghost))
		return TRUE
	// A blocked player's ghost has no mind and their corpse no ckey, so the block is checked here
	var/holder_key = ckey(mind?.key) || ghost?.ckey
	if(holder_key && (holder_key in home.blocked_residents))
		return FALSE
	if(ghost?.mind)
		return home.is_outpost_member(ghost)
	if(!mind)
		return FALSE
	return (mind in home.residents) || (mind.current && home.is_outpost_member(mind.current))

/// Whether any crew the imprinted mind belongs to is banned from `home`
/obj/machinery/cloning_vat/outpost/proc/holder_banned(obj/structure/overmap/dynamic/player_outpost/home, datum/mind/mind)
	for(var/datum/team/voidcrew/team as anything in mind?.ship_teams)
		if(team.ship && home.banned_ships[team.ship])
			return TRUE
	return FALSE

/**
 * Waking here is an arrival. While the outpost has an owner, a visitor may not arrive during a
 * LOCKDOWN, or while their crew is banned. An ownerless outpost lets everyone wake:
 * there is nobody to protect, and refusing would strand paid lives.
 */
/obj/machinery/cloning_vat/outpost/claim_denial(mob/dead/observer/user, datum/mind/mind)
	. = ..()
	if(.)
		return
	var/obj/structure/overmap/dynamic/player_outpost/home = host_outpost()
	if(!home?.founder_ckey || holder_is_member(home, user, mind))
		return null
	if(holder_banned(home, mind))
		return "Your crew is banned from [home.name]."
	if(home.dock_mode == OUTPOST_DOCK_MODE_LOCKDOWN)
		return "[home.name] is in lockdown."
	return null

/obj/machinery/cloning_vat/outpost/claim_warning(mob/dead/observer/user)
	var/obj/structure/overmap/dynamic/player_outpost/home = host_outpost()
	var/datum/outpost_upgrade/service/room = home?.upgrade_at_turf(get_turf(src))
	if(!istype(room))
		return null
	var/exit = room.exit_denial()
	return exit ? "[home.name] cloning bay: [exit]." : null

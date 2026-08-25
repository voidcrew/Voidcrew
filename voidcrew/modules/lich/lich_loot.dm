/**
 * # The Verdigris: hoard
 *
 * What is left on the sanctum floor when Ilthuun stops working. Four layers of
 * undead buy the raid his regalia (a robe and a horned crown, green and gold,
 * both of which cast), the staff he was leaning on, the husk of the phylactery
 * that stopped saving him, the bridle he put on other people's hands, and three
 * codices in his own hand, one per school he fought in (see lich_spells.dm).
 * The hoard is the WHOLE payout: only the boarding party gets anything, which
 * is the correct answer now that the site costs everyone else nothing.
 *
 * ## Power calibration
 *
 * The occult theme's ceiling is `/obj/item/his_grace` at weight 1 in
 * `loot_prime` (voidcrew/modules/loot/themes/occult.dm), a deliberate
 * crown-jewel jackpot, and a permanent, escalating, round-warping one. Nothing
 * here is that. Everything here is:
 *  - bounded (the phylactery is one draught and then it is glass),
 *  - narrow (the crown covers lesser undead only, only while worn, and only for
 *    the wearer, it is a hat that skeletons ignore, not a licence),
 *  - or a retune of gear that already sits in this theme's tables (the robe and
 *    crown are wizard garb with a modest armour bump and real cold protection;
 *    `/obj/item/clothing/suit/armor/riot/knight` is already loot_prime weight 5,
 *    and `/obj/item/gun/magic/staff/chaos` is already loot_prime weight 2).
 * The staff's siphon is the one genuinely new capability, and it is capped, on a
 * cooldown, and does nothing at all against the undead, which is to say it does
 * nothing on four fifths of the map it drops in.
 *
 * The bridle is the exception that has to be argued rather than waved at: taking
 * another player's body off them for five seconds is the strongest thing in this
 * file and the most grief-report-prone mechanic in the module. It is priced in
 * three ways, three charges and then it is dead leather, a full minute between
 * uses against a five second effect, and a 90 second per-victim lockout that
 * outlasts its own cooldown, and it is loud: it names its wielder to the victim,
 * to every bystander, and in the logs, at apply and at expiry. It is also not a
 * targeting tool. The victim goes for whoever is nearest, which regularly means
 * the person who bridled them. See the item's own header.
 *
 * ## Cross-track API
 *
 * `drop_lich_hoard(atom/drop_near)` is the entry point. Whoever owns the boss's
 * death should call it once; it is idempotent (GLOB.lich_hoard_dropped) so a
 * belt-and-braces second call from the site is harmless. It prefers a mapped
 * `/obj/effect/landmark/lich/loot_spot` and falls back to the turf of whatever
 * it was handed.
 *
 * There is no other half. A galaxy-wide spell dispersal used to fire alongside
 * the hoard, compensation for a ritual clock that pressured every crew in the
 * galaxy, and it was cut together with the rites: with nothing to compensate
 * anyone for, handing the raiders' own three spells to everyone who stayed home
 * only cheapened the codices on the sanctum floor.
 *
 * Sprites come from `voidcrew/modules/lich/icons/lich_garb.dmi` (track F). The
 * state names this file asks for are listed beside each item.
 */

// =========================================================================
// Local tuning defines, #undef'd at the bottom of the file so they don't leak
// (same convention as voidcrew/modules/loot/uniques/occult.dm).
// =========================================================================
/// Cooldown between the verdigris staff's life-siphons
#define LICH_SIPHON_COOLDOWN (4 SECONDS)
/// Toxin damage the siphon tears out of a living, non-undead target
#define LICH_SIPHON_DRAIN 12
/// Brute/burn the siphon gives back to the wielder, per successful drink
#define LICH_SIPHON_HEAL 8
/// How far the crown's dominion reaches for lesser undead
#define LICH_CROWN_DOMINION_RANGE 7
/// maxHealth at or below which an undead counts as "lesser" and can be claimed.
/// A deliberately blunt gate: it keeps the crown off elites and off Ilthuun
/// himself (2800 HP) without this file having to reference track C's typepath.
#define LICH_CROWN_LESSER_UNDEAD_HP 300
/// Beat between death and the phylactery's draught, for the visible messages to land in
#define LICH_PHYLACTERY_DELAY (8 SECONDS)
/// Damage threshold each type is healed down to on the draught. Low on purpose:
/// four types at this value still leaves a human alive (see heal_and_revive,
/// code/modules/mob/living/living.dm:926) and you come back hurt, not fresh.
#define LICH_PHYLACTERY_REVIVE_TO 30
/// How long you lie there afterwards, remembering it
#define LICH_PHYLACTERY_STUN (15 SECONDS)
/// Possessions in a fresh verdigris bridle. Three, and then it is a strap.
#define LICH_BRIDLE_CHARGES 3
/// How long one bridled possession lasts. Half of Ilthuun's ten seconds
/// (LICH_THRALL_DURATION, lich_thrall.dm): ten seconds of lost agency decides most player
/// fights outright, five is decisive without being a death sentence.
#define LICH_BRIDLE_DURATION (5 SECONDS)
/// Between uses. Ilthuun casts his every 45 seconds; a minute is what stops this opening
/// every engagement. Deliberately SHORTER than the 90 second per-victim immunity
/// lich_thrall.dm leaves behind, so the bridle always comes back before its last victim
/// does, a wielder who wants to use it again has to pick somebody else.
#define LICH_BRIDLE_COOLDOWN (60 SECONDS)

/// Set once the sanctum has been paid out, so a doubled death call can't double the hoard.
GLOBAL_VAR_INIT(lich_hoard_dropped, FALSE)

// =========================================================================
// LANDMARK
// Only the loot_spot subtype is declared here. `/obj/effect/landmark/lich`
// itself is left implicit on purpose, DM creates the intermediate path for
// free, and declaring a body for it in two tracks' files at once would be a
// duplicate definition. boss_spawn and summon_spot belong to their own tracks.
// =========================================================================

/// Optional. Marks the tile Ilthuun's hoard lands on, a plinth, an altar, the
/// middle of the sanctum floor, mapper's choice. Consumed on payout.
/obj/effect/landmark/lich/loot_spot
	name = "lich loot spot"

// =========================================================================
// THE PAYOUT
// =========================================================================

/// Everything Ilthuun leaves behind, in drop order.
GLOBAL_LIST_INIT(lich_hoard_contents, list(
	/obj/item/clothing/suit/wizrobe/verdigris,
	/obj/item/clothing/head/wizard/verdigris,
	/obj/item/melee/verdigris_staff,
	/obj/item/verdigris_phylactery,
	/obj/item/verdigris_bridle,
	/obj/item/book/granter/action/spell/raise_thrall,
	/obj/item/book/granter/action/spell/verdigris_bolt,
	/obj/item/book/granter/action/spell/grave_mirage,
))

/**
 * Drops the hoard. Call this once, from wherever the boss dies.
 *
 * Scatters over the free tiles around the drop point rather than stacking the
 * whole hoard on one turf. A mapped plinth reads better with the regalia laid
 * out around it, and a pile of eight is genuinely annoying to sort through.
 *
 * The scatter is size-agnostic: it lays claim to the drop turf plus every open,
 * non-dense tile in `range(1, ...)` (up to nine), and refills from that list if
 * the hoard is ever longer than the ring, so adding an entry to
 * GLOB.lich_hoard_contents needs no payout change. Verified against the current
 * eight, eight items, nine candidate tiles, one item per tile.
 *
 * Returns the turf it dropped on, or null if it couldn't find one.
 */
/proc/drop_lich_hoard(atom/drop_near)
	if(GLOB.lich_hoard_dropped)
		return null

	var/turf/hoard_turf = get_lich_hoard_turf(drop_near)
	if(!hoard_turf)
		log_mapping("LICH: hoard payout found no turf to drop on (drop_near: [drop_near || "null"]).")
		return null

	GLOB.lich_hoard_dropped = TRUE

	// Scatter tiles: the drop turf first, then whatever open ground surrounds it.
	var/list/turf/scatter = list(hoard_turf)
	for(var/turf/open/nearby in range(1, hoard_turf))
		if(nearby == hoard_turf || nearby.density)
			continue
		scatter += nearby

	var/list/turf/remaining = scatter.Copy()
	for(var/hoard_type as anything in GLOB.lich_hoard_contents)
		if(!length(remaining))
			remaining = scatter.Copy()
		new hoard_type(pick_n_take(remaining))

	// VOIDCREW EDIT: RATTLEMEBONES.ogg was deleted upstream for copyright (tg #96880).
	playsound(hoard_turf, 'sound/effects/magic/RATTLEMEBONES.ogg', 65, TRUE)
	hoard_turf.visible_message(span_boldnotice("The green goes out of the room, and leaves his things on the floor."))
	log_game("LICH: hoard paid out at ([hoard_turf.x], [hoard_turf.y], [hoard_turf.z]).")
	return hoard_turf

/**
 * Where the hoard lands: the spot the MAP nominated.
 *
 * The lair's template places an `/obj/effect/landmark/lich/loot_spot` on the
 * reliquary plinth, and the site captures its turf during link_interior()'s walk
 * over its own footprint (lich_site.dm), holding it for the round. All this proc
 * does is read that turf.
 *
 * It deliberately does NOT go looking for the landmark itself. The previous
 * version scanned GLOB.landmarks_list at death time and paid the entire hoard out
 * onto a docked player's SHIP: that list holds every landmark in the game, and the
 * first arbitrary one sharing the lich's z-level won, ruin interiors and docked
 * shuttles share reservation z-levels. Resolving position from the lair's own
 * footprint instead makes straying off the map structurally impossible.
 *
 * Fallback is the turf we were handed (where Ilthuun fell), so a template that
 * loses its marker still pays out, just on the corpse instead of the plinth.
 */
/proc/get_lich_hoard_turf(atom/drop_near)
	var/turf/marked = GLOB.lich_lair?.hoard_turf
	if(marked)
		return marked
	return get_turf(drop_near)

// =========================================================================
// GARB: verdigris robe
// Subtypes /obj/item/clothing/suit/wizrobe (code/modules/clothing/suits/wiz_robe.dm:111)
// for slot behaviour, strip delays, the casting-clothing trait and the fishing-difficulty
// component. Icon, worn icon, armour and cold protection are all overridden.
// DMI states wanted: "lich_robe" (world), "lich_robe_worn" (worn overlay),
// "lich_robe_inhand" (carried, same state used for both hands).
// =========================================================================

/**
 * Wizard garb, honestly. Inheriting TRAIT_CASTING_CLOTHING from
 * wizrobe is the whole point of the item: the robe and crown together are what
 * let a plain crewmember cast the garb-locked half of this codebase's magic
 * (staves of change, a `granter/action/spell/random` roll that landed on
 * something garb-gated, the Athenaeum's blink). The three spells in
 * lich_spells.dm deliberately do NOT need it. The regalia is an amplifier for
 * magic you find elsewhere, not a key to your own reward.
 */
/obj/item/clothing/suit/wizrobe/verdigris
	name = "verdigris robe"
	desc = "Green wool over a segmented gold collar, cut for someone much taller and thinner than you. The hem is heavy with grave-dirt that won't brush out, and it's still warm."
	icon = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	icon_state = "lich_robe"
	worn_icon = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	worn_icon_state = "lich_robe_worn"
	lefthand_file = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	righthand_file = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	inhand_icon_state = "lich_robe_inhand"
	armor_type = /datum/armor/suit_verdigris_robe
	allowed = list(
		/obj/item/melee/verdigris_staff,
		/obj/item/verdigris_phylactery,
		/obj/item/teleportation_scroll,
	)
	// The cold has nothing left to take from the man who wore this. It has
	// plenty to take from you, but the robe doesn't know that.
	// CASTING_CLOTHES is gone: upstream turned it into TRAIT_CASTING_CLOTHING, added by
	// /obj/item/clothing/suit/wizrobe/Initialize(), which this inherits.
	clothing_flags = STOPSPRESSUREDAMAGE
	cold_protection = CHEST|GROIN|ARMS|LEGS
	min_cold_protection_temperature = SPACE_SUIT_MIN_TEMP_PROTECT
	heat_protection = CHEST|GROIN|ARMS|LEGS
	max_heat_protection_temperature = FIRE_SUIT_MAX_TEMP_PROTECT
	fishing_modifier = -7

/// A modest bump on the wizrobe's numbers (melee 30 / bullet 20 / laser 20 /
/// energy 30 / bomb 20 / wound 20). Melee is left exactly where it was: this is
/// a robe, and the melee tier in this theme belongs to riot armour.
/datum/armor/suit_verdigris_robe
	melee = 30
	bullet = 25
	laser = 25
	energy = 35
	bomb = 25
	bio = 100
	fire = 100
	acid = 100
	wound = 25

/obj/item/clothing/suit/wizrobe/verdigris/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/suit/wizrobe/verdigris/examine(mob/user)
	. = ..()
	. += span_green("The collar's segments are lettered. Read together they spell the same name forty times over.")

// =========================================================================
// GARB: verdigris crown
// Subtypes /obj/item/clothing/head/wizard (code/modules/clothing/suits/wiz_robe.dm:1)
// for SNUG_FIT plus the casting trait, strip delays and armour baseline.
// DMI states wanted: "lich_crown" (world), "lich_crown_worn" (worn overlay),
// "lich_crown_inhand" (carried, same state used for both hands).
// =========================================================================

/**
 * Lesser undead ignore you while you wear this. That is the entire item.
 *
 * Every undead-biotype `/mob/living` within LICH_CROWN_DOMINION_RANGE whose
 * maxHealth is at or below LICH_CROWN_LESSER_UNDEAD_HP has the wearer's own ref
 * added to its faction list, so it stops initiating on the wearer specifically.
 *
 * This is the censer of the quiet parish's exact mechanism
 * (voidcrew/modules/loot/uniques/occult.dm:308) and works for the same verified
 * reason: `/mob/living/Initialize` puts `REF(src)` into its own faction list
 * (code/modules/mob/living/living.dm:13), so seeding that ref into a hostile's
 * factions makes `faction_check_atom` return TRUE for that pair and nobody else.
 * It is re-scanned every process tick, so the truce follows whoever is actually
 * nearby instead of being permanent, and it is handed straight back on unequip,
 * on a change of wearer, and on Destroy.
 *
 * What keeps it in its lane is the cap, not a clause: it never covers the person
 * standing next to you, and LICH_CROWN_LESSER_UNDEAD_HP keeps it off elites and
 * off Ilthuun himself. An earlier version dropped the whole truce for two minutes
 * if the wearer swung at a claimed corpse; in playtest that read as the crown
 * breaking at random, so it is gone. Skeleton-proof while worn, full stop.
 */
/obj/item/clothing/head/wizard/verdigris
	name = "verdigris crown"
	desc = "A horned skull-cap of hammered gold, gone green in the seams and sized for a head with nothing in it. The horns are real bone under the gilding."
	icon = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	icon_state = "lich_crown"
	worn_icon = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	worn_icon_state = "lich_crown_worn"
	lefthand_file = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	righthand_file = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	inhand_icon_state = "lich_crown_inhand"
	armor_type = /datum/armor/head_verdigris_crown
	dog_fashion = null
	// See the robe above - the casting half is TRAIT_CASTING_CLOTHING on the parent now.
	clothing_flags = SNUG_FIT | STOPSPRESSUREDAMAGE
	cold_protection = HEAD
	min_cold_protection_temperature = SPACE_HELM_MIN_TEMP_PROTECT
	heat_protection = HEAD
	max_heat_protection_temperature = FIRE_HELM_MAX_TEMP_PROTECT
	light_range = 1.6
	light_power = 0.7
	light_color = LIGHT_COLOR_GREEN
	fishing_modifier = -6
	/// The lesser undead currently holding their peace with our wearer
	var/list/mob/living/claimed_dead = list()
	/// Whose head we're on and scanning from, if any
	var/mob/living/current_wearer

/// Wizard hat armour (melee 30 / bullet 20 / laser 20 / energy 30 / bomb 20 /
/// wound 20) with the same modest bump the robe got, for the same reason.
/datum/armor/head_verdigris_crown
	melee = 30
	bullet = 25
	laser = 25
	energy = 35
	bomb = 25
	bio = 100
	fire = 100
	acid = 100
	wound = 25

/obj/item/clothing/head/wizard/verdigris/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/head/wizard/verdigris/Destroy()
	end_dominion()
	return ..()

/obj/item/clothing/head/wizard/verdigris/examine(mob/user)
	. = ..()
	. += span_green("<b>Worn, lesser undead within [LICH_CROWN_DOMINION_RANGE] tiles will not attack you.</b> It holds for as long as it's on your head, no matter what you do to them in the meantime.")
	. += span_green("It only covers you, not anyone standing next to you, and the bigger undead ignore it entirely.")

/obj/item/clothing/head/wizard/verdigris/equipped(mob/living/user, slot, initial)
	. = ..()
	if(!(slot & ITEM_SLOT_HEAD) || !isliving(user))
		return
	begin_dominion(user)

/obj/item/clothing/head/wizard/verdigris/dropped(mob/living/user, silent = FALSE)
	. = ..()
	if(current_wearer != user)
		return
	end_dominion()

/obj/item/clothing/head/wizard/verdigris/proc/begin_dominion(mob/living/wearer)
	if(current_wearer)
		end_dominion()
	current_wearer = wearer
	START_PROCESSING(SSobj, src)

/obj/item/clothing/head/wizard/verdigris/proc/end_dominion()
	STOP_PROCESSING(SSobj, src)
	release_all_dead()
	current_wearer = null

/obj/item/clothing/head/wizard/verdigris/process(seconds_per_tick)
	if(QDELETED(current_wearer) || current_wearer.get_item_by_slot(ITEM_SLOT_HEAD) != src)
		end_dominion()
		return
	reconcile_dominion()

/// Recomputes which lesser undead should currently be at peace with the wearer.
/obj/item/clothing/head/wizard/verdigris/proc/reconcile_dominion()
	var/list/mob/living/should_hold = list()
	for(var/mob/living/corpse in range(LICH_CROWN_DOMINION_RANGE, get_turf(current_wearer)))
		if(!is_lesser_undead(corpse))
			continue
		should_hold += corpse

	for(var/mob/living/corpse as anything in claimed_dead)
		if(!(corpse in should_hold))
			release_dead(corpse)
	for(var/mob/living/corpse as anything in should_hold)
		if(!(corpse in claimed_dead))
			claim_dead(corpse)

/// The gate: undead biotype, alive, not an elite, not the wearer's own ally already.
/obj/item/clothing/head/wizard/verdigris/proc/is_lesser_undead(mob/living/corpse)
	if(QDELETED(corpse) || corpse == current_wearer || corpse.stat == DEAD)
		return FALSE
	if(!(corpse.mob_biotypes & MOB_UNDEAD))
		return FALSE
	if(ismegafauna(corpse) || corpse.maxHealth > LICH_CROWN_LESSER_UNDEAD_HP)
		return FALSE
	return TRUE

/obj/item/clothing/head/wizard/verdigris/proc/claim_dead(mob/living/corpse)
	corpse.faction |= REF(current_wearer)
	claimed_dead += corpse
	RegisterSignal(corpse, COMSIG_QDELETING, PROC_REF(on_claimed_dead_gone))

/obj/item/clothing/head/wizard/verdigris/proc/release_dead(mob/living/corpse)
	if(!QDELETED(corpse))
		corpse.faction -= REF(current_wearer)
		UnregisterSignal(corpse, COMSIG_QDELETING)
	claimed_dead -= corpse

/obj/item/clothing/head/wizard/verdigris/proc/release_all_dead()
	for(var/mob/living/corpse as anything in claimed_dead.Copy())
		release_dead(corpse)

/obj/item/clothing/head/wizard/verdigris/proc/on_claimed_dead_gone(datum/source)
	SIGNAL_HANDLER
	claimed_dead -= source

// =========================================================================
// GEAR: verdigris staff
// Subtypes /obj/item/melee (code/game/objects/items/melee/misc.dm:2) for
// NEEDS_PERMIT and nothing else; every appearance var is set here.
// DMI states wanted: "lich_staff" (world) and "lich_staff_inhand" (carried,
// one state serving both hands, since `inhand_icon_state` is a single var and
// both hand files point at lich_garb.dmi).
// =========================================================================

/**
 * A bone shaft with something still in it. Solid melee (force 18, between a
 * spear and a fireaxe) plus the siphon: a harm-intent hit on a living,
 * non-undead target tears LICH_SIPHON_DRAIN toxin out of it and gives
 * LICH_SIPHON_HEAL of the wielder's own brute and burn back, once every
 * LICH_SIPHON_COOLDOWN.
 *
 * Scope note, honestly: the siphon fires in attack() after the parent call, so
 * it does not read whether the swing actually connected past a block or a dodge.
 * Precedent for hooking here is the shepherd's crook
 * (voidcrew/modules/loot/uniques/occult.dm:638). The cooldown is what keeps the
 * imprecision from mattering, you get one drink per four seconds regardless.
 */
/obj/item/melee/verdigris_staff
	name = "verdigris staff"
	desc = "A femur too long to have come off anything that walked upright, capped with a knot of gold and wound in green wire. Hit something living with it and it drinks their life to close your own wounds. The undead have nothing in them to take."
	icon = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	icon_state = "lich_staff"
	lefthand_file = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	righthand_file = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	inhand_icon_state = "lich_staff_inhand"
	// No bespoke back sprite in lich_garb.dmi, so borrow the necro staff's.
	worn_icon_state = "necrostaff"
	icon_angle = -45
	force = 18
	throwforce = 12
	w_class = WEIGHT_CLASS_BULKY
	slot_flags = ITEM_SLOT_BACK
	attack_verb_continuous = list("cracks", "clubs", "raps", "brains")
	attack_verb_simple = list("crack", "club", "rap", "brain")
	hitsound = 'sound/items/weapons/genhit1.ogg'
	resistance_flags = FIRE_PROOF | ACID_PROOF
	light_range = 2
	light_power = 0.8
	light_color = LIGHT_COLOR_GREEN
	/// Running tally of drinks taken, purely so the staff can brag on examine
	var/draughts_taken = 0
	COOLDOWN_DECLARE(siphon_cooldown)

/obj/item/melee/verdigris_staff/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/melee/verdigris_staff/examine(mob/user)
	. = ..()
	// Lead with the numbers. The playtest read of the old copy was that the staff
	// might be healing the person you were hitting.
	. += span_green("<b>Strike a living, non-undead target: it takes [LICH_SIPHON_DRAIN] toxin damage, and <u>you</u> are healed [LICH_SIPHON_HEAL] brute and [LICH_SIPHON_HEAL] burn.</b> Once every [DisplayTimeText(LICH_SIPHON_COOLDOWN)].")
	. += span_green("The undead have no life in them to drink. Against skeletons this is a club and nothing else.")
	if(draughts_taken)
		. += span_green("<i>It has drunk [draughts_taken] time[draughts_taken == 1 ? "" : "s"] so far.</i>")

/obj/item/melee/verdigris_staff/attack(mob/living/target_mob, mob/living/user, list/modifiers, list/attack_modifiers)
	. = ..()
	try_siphon(target_mob, user)

/obj/item/melee/verdigris_staff/proc/try_siphon(mob/living/target_mob, mob/living/user)
	if(!isliving(target_mob) || !isliving(user) || target_mob == user)
		return
	if(!COOLDOWN_FINISHED(src, siphon_cooldown))
		return
	if(target_mob.stat == DEAD)
		return
	// The whole point of the item: it drinks life, and the undead have none to
	// give. In a lair full of skeletons the staff is a stick.
	if(target_mob.mob_biotypes & MOB_UNDEAD)
		return
	if(target_mob.can_block_magic(MAGIC_RESISTANCE))
		to_chat(user, span_warning("[src] finds nothing to hold onto in [target_mob]."))
		COOLDOWN_START(src, siphon_cooldown, LICH_SIPHON_COOLDOWN)
		return

	COOLDOWN_START(src, siphon_cooldown, LICH_SIPHON_COOLDOWN)
	draughts_taken++
	target_mob.adjust_tox_loss(LICH_SIPHON_DRAIN, forced = TRUE)
	user.adjust_brute_loss(-LICH_SIPHON_HEAL)
	user.adjust_fire_loss(-LICH_SIPHON_HEAL)
	new /obj/effect/temp_visual/small_smoke/halfsecond(get_turf(target_mob))
	playsound(target_mob, 'sound/effects/magic/demon_consume.ogg', 35, TRUE)
	user.visible_message(
		span_warning("The gold cap of [src] flushes green, and [target_mob] goes grey around it."),
		span_green("Something warm comes up the shaft of [src] and settles behind your ribs."),
	)
	log_combat(user, target_mob, "siphoned with", src)

// =========================================================================
// GEAR: spent phylactery
// A bare /obj/item; every appearance var set here.
// DMI state wanted: "lich_phylactery" (world only, no inhand or worn).
// =========================================================================

/**
 * Not a phylactery. `/datum/component/phylactery`
 * (code/datums/components/phylactery.dm) is the wizard antag's unlimited
 * revive loop bound to a mind, and this is deliberately none of that: no mind
 * binding, no repeat resurrections, no stationloving, no point of interest.
 *
 * This is the husk of Ilthuun's, cracked by whatever the raid did to him, with
 * one swallow left in the bottom. Carried on your person, pocket, belt, suit
 * storage, hand, never a bag, exactly as `equipped()`/`dropped()` define it (the
 * same "on your person" contract the sealed syllable uses,
 * voidcrew/modules/antag_ruins/theme_wizard.dm:293), it registers your death.
 * When you die it waits LICH_PHYLACTERY_DELAY, drags you back at
 * LICH_PHYLACTERY_REVIVE_TO damage of each type, paralyses you for
 * LICH_PHYLACTERY_STUN, and shatters. Once. Then it is glass on the floor.
 *
 * It cannot save a gibbed or dusted body. There is nothing left to pour into,
 * and it refuses rather than spends itself in any case it cannot fix: see
 * `pour_the_draught()` for why it must NOT ask `can_be_revived()` up front.
 *
 * Every outcome, trigger, refusal and success, is told to the player's ghost as
 * well as the body. `death()` ghostizes the client BEFORE COMSIG_LIVING_DEATH
 * fires when the dead-keyloop lag switch is on, and everyone else ghosts during
 * the pour delay, so `to_chat(corpse)` alone lands nowhere. A refusal the player
 * cannot see is indistinguishable from the item being broken, which is exactly
 * the bug report that produced this paragraph. Every outcome is also `log_game`'d
 * for the same reason.
 */
/obj/item/verdigris_phylactery
	name = "spent phylactery"
	desc = "A stoppered gourd of green glass, cased in gold lattice, with a hairline crack running its whole height. There is a swallow left in the bottom and it is moving on its own."
	icon = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	icon_state = "lich_phylactery"
	inhand_icon_state = null
	w_class = WEIGHT_CLASS_SMALL
	resistance_flags = FIRE_PROOF | ACID_PROOF
	light_range = 1.5
	light_power = 0.6
	light_color = LIGHT_COLOR_GREEN
	/// Whose death we're currently listening for
	var/mob/living/listening_to
	/// Claimed the moment a death is registered so a second death inside the delay
	/// can't drink twice, and rolled back by `refuse_draught()` if the pour fails.
	var/spent = FALSE

/obj/item/verdigris_phylactery/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)
	// This is NOT the revive trigger; that stays strictly equipped()/dropped().
	// It exists so that dying with the gourd in a bag gets an explanation instead
	// of silence. See on_unheard_death().
	RegisterSignal(SSdcs, COMSIG_GLOB_MOB_DEATH, PROC_REF(on_unheard_death))

/obj/item/verdigris_phylactery/Destroy()
	stop_listening()
	UnregisterSignal(SSdcs, COMSIG_GLOB_MOB_DEATH)
	return ..()

/obj/item/verdigris_phylactery/examine(mob/user)
	. = ..()
	// `spent` is only ever TRUE for the few seconds the draught is out looking for
	// its drinker: a successful pour shatters the gourd immediately, and a refused
	// one hands the charge back. There is no lasting empty state to describe.
	if(spent)
		. += span_warning("The stopper is out and the gourd is empty. Whatever was in it is loose in the room.")
		return
	. += span_green("Carry it on your person, never in a bag. The first time you die while it's on you, it brings you back and then shatters. There is one swallow in it, and it won't spend it on a death it can't undo.")

/obj/item/verdigris_phylactery/equipped(mob/user, slot, initial)
	. = ..()
	if(!isliving(user) || listening_to == user)
		return
	stop_listening()
	listening_to = user
	RegisterSignal(user, COMSIG_LIVING_DEATH, PROC_REF(on_holder_died))

/obj/item/verdigris_phylactery/dropped(mob/user)
	. = ..()
	// dropped() also fires on slot-to-slot moves; equipped() re-registers right
	// after. A real departure just means we stop listening.
	stop_listening()

/obj/item/verdigris_phylactery/proc/stop_listening()
	if(!listening_to)
		return
	UnregisterSignal(listening_to, COMSIG_LIVING_DEATH)
	listening_to = null

/obj/item/verdigris_phylactery/proc/on_holder_died(mob/living/source, gibbed)
	SIGNAL_HANDLER
	// A gibbed body has nothing left to pour into. Say so: a refusal the player
	// cannot see is indistinguishable from the gourd being broken.
	if(gibbed)
		source.notify_revival("The gourd on your person stirs, and goes still. There is nothing left of you to pour into.", 'sound/effects/magic/RATTLEMEBONES.ogg', src)
		log_game("LICH: spent phylactery could not revive [key_name(source)]: gibbed.")
		return
	if(spent)
		return
	// Claimed, not consumed. Nothing here is irreversible until the pour succeeds.
	// The gourd only unstoppers, so a refusal below can honestly put it back.
	spent = TRUE
	source.visible_message(
		span_boldwarning("The gourd on [source]'s person unstoppers itself, and something green climbs out of it and goes looking."),
		span_green("Ilthuun's last swallow finds you on its way past, and it does not ask first."),
	)
	playsound(src, 'sound/effects/magic/RATTLEMEBONES.ogg', 60, TRUE)
	// The client is usually not in the body for any of this (death() ghostizes it
	// before COMSIG_LIVING_DEATH fires under the dead-keyloop lag switch, and anyone
	// else ghosts during the pour delay), so every outcome message goes to the ghost
	// as well as the body from here on.
	source.notify_revival("The gourd on your corpse unstoppers itself. In [LICH_PHYLACTERY_DELAY / 10] seconds it pours its last swallow into you.", 'sound/effects/magic/RATTLEMEBONES.ogg', src)
	log_game("LICH: spent phylactery triggered for [key_name(source)] at [AREACOORD(source)].")
	addtimer(CALLBACK(src, PROC_REF(pour_the_draught), source), LICH_PHYLACTERY_DELAY)

/**
 * The gourd was somewhere on a mob that just died, but NOT in a slot it listens
 * from, a bag, a box, anywhere `equipped()` does not reach. It stays inert
 * (that contract is deliberate, see the type docblock), but the ghost deserves
 * to know why nothing happened instead of filing a bug report.
 */
/obj/item/verdigris_phylactery/proc/on_unheard_death(datum/source, mob/living/died, gibbed)
	SIGNAL_HANDLER
	if(died == listening_to) // equipped deaths go through on_holder_died
		return
	if(!(src in died.get_all_contents()))
		return
	to_chat(died, span_warning("The gourd rattles once, and goes still."))
	died.notify_revival("The gourd rattles once, and goes still. It only spends its swallow from your hand, pocket, belt or suit storage, never from inside a bag.", 'sound/effects/magic/RATTLEMEBONES.ogg', src)

/**
 * The pour. Heals FIRST, then lets the heal make the revive legal.
 *
 * There is deliberately no `can_be_revived()` pre-check here, and there must not
 * be one. `/mob/living/can_be_revived()` (code/modules/mob/living/living.dm:1026)
 * is nothing but `health > HEALTH_THRESHOLD_DEAD`, and `succumb()` sets health to
 * *exactly* HEALTH_THRESHOLD_DEAD on its way out (living.dm:559), so every
 * succumbed corpse, and every corpse beaten past -100, failed that gate and the
 * draught drained away having done nothing at all. That was the bug.
 *
 * `heal_and_revive()` (living.dm:926) is built for precisely this order: it heals
 * brute, burn, oxy and tox each down to `heal_to`, calls updatehealth(), and only
 * THEN runs its own `stat == DEAD && can_be_revived()` check before reviving. Four
 * types at LICH_PHYLACTERY_REVIVE_TO leaves a human at about -20 health, which
 * clears the -100 threshold comfortably. It returns `stat != DEAD`, so its return
 * value is the honest answer to "did this work".
 *
 * If it did not work, no brain, no heart, or a body that simply will not take.
 * The charge is handed back and the gourd stays whole. A revival item that eats
 * itself on a case it cannot fix is worse than no item.
 */
/obj/item/verdigris_phylactery/proc/pour_the_draught(mob/living/drinker)
	if(QDELETED(drinker))
		// Body left the world between the death and the pour. Nobody to tell.
		log_game("LICH: spent phylactery lost its drinker: body deleted before the pour landed.")
		refuse_draught()
		return
	if(drinker.stat != DEAD)
		// A defib, a cloner or a strange reagent beat us to it by a few seconds.
		to_chat(drinker, span_green("The green looks you over, finds you already breathing, and climbs back into the glass."))
		refuse_draught()
		return

	var/came_back = drinker.heal_and_revive(
		LICH_PHYLACTERY_REVIVE_TO,
		span_boldwarning("[drinker] jerks upright in a wash of green light, and somewhere a jar breaks."),
	)
	if(!came_back)
		// to_chat alone is not enough here: a failed pour means the player is
		// still a ghost, watching a body with no client in it.
		to_chat(drinker, span_warning("The green pours itself into you, finds nothing that will hold it, and climbs back into the glass."))
		drinker.notify_revival("The gourd pours its last swallow into your body, and the body will not take it. The gourd keeps its charge.", 'sound/effects/magic/RATTLEMEBONES.ogg', src)
		log_game("LICH: spent phylactery failed to revive [key_name(drinker)] at [AREACOORD(drinker)] (husked, missing brain, or otherwise unrevivable). Charge refunded.")
		refuse_draught()
		return

	drinker.Paralyze(LICH_PHYLACTERY_STUN)
	to_chat(drinker, span_green("You're back, and you're very aware that it wasn't your doing."))
	// If the ghost grab inside revive() missed, the player is still orbiting a
	// living body with no idea it stood up. Tell them.
	drinker.notify_revival("The gourd has put your body back on its feet. Re-enter your corpse if you are not in it!", 'sound/effects/magic/RATTLEMEBONES.ogg', src)
	drinker.log_message("was revived by a spent phylactery ([src])", LOG_ATTACK, color = "green")
	log_game("LICH: [key_name(drinker)] was revived by a spent phylactery.")
	shatter()

/// Hands the one charge back. Called on every path that could not revive anyone,
/// so a refused pour costs nothing and the gourd is still there for next time.
/obj/item/verdigris_phylactery/proc/refuse_draught()
	spent = FALSE

/obj/item/verdigris_phylactery/proc/shatter()
	if(QDELETED(src))
		return
	var/turf/resting_place = get_turf(src)
	if(resting_place)
		playsound(resting_place, 'sound/effects/glass/glassbr1.ogg', 70, TRUE)
		new /obj/effect/decal/cleanable/ash(resting_place)
		resting_place.visible_message(span_warning("The gourd comes apart into green glass and ash."))
	qdel(src)

// =========================================================================
// GEAR: verdigris bridle
// A bare /obj/item, on the module's own art: "lich_bridle" (world) and
// "lich_bridle_inhand" (carried) in lich_garb.dmi, locked to the same sixteen
// colours as the robe, crown, staff and phylactery.
//
// The sprite is the BIT, not the whole headstall: two rings and the jointed
// mouthpiece, with the crooked spur that makes it the wrong shape for a mouth.
// A full bridle was drawn first and thrown out, crownpiece, cheekpieces and
// buckles cannot all be told apart in 32 pixels, and the closed strap loop it
// needs reads as a padlock. The bit is strongly horizontal and mostly gold on
// dark, so it survives at icon size. The leather is present only as the short
// strap stubs threaded through each ring, which is what keeps it from reading
// as pure metal; it is a small accent, not the subject.
//
// One inhand state serves both hands, `inhand_icon_state` is looked up in
// `lefthand_file` and `righthand_file` alike, and both point here, so it is
// drawn once, on tg's lefthand geometry (East sits right of West, the held
// item leading the facing direction).
//
// The sprite carries its own greens and golds, so there is deliberately no
// `color` on this item; tinting it would wash the palette flat.
// =========================================================================

/**
 * ## The verdigris bridle
 *
 * Ilthuun's mind control, three times, in somebody else's hands. Asked for after the boss
 * fight playtest: the ability that makes people turn on each other, as a drop.
 *
 * ### Delivery: the boss's own spell, lent while held
 *
 * The bridle grants [/datum/action/cooldown/spell/pointed/lich_corruption/bridle], a
 * subtype of the spell Ilthuun casts, through `actions_types` plus
 * `action_slots = ITEM_SLOT_HANDS`. That is the `/obj/item/teleportation_scroll` pattern
 * (code/game/objects/items/scrolls.dm:12-15) and it is here for one reason: everything
 * that makes this mechanic *safe* already lives in the spell chain, verified, and none of
 * it has to be rewritten. Click targeting, the `cast_range` check (`_pointed.dm`
 * before_cast), `can_be_lich_thralled` as the eligibility gate, antimagic propagation,
 * the "not on yourself" rejection, the invocation and the cooldown are all inherited. A
 * bespoke use-on-target path would have had to reimplement each of those, and the failure
 * mode of getting one clause wrong is a player losing their body to something that should
 * have refused. The item's own code is therefore only about charges and attribution.
 *
 * The button appears when it is in a hand and leaves when it is not, so a bridle in a bag
 * is inert cargo. `attack_self` arms the same click ability, for people who use items in
 * hand rather than hunting for the HUD button.
 *
 * ### What it costs
 *
 * LICH_BRIDLE_CHARGES possessions, spent only on one that actually lands: the parent
 * spell calls [/datum/action/cooldown/spell/pointed/lich_corruption/proc/on_thrall_applied]
 * from the branch where `apply_status_effect` returned an instance, so an antimagic shrug
 * or a target who stopped being eligible mid-cast costs the 60 second cooldown and not the
 * leather.
 *
 * At zero it goes inert instead of crumbling, a deliberate difference from the
 * phylactery, which shatters. Three reasons: the module already has one item that breaks
 * and doesn't need two; a spent strap left on a belt is a legible trophy, and a crew that
 * has just watched somebody use this should be able to look at the thing afterwards; and
 * it means nothing is ever qdel'd from inside its own spell's cast chain, which is where
 * `Activate()` still has `StartCooldown()`, `after_cast()` and a button rebuild to do.
 * The action stays granted and refuses, rather than being deleted mid-cast.
 *
 * ### Attribution
 *
 * The whole point of the tuned status effect below. Ilthuun's version names Ilthuun
 * because he is always the caster; a player-wielded version names the player, in the
 * message the victim reads, the message the room reads, the expiry message, out of the
 * victim's own mouth, on the status alert, and in `log_attack` and `log_game` with a ckey
 * attached. Threaded through the base effect's [/datum/status_effect/lich_thrall/proc/attribution_name]
 * and [/datum/status_effect/lich_thrall/proc/attribution_log] rather than duplicated.
 *
 * ### What it is deliberately not
 *
 * It is not a remote-controlled assassin. The bridled victim keeps the base effect's
 * target selection (nearest living non-ally, players first) which the wielder does not
 * get to influence, and the wielder has to be within seven tiles to cast, so the wielder
 * is frequently the nearest thing there is. Bridling somebody at knife range means being
 * knifed. That is the intended shape of the item: you point it at a fight and the fight
 * gets worse.
 *
 * Everything else is inherited from `/datum/status_effect/lich_thrall` untouched: the
 * eligibility gate in full (conscious only, never the undead, never someone already
 * possessed, never through mind-affecting antimagic, never someone inside the per-victim
 * lockout), the green wash everyone in the room can see, thralls never targeting each
 * other, and the effect ending on cuffs, stuns, crit or death.
 */
/obj/item/verdigris_bridle
	name = "verdigris bridle"
	desc = "A short strap of green-black leather, gold at the buckles and gone verdigris in every crease. There is a bit on it, and the bit is the wrong shape for a mouth. Point it at someone and it goes into their head instead: for a few seconds they are ridden, and what they reach for is whoever of their own is standing closest. There is only so much give left in the leather."
	icon = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	icon_state = "lich_bridle"
	lefthand_file = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	righthand_file = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	inhand_icon_state = "lich_bridle_inhand"
	w_class = WEIGHT_CLASS_SMALL
	resistance_flags = FIRE_PROOF | ACID_PROOF
	light_range = 1.5
	light_power = 0.6
	light_color = LIGHT_COLOR_GREEN
	actions_types = list(/datum/action/cooldown/spell/pointed/lich_corruption/bridle)
	// Only lends its spell from a hand. A bridle in a backpack does nothing.
	action_slots = ITEM_SLOT_HANDS
	/// Possessions left in the leather.
	var/charges = LICH_BRIDLE_CHARGES
	/// TRUE once the last charge is gone. One-way; there is no recharging this.
	var/inert = FALSE

/obj/item/verdigris_bridle/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/verdigris_bridle/examine(mob/user)
	. = ..()
	if(inert)
		. += span_warning("The leather is dry and grey at the creases and the bit does not move. There is nothing left in it, and there is no putting anything back.")
		return
	// Numbers first and plainly. What a wielder needs to know before they use this on
	// another player is how long they are taking somebody's body away for, and how many
	// times they can do it.
	. += span_green("<b>Point it at someone: for [LICH_BRIDLE_DURATION / 10] seconds they are not driving, and they will attack whoever is nearest to them.</b> [charges] use[charges == 1 ? "" : "s"] left, once every [DisplayTimeText(LICH_BRIDLE_COOLDOWN)].")
	. += span_green("You do not get to choose what they swing at, and you are usually the closest thing to them.")
	. += span_green("It says your name while it does it, to them, to the room, and in the record. Mind-affecting wards turn it away, and it will not take the same head twice in the same minute and a half.")

/obj/item/verdigris_bridle/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	if(inert)
		balloon_alert(user, "nothing left in it")
		return TRUE
	var/datum/action/cooldown/spell/pointed/lich_corruption/bridle/rein = locate() in actions
	if(isnull(rein) || rein.owner != user)
		return
	// Arms (or disarms) the click ability, same as clicking the HUD button.
	rein.Trigger(user)
	return TRUE

/**
 * Spends one possession. Called from the spell, and only for a landed one.
 *
 * Logs from the item's side as well as the effect's, so an admin reading one line has the
 * wielder, the victim and how much of the thing was left.
 */
/obj/item/verdigris_bridle/proc/spend_charge(mob/living/wielder, mob/living/victim)
	if(inert)
		return
	charges = max(charges - 1, 0)
	wielder?.log_message("used [src] on [key_name(victim)] ([charges] charge[charges == 1 ? "" : "s"] left)", LOG_ATTACK, color = "green")

	if(charges > 0)
		if(wielder)
			to_chat(wielder, span_green("The strap loses some of its give. [charges] left in it."))
		return
	go_inert(wielder)

/// The last charge. The strap stays; nothing in it is listening any more.
/obj/item/verdigris_bridle/proc/go_inert(mob/living/wielder)
	if(inert)
		return
	inert = TRUE
	charges = 0
	name = "slack bridle"
	desc = "A short strap of grey-green leather with a dull gold bit buckled into it. Whatever used to be in the creases has been spent down to nothing. It is a thing that was used until it was empty, and is now a souvenir of what it was used on."
	set_light_on(FALSE)

	// The action is kept and made permanently unavailable rather than deleted (see the)
	// header. Renamed so a wielder staring at their HUD can see which of it is dead.
	var/datum/action/cooldown/spell/pointed/lich_corruption/bridle/rein = locate() in actions
	if(rein)
		rein.name = "Slack Bridle"
		rein.desc = "There is nothing left in the leather."
		rein.build_all_button_icons()

	if(wielder)
		to_chat(wielder, span_warning("The last of the green goes out of the strap in your hand, and it is only leather."))
	playsound(src, 'sound/effects/magic/blind.ogg', 40, vary = TRUE)

// ===== THE SPELL =====

/**
 * The bridle's cast. A retune of Ilthuun's `lich_corruption` and nothing else: the shorter
 * possession, the longer cooldown, a whispered invocation in place of his shout, and a
 * charge check. The cast body, the range check, the eligibility gate and the antimagic
 * handling are all the parent's.
 *
 * `target` is the bridle: `/obj/item/proc/add_item_action` constructs item actions with
 * the item as the action's target (items.dm:270), which is how the spell finds its own
 * charges without a second reference to maintain.
 */
/datum/action/cooldown/spell/pointed/lich_corruption/bridle
	name = "Verdigris Bridle"
	desc = "Put the bit in one living head. They will go for whoever is nearest, including you, and everyone will know who did it."
	// A borrowed word, said quietly, rather than his shout. He is not the one holding it.
	invocation = "hold still. i only need the hands."
	invocation_type = INVOCATION_WHISPER
	cooldown_time = LICH_BRIDLE_COOLDOWN
	thrall_type = /datum/status_effect/lich_thrall/bridle
	active_msg = "You work the bit loose. Click someone to put it in..."
	deactive_msg = "You let the strap go slack."

/datum/action/cooldown/spell/pointed/lich_corruption/bridle/IsAvailable(feedback = FALSE)
	. = ..()
	if(!.)
		return FALSE
	var/obj/item/verdigris_bridle/bridle = target
	if(!istype(bridle) || bridle.inert || bridle.charges <= 0)
		if(feedback && owner)
			owner.balloon_alert(owner, "nothing left in it")
		return FALSE
	return TRUE

/datum/action/cooldown/spell/pointed/lich_corruption/bridle/on_thrall_applied(mob/living/victim, datum/status_effect/lich_thrall/possession)
	. = ..()
	var/obj/item/verdigris_bridle/bridle = target
	if(!istype(bridle))
		return
	bridle.spend_charge(owner, victim)

// ===== THE TUNED POSSESSION =====

/**
 * Ilthuun's possession, tuned down for a player to hold, and made to say who is holding it.
 *
 * The only mechanical change is [duration]: LICH_BRIDLE_DURATION against his
 * LICH_THRALL_DURATION. Everything else about the effect, the AI controller, the
 * discarded input, the target selection, the green wash, the counterplay, and the
 * per-victim lockout it leaves behind (LICH_THRALL_IMMUNITY, 90 seconds, longer than this
 * spell's own cooldown on purpose). Is the base effect's, unweakened.
 *
 * The rest of this subtype is attribution. `id` is deliberately left inherited, so
 * `has_status_effect(/datum/status_effect/lich_thrall)` and STATUS_EFFECT_UNIQUE treat a
 * bridling and a lich possession as the same thing: they cannot stack, and neither one can
 * be layered onto a victim of the other.
 */
/datum/status_effect/lich_thrall/bridle
	duration = LICH_BRIDLE_DURATION
	alert_type = /atom/movable/screen/alert/status_effect/lich_thrall/bridle

	/// What a bridled mouth says. Its own list rather than an override of the parent's:
	/// `possessed_lines` is `static`, and DM shares one storage slot for a static var
	/// across a type and its subtypes, so overriding its value is not a thing you can do.
	var/static/list/bridle_lines = list(
		"THE BIT IS IN. THE BIT IS IN. THE BIT IS IN.",
		"THIS IS NOT ME. WATCH MY HANDS, NOT MY FACE.",
		"SOMEBODY TAKE THE STRAP OFF THEM.",
	)

/datum/status_effect/lich_thrall/bridle/on_creation(mob/living/new_owner, mob/living/new_master)
	. = ..()
	if(!. || QDELETED(src))
		return
	// The alert cannot be named in on_apply: /datum/status_effect/on_creation calls on_apply
	// first and only throws the alert afterwards, so `linked_alert` is null in there. This
	// is the first point at which the victim's own alert can be told who to blame.
	if(linked_alert)
		linked_alert.desc = "[attribution_name()] has put a verdigris bridle on you. Your body is not taking \
			instructions from you for [initial(duration) / 10] seconds. Whatever you do in the meantime is not \
			your fault, and you know exactly who to say that to afterwards."

/datum/status_effect/lich_thrall/bridle/on_apply()
	. = ..()
	if(!.)
		return .
	// One extra line on top of the base effect's, so the *tool* is named as well as the
	// person. A victim who missed the first message still learns what happened to them.
	var/mob/living/rider = master_ref?.resolve()
	owner.visible_message(
		span_boldwarning("There is a strap of green leather in [rider ? "[rider]'s" : "somebody's"] hand, and the other end of it is behind [owner]'s teeth."),
		span_userdanger("There is a bit in your mouth that is not in your mouth. [rider ? "[rider]" : "Somebody"] is holding the other end of it."),
	)
	return .

/**
 * The wielder, by the name a bystander would actually see.
 *
 * Deliberately `"[rider]"` and not `real_name`: a masked wielder reads as "Unknown" here,
 * exactly as they would for anything else they did in front of witnesses. The identity an
 * admin needs is in [attribution_log], which carries the ckey.
 */
/datum/status_effect/lich_thrall/bridle/attribution_name()
	var/mob/living/rider = master_ref?.resolve()
	return rider ? "[rider]" : "whoever was holding the bridle"

/datum/status_effect/lich_thrall/bridle/attribution_log()
	var/mob/living/rider = master_ref?.resolve()
	return rider ? "[key_name(rider)] with a verdigris bridle" : "a verdigris bridle with nobody holding it"

/// Examining a bridled mob names the wielder too. It is the one attribution channel that
/// still works for somebody who walked in after the apply message scrolled past.
/datum/status_effect/lich_thrall/bridle/get_examine_text()
	return span_boldwarning("[owner.p_They()] [owner.p_are()] lit from the inside with a cold green light, and [attribution_name()] is holding the other end of the strap.")

/// Half the time, the victim's own mouth names the person steering it.
/datum/status_effect/lich_thrall/bridle/possessed_line()
	if(prob(50))
		return "[uppertext(attribution_name())] IS DRIVING THIS. I AM NOT DRIVING THIS."
	return pick(bridle_lines)

/atom/movable/screen/alert/status_effect/lich_thrall/bridle
	name = "Bridled"
	// Rewritten with the wielder's name in on_creation above. This is the fallback for a
	// bridling with no resolvable holder.
	desc = "Somebody has put a verdigris bridle on you. Your body is not taking instructions from you. \
		This will pass. Whatever you do in the meantime is not your fault."

#undef LICH_SIPHON_COOLDOWN
#undef LICH_SIPHON_DRAIN
#undef LICH_SIPHON_HEAL
#undef LICH_CROWN_DOMINION_RANGE
#undef LICH_CROWN_LESSER_UNDEAD_HP
#undef LICH_PHYLACTERY_DELAY
#undef LICH_PHYLACTERY_REVIVE_TO
#undef LICH_PHYLACTERY_STUN
#undef LICH_BRIDLE_CHARGES
#undef LICH_BRIDLE_DURATION
#undef LICH_BRIDLE_COOLDOWN

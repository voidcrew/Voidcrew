/**
 * # The Verdigris — hoard
 *
 * What is left on the sanctum floor when Ilthuun stops working. Four layers of
 * undead and a galaxy-wide ritual clock buy the raid his regalia (a robe and a
 * horned crown, green and gold, both of which cast), the staff he was leaning
 * on, the husk of the phylactery that stopped saving him, and three codices in
 * his own hand — one per school he fought in (see lich_spells.dm).
 *
 * ## Power calibration
 *
 * The occult theme's ceiling is `/obj/item/his_grace` at weight 1 in
 * `rare_loot_red` (voidcrew/modules/loot/themes/occult.dm:89) — a deliberate
 * crown-jewel jackpot, and a permanent, escalating, round-warping one. Nothing
 * here is that. Everything here is:
 *  - bounded (the phylactery is one draught and then it is glass),
 *  - narrow (the crown covers lesser undead only, only while worn, and only for
 *    the wearer — it is a hat that skeletons ignore, not a licence),
 *  - or a retune of gear that already sits in this theme's tables (the robe and
 *    crown are wizard garb with a modest armour bump and real cold protection;
 *    `/obj/item/clothing/suit/armor/riot/knight` is already loot_red weight 5,
 *    and `/obj/item/gun/magic/staff/chaos` is already rare_loot_red weight 2).
 * The staff's siphon is the one genuinely new capability, and it is capped, on a
 * cooldown, and does nothing at all against the undead — which is to say it does
 * nothing on four fifths of the map it drops in.
 *
 * ## Cross-track API
 *
 * `drop_lich_hoard(atom/drop_near)` is the entry point. Whoever owns the boss's
 * death should call it once; it is idempotent (GLOB.lich_hoard_dropped) so a
 * belt-and-braces second call from the site is harmless. It prefers a mapped
 * `/obj/effect/landmark/lich/loot_spot` and falls back to the turf of whatever
 * it was handed.
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
/// himself (~2500 HP) without this file having to reference track C's typepath.
#define LICH_CROWN_LESSER_UNDEAD_HP 300
/// Beat between death and the phylactery's draught, for the visible messages to land in
#define LICH_PHYLACTERY_DELAY (8 SECONDS)
/// Damage threshold each type is healed down to on the draught. Low on purpose:
/// four types at this value still leaves a human alive (see heal_and_revive,
/// code/modules/mob/living/living.dm:926) and you come back hurt, not fresh.
#define LICH_PHYLACTERY_REVIVE_TO 30
/// How long you lie there afterwards, remembering it
#define LICH_PHYLACTERY_STUN (15 SECONDS)

/// Set once the sanctum has been paid out, so a doubled death call can't double the hoard.
GLOBAL_VAR_INIT(lich_hoard_dropped, FALSE)

// =========================================================================
// LANDMARK
// Only the loot_spot subtype is declared here. `/obj/effect/landmark/lich`
// itself is left implicit on purpose — DM creates the intermediate path for
// free, and declaring a body for it in two tracks' files at once would be a
// duplicate definition. boss_spawn and summon_spot belong to their own tracks.
// =========================================================================

/// Optional. Marks the tile Ilthuun's hoard lands on — a plinth, an altar, the
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
	/obj/item/book/granter/action/spell/raise_thrall,
	/obj/item/book/granter/action/spell/verdigris_bolt,
	/obj/item/book/granter/action/spell/grave_mirage,
))

/**
 * Drops the hoard. Call this once, from wherever the boss dies.
 *
 * Scatters over the free tiles around the drop point rather than stacking seven
 * items on one turf — a mapped plinth reads better with the regalia laid out
 * around it, and a pile of seven is genuinely annoying to sort through.
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

	playsound(hoard_turf, 'sound/effects/magic/RATTLEMEBONES2.ogg', 65, TRUE)
	hoard_turf.visible_message(span_boldnotice("Something green and patient goes out of the room, and leaves its things behind."))
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
 * first arbitrary one sharing the lich's z-level won — ruin interiors and docked
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
// GARB — verdigris robe
// Subtypes /obj/item/clothing/suit/wizrobe (code/modules/clothing/suits/wiz_robe.dm:111)
// for slot behaviour, strip delays, CASTING_CLOTHES and the fishing-difficulty
// component. Icon, worn icon, armour and cold protection are all overridden.
// DMI states wanted: "lich_robe" (world), "lich_robe_worn" (worn overlay),
// "lich_robe_inhand" (carried, same state used for both hands).
// =========================================================================

/**
 * Wizard garb, honestly. Inheriting `clothing_flags = CASTING_CLOTHES` from
 * wizrobe is the whole point of the item: the robe and crown together are what
 * let a plain crewmember cast the garb-locked half of this codebase's magic
 * (staves of change, a `granter/action/spell/random` roll that landed on
 * something garb-gated, the Athenaeum's blink). The three spells in
 * lich_spells.dm deliberately do NOT need it — the regalia is an amplifier for
 * magic you find elsewhere, not a key to your own reward.
 */
/obj/item/clothing/suit/wizrobe/verdigris
	name = "verdigris robe"
	desc = "Green wool over a segmented gold collar, cut for someone taller than you and thinner than anyone. The hem is heavy with grave-dirt that will not brush out. It is still warm, which is the worst thing about it."
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
	. += span_green("The collar's segments are lettered. Read together they say the same word forty times, and the word is a name.")

// =========================================================================
// GARB — verdigris crown
// Subtypes /obj/item/clothing/head/wizard (code/modules/clothing/suits/wiz_robe.dm:1)
// for SNUG_FIT|CASTING_CLOTHES, strip delays and armour baseline.
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
	desc = "A horned skull-cap of hammered gold gone green in the seams, sized for a head with nothing in it. The horns are not decorative; something grew them and then someone gilded them."
	icon = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	icon_state = "lich_crown"
	worn_icon = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	worn_icon_state = "lich_crown_worn"
	lefthand_file = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	righthand_file = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	inhand_icon_state = "lich_crown_inhand"
	armor_type = /datum/armor/head_verdigris_crown
	dog_fashion = null
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
	. += span_green("<b>Worn, lesser undead within [LICH_CROWN_DOMINION_RANGE] tiles will not attack you.</b> It holds for as long as it is on your head, and it does not care what you do to them in the meantime.")
	. += span_green("It covers you and nobody standing next to you, and the big ones are not listening.")

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
// GEAR — verdigris staff
// Subtypes /obj/item/melee (code/game/objects/items/melee/misc.dm:2) for
// NEEDS_PERMIT and nothing else; every appearance var is set here.
// DMI states wanted: "lich_staff" (world) and "lich_staff_inhand" (carried —
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
 * imprecision from mattering — you get one drink per four seconds regardless.
 */
/obj/item/melee/verdigris_staff
	name = "verdigris staff"
	desc = "Hit something living with this and it drinks that thing's life, then closes your wounds with it. The undead have nothing in them to take, and against them it is only a heavy stick. A femur too long to have come off anything that walked upright, capped with a knot of gold and wound in green wire."
	icon = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	icon_state = "lich_staff"
	lefthand_file = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	righthand_file = 'voidcrew/modules/lich/icons/lich_garb.dmi'
	inhand_icon_state = "lich_staff_inhand"
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
		. += span_green("<i>It has swallowed [draughts_taken] time[draughts_taken == 1 ? "" : "s"] since it was last put down for good.</i>")

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
	target_mob.adjustToxLoss(LICH_SIPHON_DRAIN, forced = TRUE)
	user.adjustBruteLoss(-LICH_SIPHON_HEAL)
	user.adjustFireLoss(-LICH_SIPHON_HEAL)
	new /obj/effect/temp_visual/small_smoke/halfsecond(get_turf(target_mob))
	playsound(target_mob, 'sound/effects/magic/demon_consume.ogg', 35, TRUE)
	user.visible_message(
		span_warning("The gold cap of [src] flushes green, and [target_mob] goes grey around it."),
		span_green("Something warm comes up the shaft of [src] and settles behind your ribs."),
	)
	log_combat(user, target_mob, "siphoned with", src)

// =========================================================================
// GEAR — spent phylactery
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
 * one swallow left in the bottom. Carried on your person — pocket, belt, suit
 * storage, hand, never a bag, exactly as `equipped()`/`dropped()` define it (the
 * same "on your person" contract the sealed syllable uses,
 * voidcrew/modules/antag_ruins/theme_wizard.dm:293) — it registers your death.
 * When you die it waits LICH_PHYLACTERY_DELAY, drags you back at
 * LICH_PHYLACTERY_REVIVE_TO damage of each type, paralyses you for
 * LICH_PHYLACTERY_STUN, and shatters. Once. Then it is glass on the floor.
 *
 * It cannot save a gibbed or dusted body — there is nothing left to pour into —
 * and it refuses rather than spends itself in any case it cannot fix: see
 * `pour_the_draught()` for why it must NOT ask `can_be_revived()` up front.
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

/obj/item/verdigris_phylactery/Destroy()
	stop_listening()
	return ..()

/obj/item/verdigris_phylactery/examine(mob/user)
	. = ..()
	// `spent` is only ever TRUE for the few seconds the draught is out looking for
	// its drinker: a successful pour shatters the gourd immediately, and a refused
	// one hands the charge back. There is no lasting empty state to describe.
	if(spent)
		. += span_warning("The stopper is out and the bottom of it is empty. Whatever was in there is somewhere in this room, looking.")
		return
	. += span_green("Carry it on you — never in a bag — and the first death you meet while it is on your person will not be the one that keeps you. There is exactly one swallow in it, and it is not spent on a death it cannot undo.")

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
	if(spent || gibbed)
		return
	// Claimed, not consumed. Nothing here is irreversible until the pour succeeds —
	// the gourd only unstoppers, so a refusal below can honestly put it back.
	spent = TRUE
	source.visible_message(
		span_boldwarning("The gourd on [source]'s person unstoppers itself, and something green climbs out of it and goes looking."),
		span_green("Ilthuun's last swallow finds you on its way past. It is not kind and it is not asking."),
	)
	playsound(src, 'sound/effects/magic/RATTLEMEBONES.ogg', 60, TRUE)
	addtimer(CALLBACK(src, PROC_REF(pour_the_draught), source), LICH_PHYLACTERY_DELAY)

/**
 * The pour. Heals FIRST, then lets the heal make the revive legal.
 *
 * There is deliberately no `can_be_revived()` pre-check here, and there must not
 * be one. `/mob/living/can_be_revived()` (code/modules/mob/living/living.dm:1026)
 * is nothing but `health > HEALTH_THRESHOLD_DEAD`, and `succumb()` sets health to
 * *exactly* HEALTH_THRESHOLD_DEAD on its way out (living.dm:559) — so every
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
 * If it did not work — no brain, no heart, or a body that simply will not take —
 * the charge is handed back and the gourd stays whole. A revival item that eats
 * itself on a case it cannot fix is worse than no item.
 */
/obj/item/verdigris_phylactery/proc/pour_the_draught(mob/living/drinker)
	if(QDELETED(drinker))
		// Body left the world between the death and the pour. Nobody to tell.
		refuse_draught()
		return
	if(drinker.stat != DEAD)
		// A defib, a cloner or a strange reagent beat us to it by a few seconds.
		to_chat(drinker, span_green("The green looks you over, finds you already breathing, and climbs back into the glass."))
		refuse_draught()
		return

	var/came_back = drinker.heal_and_revive(
		LICH_PHYLACTERY_REVIVE_TO,
		span_boldwarning("[drinker] comes back the wrong way round, in green, with the sound of a jar breaking."),
	)
	if(!came_back)
		to_chat(drinker, span_warning("The green pours itself into you, finds nothing that will hold it, and climbs back into the glass."))
		refuse_draught()
		return

	drinker.Paralyze(LICH_PHYLACTERY_STUN)
	to_chat(drinker, span_green("You are back. You are extremely aware that you are back on somebody else's terms."))
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

#undef LICH_SIPHON_COOLDOWN
#undef LICH_SIPHON_DRAIN
#undef LICH_SIPHON_HEAL
#undef LICH_CROWN_DOMINION_RANGE
#undef LICH_CROWN_LESSER_UNDEAD_HP
#undef LICH_PHYLACTERY_DELAY
#undef LICH_PHYLACTERY_REVIVE_TO
#undef LICH_PHYLACTERY_STUN

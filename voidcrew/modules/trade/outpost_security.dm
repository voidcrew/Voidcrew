/**
 * # Outpost Security
 *
 * The economic-deterrent enforcement arm of a trader outpost: indestructible
 * lethal turrets that ONLY engage people who attacked outpost property, and
 * the indestructible airlocks of the sanctuary interior.
 *
 * Turrets never target ordinary visitors — zone PvP between players is the
 * commute's problem, not the outpost's. Aggression against the outpost itself
 * accrues warning strikes (see trader_outpost.register_aggression); the early
 * hits only issue a warning, and only once the offender crosses
 * OUTPOST_AGGRESSION_STRIKES is their mind marked and shot on sight until they leave.
 */
/obj/machinery/porta_turret/outpost
	name = "outpost defense turret"
	desc = "An over-engineered defense turret bearing a polite brass plaque: 'Violence is bad for business.'"
	installation = null
	uses_stored = FALSE // without this, process() PROCESS_KILLs over the null stored_gun and the turret never scans
	max_integrity = 500
	always_up = TRUE
	has_cover = FALSE
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	scan_range = 9
	stun_projectile = /obj/projectile/beam/laser/outpost
	lethal_projectile = /obj/projectile/beam/laser/outpost
	lethal_projectile_sound = 'sound/items/weapons/plasma_cutter.ogg'
	stun_projectile_sound = 'sound/items/weapons/plasma_cutter.ogg'
	icon_state = "syndie_off"
	base_icon_state = "syndie"
	// Players' default faction IS "neutral" — including FACTION_NEUTRAL here (like
	// the pacifist centcom turrets do) would faction-exempt every player from targeting
	faction = list(FACTION_TURRET)
	mode = 1 // TURRET_LETHAL — the define is file-local to portable_turret.dm
	turret_flags = NONE

	/// The outpost this turret defends (set by the outpost on interior load)
	var/obj/structure/overmap/trader_outpost/outpost

/obj/machinery/porta_turret/outpost/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/empprotection, EMP_PROTECT_SELF | EMP_PROTECT_WIRES)

/obj/machinery/porta_turret/outpost/Destroy()
	outpost = null
	return ..()

/obj/machinery/porta_turret/outpost/setup()
	return

// Only marked aggressors are perps; everyone else shops in peace
/obj/machinery/porta_turret/outpost/assess_perp(mob/living/carbon/human/perp)
	if(outpost?.is_turret_target(perp))
		return 10
	return 0

// Shooting the turret itself is also aggression
/obj/machinery/porta_turret/outpost/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force && outpost)
		outpost.register_aggression(user)
	return ..()

/obj/machinery/porta_turret/outpost/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	if(outpost && isliving(hitting_projectile.firer))
		outpost.register_aggression(hitting_projectile.firer)
	return ..()

/**
 * # Outpost Defense Laser
 *
 * Fired only by outpost turrets. Phases harmlessly through bystanders and only
 * impacts valid turret targets — marked aggressors and embargoed crew — so
 * enforcement never catches innocent shoppers in the crossfire. Dense obstacles
 * (walls, structures) still stop it as normal.
 */
/obj/projectile/beam/laser/outpost
	name = "outpost defense laser"

/obj/projectile/beam/laser/outpost/can_hit_target(atom/target, direct_target = FALSE, ignore_loc = FALSE, cross_failed = FALSE)
	// Let bystanders through: skip any living mob that isn't a turret target. The aimed
	// offender arrives as direct_target and any other barred mob in the path passes
	// is_turret_target(), so both are still hit by the parent check. Aggression is
	// per-mind, resolved via the firing turret's outpost, not by faction.
	if(isliving(target) && !direct_target)
		var/obj/machinery/porta_turret/outpost/turret = firer
		if(istype(turret) && !turret.outpost?.is_turret_target(target))
			return FALSE
	return ..()

/**
 * # Outpost Airlock
 *
 * Indestructible, always-powered sanctuary doors. Attacking one flags you.
 */
/obj/machinery/door/airlock/outpost
	name = "outpost airlock"
	desc = "A blast-rated airlock kept in better repair than most warship hulls."
	icon = 'icons/obj/doors/airlocks/external/external.dmi'
	overlays_file = 'icons/obj/doors/airlocks/external/overlays.dmi'
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	damage_deflection = 100
	explosion_block = 3
	hackProof = TRUE
	aiControlDisabled = AI_WIRE_DISABLED
	security_level = 6
	normal_integrity = 1000

	/// The outpost this door belongs to (set by the outpost on interior load)
	var/obj/structure/overmap/trader_outpost/outpost

/obj/machinery/door/airlock/outpost/Destroy()
	outpost = null
	return ..()

/obj/machinery/door/airlock/outpost/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force && outpost)
		outpost.register_aggression(user)
	return ..()

/obj/machinery/door/airlock/outpost/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	if(outpost && isliving(hitting_projectile.firer))
		outpost.register_aggression(hitting_projectile.firer)
	return ..()

/**
 * # Outpost Wall
 *
 * The sanctuary shell. Turfs have no back-reference to the outpost, so hits
 * resolve it through get_trader_outpost_for_turf().
 */
/turf/closed/indestructible/reinforced/titanium/outpost
	name = "outpost wall"
	desc = "Layered torpedo-rated plating. The scorch marks are from people who needed convincing."

/turf/closed/indestructible/reinforced/titanium/outpost/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force && isliving(user))
		var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(src)
		outpost?.register_aggression(user)
	return ..()

/turf/closed/indestructible/reinforced/titanium/outpost/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	if(isliving(hitting_projectile.firer))
		var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(src)
		outpost?.register_aggression(hitting_projectile.firer)
	return ..()

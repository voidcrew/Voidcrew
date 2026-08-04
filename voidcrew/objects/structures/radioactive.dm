/* Radioactive hazards for ruins */

/**
 * How long a source waits between warning nearby crew that they are being dosed.
 * Deliberately much longer than the pulse interval: sources cluster, and the point
 * is to tell someone they have walked somewhere unsafe, not to narrate every pulse.
 */
#define RADIOACTIVE_WARN_COOLDOWN (20 SECONDS)

/obj/structure/radioactive
	name = "nuclear waste barrel"
	desc = "An old container of radioactive biproducts."
	icon = 'voidcrew/icons/obj/hazard.dmi'
	icon_state = "barrel"
	density = TRUE
	// Emitters are otherwise unlit props sitting on open ground, which made them
	// indistinguishable from ordinary wasteland debris right up until they dosed
	// you. The glow marks the individual source; the ground it stands on carries
	// the zone-wide warning. Every subtype keeps light_range == rad_range, so the
	// edge of the glow is an honest safety line - keep them equal when retuning.
	light_color = LIGHT_COLOR_NUCLEAR
	light_power = 1.5
	light_range = 3
	var/rad_range = 3
	var/rad_threshold = RAD_MEDIUM_INSULATION
	var/rad_delay = 6 SECONDS
	var/rad_prob = 20
	var/_pulse = 0 // Holds the world.time interval in process
	COOLDOWN_DECLARE(warn_cooldown)

/obj/structure/radioactive/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/structure/radioactive/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/structure/radioactive/process()
	if(world.time > _pulse)
		if(prob(rad_prob))
			Nuke()
		_pulse = world.time + rad_delay
	..()

/obj/structure/radioactive/bullet_act(obj/projectile/P)
	disturb()
	. = ..()

/obj/structure/radioactive/attack_tk(mob/user)
	disturb()

/obj/structure/radioactive/attack_paw(mob/user)
	disturb()

/obj/structure/radioactive/attack_alien(mob/living/carbon/alien/user)
	disturb()

/obj/structure/radioactive/attack_animal(mob/living/simple_animal/M)
	disturb()

/obj/structure/radioactive/attack_hand(mob/user)
	. = ..()
	if(.)
		return
	disturb()

/obj/structure/radioactive/Bumped(atom/movable/AM)
	if(!iseffect(AM))
		disturb()

/**
 * Jostling a source sets it off, but on the same cooldown the passive pulse uses.
 * These are dense and the biome that seeds them spawns a lot of wandering hostiles,
 * so an ungated Bumped() let a single mob pathing into a barrel fire an unbounded
 * stream of full-strength pulses - and queue a 17x17 turf sweep into SSradiation
 * for each one.
 */
/obj/structure/radioactive/proc/disturb()
	if(world.time <= _pulse)
		return
	_pulse = world.time + rad_delay
	Nuke()

/obj/structure/radioactive/proc/Nuke(atom/movable/AM)
	radiation_pulse(src, max_range = rad_range, threshold = rad_threshold, chance = rad_prob)
	warn_nearby()

/**
 * Tells anyone inside the radius that they are being dosed right now. The irradiated
 * HUD alert only appears once radiation has already landed, so on open ground the
 * first feedback a player got was toxin damage with nothing naming the cause.
 * The cooldown only starts once somebody was actually warned, so the first person to
 * walk into range is always told promptly rather than landing mid-cooldown.
 */
/obj/structure/radioactive/proc/warn_nearby()
	if(!COOLDOWN_FINISHED(src, warn_cooldown))
		return
	var/warned_anyone = FALSE
	for(var/mob/living/carbon/human/nearby in range(rad_range, src))
		if(!nearby.client || HAS_TRAIT(nearby, TRAIT_RADIMMUNE))
			continue
		to_chat(nearby, span_danger("Your teeth buzz and your skin prickles. Something close by is badly irradiated."))
		warned_anyone = TRUE
	if(warned_anyone)
		COOLDOWN_START(src, warn_cooldown, RADIOACTIVE_WARN_COOLDOWN)

/obj/structure/radioactive/waste
	name = "leaking waste barrel"
	desc = "It wasn't uncommon for early vessels to simply dump their waste like this out the airlock. However this proved to be a terrible long-term solution."
	icon_state = "barrel_tipped"
	anchored = TRUE
	light_range = 5
	rad_range = 5
	rad_threshold = RAD_HEAVY_INSULATION

/obj/structure/radioactive/stack
	name = "stack of nuclear waste"
	desc = "A large amount of discarded nuclear waste. This can't be good for the environment..."
	icon_state = "barrel_3"
	light_power = 2
	rad_threshold = RAD_EXTREME_INSULATION
	rad_prob = 30

/obj/structure/radioactive/supermatter
	name = "decayed supermatter crystal"
	desc = "An abandoned supermatter crystal undergoing extreme nuclear decay as a result of poor maintenence and disposal."
	icon_state = "smdecay"
	anchored = TRUE
	light_power = 2
	light_range = 5
	rad_range = 5
	rad_threshold = RAD_FULL_INSULATION
	rad_prob = 40

#undef RADIOACTIVE_WARN_COOLDOWN

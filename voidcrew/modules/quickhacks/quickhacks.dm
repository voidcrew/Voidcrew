/**
 * # Quickhacks
 *
 * One thing done to one thing: the single-target hacks first written for the
 * Machine Communion boon (voidcrew/modules/antag_ruins/ascension_mech.dm) and
 * shared since with cyberdecks (voidcrew/modules/cyberware/ware_line_deck.dm).
 * Moved here unchanged. What a given source carries, how far it reaches and
 * how its menu reads is its [/datum/quickhack_kit] (quickhack_kit.dm).
 *
 * The descs below quote numbers on purpose: they are the boon's tooltips. A
 * deck's menu shows hack names only.
 */

/// Seconds a bolted-and-live door stays electrified.
#define COMMUNION_ELECTRIFY_SECONDS 30
/// Burn a communion-live door lands. Equal to the floor of a stock powernet shock, ELECTROCUTE_DAMAGE().
#define COMMUNION_ELECTRIFY_DAMAGE 20
/// Stun on top of the burn. Matches the paralyse a carbon takes from a stock shock, so carbons feel no change.
#define COMMUNION_ELECTRIFY_STUN (4 SECONDS)
/// How long an overloaded machine buzzes before it goes.
#define COMMUNION_OVERLOAD_DELAY (4 SECONDS)
/// Radius and lifetime of the Silence bubble.
#define COMMUNION_JAM_RANGE 9
#define COMMUNION_JAM_DURATION (45 SECONDS)
/// How long a radio switched off by Cutout or Silence stays dead before it recovers.
#define COMMUNION_RADIO_OFF_DURATION (45 SECONDS)
/// Burn per full standard cell drained by Feedback Surge, and the ceiling on it.
#define COMMUNION_SURGE_PER_CELL 12
#define COMMUNION_SURGE_MAX 60
#define COMMUNION_SURGE_MIN 5

// =========================================================================
// THE QUICKHACKS
// =========================================================================

/**
 * One thing Machine Communion can do to one thing.
 *
 * Stateless singletons, built once into a global list and shared by every owner, so
 * nothing here may hold per-cast state. Timers hang off the singleton, which is fine
 * because it is never deleted.
 */
/datum/machine_quickhack
	/// Shown on the radial slice.
	var/name = "Quickhack"
	/// Shown in the slice's tooltip. Lead with the effect, then the numbers.
	var/desc = ""
	/// Radial slice icon.
	var/radial_icon = 'icons/mob/actions/actions_AI.dmi'
	/// Icon state paired with radial_icon.
	var/radial_icon_state = "overload_machine"
	/// Cooldown this hack puts on the whole ability.
	var/cooldown = 20 SECONDS

/// Can this hack be run on this target at all? Decides whether the slice is even shown.
/datum/machine_quickhack/proc/valid_for(atom/target, mob/living/user)
	return FALSE

/// Do it. Return TRUE if it landed; a FALSE return costs no cooldown.
/datum/machine_quickhack/proc/execute(atom/target, mob/living/user)
	return FALSE

/// Every quickhack, built once on demand.
GLOBAL_LIST_EMPTY(machine_quickhacks)

/proc/get_machine_quickhacks()
	if(!length(GLOB.machine_quickhacks))
		for(var/datum/machine_quickhack/hack_type as anything in subtypesof(/datum/machine_quickhack))
			GLOB.machine_quickhacks += new hack_type()
	return GLOB.machine_quickhacks

// ===== OVERLOAD =====

/**
 * Straight off `/datum/action/innate/ai/ranged/overload_machine` (malf_ai_modules.dm:521),
 * including its blacklist, with a smaller blast because this one is repeatable rather
 * than two uses a purchase. Lights burst instead of exploding. A light bulb should not
 * take out a wall.
 */
/datum/machine_quickhack/overload
	name = "Overload"
	desc = "Feed the machine power until it comes apart. Four seconds of loud buzzing, then a small explosion that destroys it. Lights just burst."
	radial_icon_state = "overload_machine"
	cooldown = 45 SECONDS

/datum/machine_quickhack/overload/valid_for(atom/target, mob/living/user)
	if(!ismachinery(target))
		return FALSE
	var/obj/machinery/victim = target
	if(victim.resistance_flags & INDESTRUCTIBLE)
		return FALSE
	return !is_type_in_typecache(victim, GLOB.blacklisted_malf_machines)

/datum/machine_quickhack/overload/execute(atom/target, mob/living/user)
	var/obj/machinery/victim = target
	victim.audible_message(span_userdanger("[victim] starts buzzing, loudly."))
	playsound(victim, SFX_SPARKS, 60, TRUE)
	user.playsound_local(user, 'sound/misc/interference.ogg', 40, FALSE)
	// ADMIN_VERBOSEJMP expands to a ternary over its argument, so it needs a plain
	// variable, a proc call inlined here doesn't parse inside the string
	var/turf/blast_site = get_turf(victim)
	message_admins("[ADMIN_LOOKUPFLW(user)] overloaded [victim.name] ([victim.type]) at [ADMIN_VERBOSEJMP(blast_site)] with Machine Communion.")
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(communion_burst_machine), victim, 1, 3), COMMUNION_OVERLOAD_DELAY)
	return TRUE

/**
 * The end of an overload, single or mass: the machine comes apart and takes the tile
 * with it. Lights burst instead of exploding, because a light bulb should not take out
 * a wall. Blast radii are arguments because the mass version fires a dozen of these and
 * has to be much smaller per machine, see [/datum/machine_masshack/overload].
 */
/proc/communion_burst_machine(obj/machinery/victim, heavy_range = 1, light_range = 3, flash_range = null)
	if(QDELETED(victim))
		return
	if(istype(victim, /obj/machinery/light))
		var/obj/machinery/light/bulb = victim
		bulb.break_light_tube()
		return
	explosion(victim, heavy_impact_range = heavy_range, light_impact_range = light_range, flash_range = flash_range)
	if(!QDELETED(victim))
		qdel(victim)

// ===== CUT THE SAFETIES =====

/**
 * `emag_act` on anything that has one. The compatible-type list is lifted from the malf
 * targeted override module (malf_ai_modules.dm:1090-1097) so the surface area is a known
 * quantity rather than "every atom in the game".
 */
/datum/machine_quickhack/safeties
	name = "Cut the Safeties"
	desc = "Strip the target's safety interlocks. Exactly what an emag would do to it, which depends entirely on what it is."
	radial_icon = 'icons/obj/card.dmi'
	radial_icon_state = "emag"
	cooldown = 25 SECONDS

/datum/machine_quickhack/safeties/valid_for(atom/target, mob/living/user)
	var/static/list/compatible = list(
		/obj/machinery,
		/obj/item/modular_computer,
		/obj/item/radio/intercom,
		/mob/living/basic/bot,
		/mob/living/silicon,
		/mob/living/simple_animal/bot,
	)
	if(!is_type_in_list(target, compatible))
		return FALSE
	if(ismachinery(target))
		var/obj/machinery/machine = target
		return machine.is_operational
	return TRUE

/datum/machine_quickhack/safeties/execute(atom/target, mob/living/user)
	if(!target.emag_act(user))
		target.balloon_alert(user, "nothing to strip!")
		return FALSE
	playsound(target, SFX_SPARKS, 50, TRUE)
	to_chat(user, span_notice("[target] drops its safety interlocks."))
	return TRUE

// ===== BOLTS =====

/datum/machine_quickhack/bolts
	name = "Bolts"
	desc = "Throw the door's bolts, or pull them if they are already down. Works on the AI wire, so a cut door will not answer."
	radial_icon_state = "lockdown"
	cooldown = 8 SECONDS

/datum/machine_quickhack/bolts/valid_for(atom/target, mob/living/user)
	return istype(target, /obj/machinery/door/airlock)

/datum/machine_quickhack/bolts/execute(atom/target, mob/living/user)
	var/obj/machinery/door/airlock/door = target
	if(!door.canAIControl(user) || door.machine_stat)
		door.balloon_alert(user, "no interface!")
		return FALSE
	if(door.locked)
		door.unbolt()
		door.balloon_alert(user, "bolts up")
	else
		door.bolt()
		door.balloon_alert(user, "bolts down")
	return TRUE

// ===== ELECTRIFY =====

/**
 * Stock electrification alone is not worth a capstone hack. A shock through the frame is
 * `ELECTROCUTE_DAMAGE(area APC's spare energy)`, which is 0 below a kilojoule and jumps
 * straight to 20 above it, so on a derelict with a flat cell the door does nothing at all,
 * no burn and no stun, and `shock()` returning FALSE means it opens for them anyway.
 *
 * So a door the vestige has electrified carries its own current: a flat
 * [COMMUNION_ELECTRIFY_DAMAGE] burn and a [COMMUNION_ELECTRIFY_STUN] stun no matter how little
 * the local powernet has left in it. The door still has to be powered at all, same as ever.
 * The hack cannot be cast on a dead one. That is what `communion_live` below is for.
 */
/datum/machine_quickhack/electrify
	name = "Electrify"
	desc = "Run the door's frame live for 30 seconds. It draws on your own current rather than the area's, so a \
		nearly-empty APC still lands the shock. Touching it without insulated gloves is 20 burn and a stun."
	radial_icon = 'icons/obj/machines/wallmounts.dmi'
	radial_icon_state = "apc-spark"
	cooldown = 20 SECONDS

/datum/machine_quickhack/electrify/valid_for(atom/target, mob/living/user)
	return istype(target, /obj/machinery/door/airlock)

/datum/machine_quickhack/electrify/execute(atom/target, mob/living/user)
	var/obj/machinery/door/airlock/door = target
	if(!door.canAIControl(user) || door.machine_stat)
		door.balloon_alert(user, "no interface!")
		return FALSE
	door.set_electrified(COMMUNION_ELECTRIFY_SECONDS, user)
	door.set_communion_live(COMMUNION_ELECTRIFY_SECONDS)
	door.balloon_alert(user, "live")
	playsound(door, SFX_SPARKS, 50, TRUE)
	return TRUE

/// Set for as long as a Machine Communion electrification lasts. See [/datum/machine_quickhack/electrify].
/obj/machinery/door/airlock/var/communion_live = FALSE

/// Makes this airlock's electrification self-powered for `seconds`, matching the seconds `set_electrified` takes.
/obj/machinery/door/airlock/proc/set_communion_live(seconds)
	communion_live = TRUE
	addtimer(VARSET_CALLBACK(src, communion_live, FALSE), seconds SECONDS, TIMER_UNIQUE|TIMER_OVERRIDE)

/**
 * Every path that shocks somebody on an airlock funnels through here, so overriding it once
 * covers bumping the door, touching it, and prying at it with a crowbar alike. Off a
 * communion-live door we do the parent's job by hand rather than through `electrocute_mob`,
 * which reads its damage off the area's APC and refuses non-carbons outright.
 *
 * `electrocute_act` with default flags still runs the victim's siemens coefficient, so
 * insulated gloves zero it out and nothing lands, same as an ordinary electrified door.
 * The explicit Paralyze is what carries the stun onto simple and basic mobs, whose
 * `electrocute_act` only ever adjusts fire loss.
 */
/obj/machinery/door/airlock/shock(mob/living/user, prb)
	if(!communion_live || !isElectrified())
		return ..()
	// Gating lifted from the parent: same power requirement, same one-second-per-victim grace
	// so a live doorway is not a stunlock, same probability roll.
	if(!istype(user) || !hasPower())
		return FALSE
	if(HAS_TRAIT(user, TRAIT_AIRLOCK_SHOCKIMMUNE))
		return FALSE
	if(!COOLDOWN_FINISHED(src, shockCooldown))
		return FALSE
	if(!prob(prb))
		return FALSE
	do_sparks(5, TRUE, src)
	if(!user.electrocute_act(COMMUNION_ELECTRIFY_DAMAGE, src))
		return FALSE
	user.Paralyze(COMMUNION_ELECTRIFY_STUN)
	log_combat(src, user, "electrocuted")
	COOLDOWN_START(src, shockCooldown, 1 SECONDS)
	ADD_TRAIT(user, TRAIT_AIRLOCK_SHOCKIMMUNE, REF(src))
	addtimer(TRAIT_CALLBACK_REMOVE(user, TRAIT_AIRLOCK_SHOCKIMMUNE, REF(src)), 1 SECONDS)
	return TRUE

// ===== KILL THE POWER =====

/datum/machine_quickhack/kill_power
	name = "Kill the Power"
	desc = "Flip an APC's breaker. Lights, equipment and air handling across that whole area go dead until it is flipped back."
	radial_icon = 'icons/obj/machines/wallmounts.dmi'
	radial_icon_state = "apc0"
	cooldown = 30 SECONDS

/datum/machine_quickhack/kill_power/valid_for(atom/target, mob/living/user)
	return isapc(target)

/datum/machine_quickhack/kill_power/execute(atom/target, mob/living/user)
	var/obj/machinery/power/apc/apc = target
	if(apc.aidisabled || !apc.is_operational || apc.failure_timer)
		apc.balloon_alert(user, "no interface!")
		return FALSE
	apc.toggle_breaker(user)
	playsound(apc, 'sound/machines/terminal/terminal_off.ogg', 50, FALSE)
	return TRUE

// ===== BURST THE LIGHTS =====

/**
 * The malf blackout, aimed at one APC instead of every APC on the station.
 *
 * It breaks the tubes directly rather than going through `overload_lighting()`, which
 * silently does nothing when the APC's cell is flat (apc_main.dm:732-736), a hack that
 * fails invisibly is worse than one that does not exist.
 */
/datum/machine_quickhack/burst_lights
	name = "Burst the Lights"
	desc = "Push an APC's lighting circuit until every bulb in its area breaks. They stay broken."
	radial_icon_state = "blackout"
	cooldown = 30 SECONDS

/datum/machine_quickhack/burst_lights/valid_for(atom/target, mob/living/user)
	return isapc(target)

/datum/machine_quickhack/burst_lights/execute(atom/target, mob/living/user)
	var/obj/machinery/power/apc/apc = target
	if(apc.aidisabled)
		apc.balloon_alert(user, "no interface!")
		return FALSE
	var/burst = 0
	for(var/obj/machinery/light/bulb as anything in apc.get_lights())
		if(QDELETED(bulb))
			continue
		bulb.on = TRUE
		bulb.break_light_tube()
		burst++
		CHECK_TICK
	if(!burst)
		apc.balloon_alert(user, "no lights on this circuit!")
		return FALSE
	playsound(apc, 'sound/effects/light_flicker.ogg', 60, FALSE)
	to_chat(user, span_notice("Overcurrent applied. [burst] bulb\s gone."))
	return TRUE

// ===== FEEDBACK SURGE =====

/**
 * The headline, and the part of the spec that has no prior art to lift: everything a
 * person is carrying that holds a charge dumps that charge into the person.
 *
 * The shock scales with what they were carrying, so this is a hard counter to somebody
 * walking around with an armoury and close to nothing against somebody in a jumpsuit.
 * SHOCK_NOGLOVES is deliberate, the current is coming out of their own belt, and
 * insulated gloves have nothing to do with it.
 */
/datum/machine_quickhack/feedback_surge
	name = "Feedback Surge"
	desc = "Dump everything a person's gear is holding into the person. Empties every power cell they are carrying and shocks them for up to 60 burn, scaled to how much charge there was."
	radial_icon = 'icons/obj/weapons/baton.dmi'
	radial_icon_state = "stunbaton_active"
	cooldown = 60 SECONDS

/datum/machine_quickhack/feedback_surge/valid_for(atom/target, mob/living/user)
	if(!isliving(target) || target == user)
		return FALSE
	var/mob/living/victim = target
	return victim.stat != DEAD

/datum/machine_quickhack/feedback_surge/execute(atom/target, mob/living/user)
	var/mob/living/victim = target
	var/drained = vestige_drain_carried_cells(victim)
	if(drained <= 0)
		victim.balloon_alert(user, "carrying nothing live!")
		return FALSE

	var/shock = clamp(round(drained / STANDARD_CELL_CHARGE) * COMMUNION_SURGE_PER_CELL, COMMUNION_SURGE_MIN, COMMUNION_SURGE_MAX)
	victim.visible_message(
		span_boldwarning("Everything [victim] is carrying goes off at once in a sheet of sparks!"),
		span_userdanger("Every powered thing on you empties itself through you!"),
	)
	do_sparks(5, FALSE, victim)
	playsound(victim, 'sound/items/weapons/egloves.ogg', 75, TRUE)
	victim.electrocute_act(shock, user, flags = SHOCK_NOGLOVES|SHOCK_KNOCKDOWN)
	victim.drop_all_held_items()
	return TRUE

// ===== CUTOUT =====

/**
 * The quiet half of the same trick. No shock, no stun, no announcement, their gear
 * simply stops working and their radios stop transmitting, and they find out when they
 * pull a trigger. Half the cooldown, none of the damage.
 */
/datum/machine_quickhack/cutout
	name = "Cutout"
	desc = "Quietly empty every power cell a person is carrying and switch their radios off for 45 seconds. No shock and no stun; their gear just stops."
	radial_icon = 'icons/obj/weapons/baton.dmi'
	radial_icon_state = "stunbaton_nocell"
	cooldown = 35 SECONDS

/datum/machine_quickhack/cutout/valid_for(atom/target, mob/living/user)
	if(!isliving(target) || target == user)
		return FALSE
	var/mob/living/victim = target
	return victim.stat != DEAD

/datum/machine_quickhack/cutout/execute(atom/target, mob/living/user)
	var/mob/living/victim = target
	var/drained = vestige_drain_carried_cells(victim)
	var/silenced = 0
	for(var/obj/item/radio/radio in victim.get_all_contents())
		if(communion_radio_off(radio))
			silenced++
	if(drained <= 0 && !silenced)
		victim.balloon_alert(user, "carrying nothing live!")
		return FALSE
	to_chat(user, span_notice("[victim]'s gear goes quiet. [victim.p_they(TRUE)] [victim.p_do()]n't seem to have noticed."))
	// The tell lands a beat later, and it is the only one they get.
	addtimer(CALLBACK(src, PROC_REF(notice), victim), 2 SECONDS)
	return TRUE

/datum/machine_quickhack/cutout/proc/notice(mob/living/victim)
	if(QDELETED(victim) || victim.stat == DEAD)
		return
	to_chat(victim, span_warning("Something in your gear clicks, and every charge light you can see goes out."))

// ===== SILENCE =====

/datum/machine_quickhack/silence
	name = "Silence"
	desc = "Jam every radio within nine tiles of what you clicked for 45 seconds, and switch the ones already in range off outright for as long."
	radial_icon = 'icons/obj/devices/syndie_gadget.dmi'
	radial_icon_state = "jammer"
	cooldown = 40 SECONDS

/datum/machine_quickhack/silence/valid_for(atom/target, mob/living/user)
	var/turf/spot = get_turf(target)
	if(isnull(spot))
		return FALSE
	// Only offered where there is somebody to silence. Jamming an empty corridor burns
	// forty seconds for nothing, and this hack is targetable at almost anything.
	for(var/mob/living/candidate in view(COMMUNION_JAM_RANGE, spot))
		if(candidate != user)
			return TRUE
	return FALSE

/datum/machine_quickhack/silence/execute(atom/target, mob/living/user)
	var/turf/spot = get_turf(target)
	if(isnull(spot))
		return FALSE
	new /obj/item/jammer/machine_communion(spot)
	for(var/mob/living/holder in view(COMMUNION_JAM_RANGE, spot))
		for(var/obj/item/radio/radio in holder.get_all_contents())
			communion_radio_off(radio)
	for(var/obj/item/radio/loose in view(COMMUNION_JAM_RANGE, spot))
		communion_radio_off(loose)
	to_chat(user, span_notice("Everything with an aerial around [target] stops talking."))
	playsound(spot, 'sound/misc/interference.ogg', 40, TRUE)
	return TRUE

/**
 * The Silence bubble.
 *
 * `is_within_radio_jammer_range()` walks `GLOB.active_jammers` and reads `.range` off
 * each entry (traitordevices.dm:318-322), so the cheapest correct way to jam an area is
 * to be a jammer. Invisible, unclickable, and it deletes itself.
 */
/obj/item/jammer/machine_communion
	name = "silence"
	desc = "You should not be able to see this."
	invisibility = INVISIBILITY_ABSTRACT
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	range = COMMUNION_JAM_RANGE

/obj/item/jammer/machine_communion/Initialize(mapload)
	. = ..()
	active = TRUE
	GLOB.active_jammers |= src
	QDEL_IN(src, COMMUNION_JAM_DURATION)

// ===== SHARED HELPERS =====

/**
 * Switches a radio off the way an EMP does, and books the same recovery.
 *
 * `set_broadcasting(FALSE)` is NOT this: broadcasting is the open-mic hot function,
 * already off on every standard headset, and `talk_into` ignores it entirely
 * (radio.dm:233-234 says so in as many words). The switch that actually gates both
 * talking and hearing is `on`, and riding the radio's own EMP bookkeeping
 * (`emped` + [/obj/item/radio/proc/end_emp_effect]) means a real EMP landing
 * mid-outage extends it instead of having it cancelled by our recovery timer.
 *
 * Returns TRUE if the radio was on and is now off.
 */
/proc/communion_radio_off(obj/item/radio/radio, duration = COMMUNION_RADIO_OFF_DURATION)
	if(QDELETED(radio) || !radio.on)
		return FALSE
	radio.emped++
	radio.set_on(FALSE)
	addtimer(CALLBACK(radio, TYPE_PROC_REF(/obj/item/radio, end_emp_effect), radio.emped), duration)
	return TRUE

/**
 * Empties every power cell inside an atom and returns the total charge taken, in joules.
 *
 * Works off `get_cell()`, which is the codebase's one honest answer to "does this thing
 * hold a charge", energy guns, security batons, MOD suits, tablets, defibs, cyborgs and
 * bare cells all implement it. Cells are deduplicated because a gun and the cell inside
 * it both show up in `get_all_contents()` and both resolve to the same cell.
 */
/proc/vestige_drain_carried_cells(atom/holder)
	if(QDELETED(holder))
		return 0
	var/total = 0
	var/list/already_drained = list()
	for(var/atom/movable/thing as anything in holder.get_all_contents())
		if(thing == holder)
			continue
		var/obj/item/stock_parts/power_store/cell = thing.get_cell()
		if(isnull(cell) || (cell in already_drained))
			continue
		already_drained += cell
		if(cell.charge <= 0)
			continue
		total += cell.use(cell.charge, TRUE)
		cell.update_appearance()
		if(thing != cell)
			thing.update_appearance()
	return total

#undef COMMUNION_ELECTRIFY_SECONDS
#undef COMMUNION_ELECTRIFY_DAMAGE
#undef COMMUNION_ELECTRIFY_STUN
#undef COMMUNION_OVERLOAD_DELAY
#undef COMMUNION_JAM_RANGE
#undef COMMUNION_JAM_DURATION
#undef COMMUNION_RADIO_OFF_DURATION
#undef COMMUNION_SURGE_PER_CELL
#undef COMMUNION_SURGE_MAX
#undef COMMUNION_SURGE_MIN

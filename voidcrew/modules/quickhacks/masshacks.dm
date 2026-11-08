/**
 * # Room hacks
 *
 * The mass hacks first written for the Machine Communion boon's second button
 * (voidcrew/modules/antag_ruins/ascension_mech.dm), moved here unchanged so a
 * cyberdeck can carry one. What a source carries is its [/datum/quickhack_kit].
 */

// ===== THE MASS HACKS =====
// The second button. Everything below is room-scale, and the descs quote these
// numbers literally, keep them in sync.

/// How far a mass hack reaches from the caster. Shorter than the single-target reach
/// on purpose: this is the room you are standing in, not the room next door.
#define COMMUNION_MASS_RANGE 7
/// Most machines any one mass hack will touch. Caps the blast, the mob count and the tick cost.
#define COMMUNION_MASS_CAP 12
/// How long the whole room buzzes before Overload the Room lands. A second longer than
/// the single-target version, because there is a great deal more to run away from.
#define COMMUNION_MASS_OVERLOAD_DELAY (5 SECONDS)
/// Gap between two machines going up, so a dozen explosions do not land on one tick.
#define COMMUNION_MASS_OVERLOAD_STAGGER (0.2 SECONDS)
/// Blast radii of one machine in a mass overload. Identical to the single-target blast.
/// This is a dozen full Overloads going off at once, not a dozen small ones. EXPLODE_HEAVY
/// on a wall is `dismantle_wall(prob(50), TRUE)`, which always takes the wall, so a room
/// that goes up this way is stripped to the girders and an outer wall may well go with it.
/// That is the intent; the five-second buzz is what everybody in the room gets instead.
#define COMMUNION_MASS_OVERLOAD_HEAVY 1
#define COMMUNION_MASS_OVERLOAD_LIGHT 3
#define COMMUNION_MASS_OVERLOAD_FLASH 3

/// Arc Flash: how many volleys it throws and how far apart.
#define COMMUNION_ARC_PULSES 5
#define COMMUNION_ARC_INTERVAL (1.5 SECONDS)
/// How far a machine will reach for somebody to earth itself through.
#define COMMUNION_ARC_REACH 5
/// Burn one arc lands. Everyone in the room takes one per volley.
#define COMMUNION_ARC_DAMAGE 14

/// Most machines Wake the Machines will stand up. Lower than the general cap; each one is a mob.
#define COMMUNION_WAKE_CAP 8
/// How long a woken machine lasts before it falls apart.
#define COMMUNION_WAKE_DURATION (2 MINUTES)
/// Multiplier on a woken machine's health and melee damage over a stock animated one.
#define COMMUNION_WAKE_SCALE 2
/// Filter key and colour for the outline a woken machine wears, so the room can tell
/// which vending machine is yours.
#define COMMUNION_WAKE_FILTER "communion_woken"
#define COMMUNION_WAKE_COLOR "#63c8d6"

// =========================================================================
// THE MASS HACKS
// =========================================================================

/**
 * One thing Mass Hack can do to one room. Stateless singletons like the quickhacks,
 * built once into a global list and shared by every owner, so nothing here may hold
 * per-cast state. Timers hang off the singleton, which is fine because it is never
 * deleted; anything a timer needs comes in as a callback argument.
 */
/datum/machine_masshack
	/// Shown on the radial slice.
	var/name = "Mass Hack"
	/// Shown in the slice's tooltip. Lead with the effect, then the numbers.
	var/desc = ""
	/// Radial slice icon.
	var/radial_icon = 'icons/mob/actions/actions_AI.dmi'
	/// Icon state paired with radial_icon.
	var/radial_icon_state = "overload_machine"
	/// Cooldown this hack puts on the ability.
	var/cooldown = 2 MINUTES

/// Is there anything in this room for this hack to do? Decides whether the slice is shown.
/datum/machine_masshack/proc/available(mob/living/user, turf/center)
	return FALSE

/// Do it. Return TRUE if it landed; a FALSE return costs no cooldown.
/datum/machine_masshack/proc/execute(mob/living/user, turf/center)
	return FALSE

/// Every mass hack, built once on demand.
GLOBAL_LIST_EMPTY(machine_masshacks)

/proc/get_machine_masshacks()
	if(!length(GLOB.machine_masshacks))
		for(var/datum/machine_masshack/hack_type as anything in subtypesof(/datum/machine_masshack))
			GLOB.machine_masshacks += new hack_type()
	return GLOB.machine_masshacks

/**
 * The machines in a room that a mass hack may touch, nearest first, capped.
 *
 * The filter matters more here than it does for a single click, because the player is not
 * choosing the targets. Two things it deliberately drops that `ismachinery` would keep:
 *
 * - **Atmospherics.** Pipes, vents and scrubbers are machinery, most of a room's pipework
 *   is under the floor and invisible, and eating a distribution loop is not a hack, it is
 *   an atmos incident nobody asked for.
 * - **Anything hidden.** Power terminals and buried plumbing sit on the tile at
 *   INVISIBILITY_MAXIMUM. If the caster cannot see it, it is not "in the room".
 *
 * `standing_only` narrows it further to the free-standing machines, dense, and not a
 * door. That is the set Wake the Machines uses, because a light switch getting up and
 * walking around is not the effect anybody wants.
 *
 * `skip_lights` drops light fixtures. Overload the Room uses it so that a room with six
 * ceiling tubes does not spend half its twelve-machine budget on bulbs; it bursts them
 * separately and for free. Arc Flash deliberately leaves them in, a light tube arcing at
 * somebody is exactly the effect.
 */
/proc/communion_mass_machines(turf/center, cap = COMMUNION_MASS_CAP, standing_only = FALSE, skip_lights = FALSE)
	var/list/found = list()
	if(isnull(center))
		return found
	var/static/list/mass_hack_blacklist = typecacheof(list(
		/obj/machinery/atmospherics,
		/obj/machinery/portable_atmospherics,
		/obj/machinery/duct,
		/obj/machinery/power/terminal,
		// The cover is the closed turret's sprite standing in for the turret, which is in
		// view right beside it. Taking both would double-count one object.
		/obj/machinery/porta_turret_cover,
	))
	for(var/obj/machinery/machine in view(COMMUNION_MASS_RANGE, center))
		if(machine.resistance_flags & INDESTRUCTIBLE)
			continue
		if(is_type_in_typecache(machine, GLOB.blacklisted_malf_machines) || is_type_in_typecache(machine, mass_hack_blacklist))
			continue
		if(machine.invisibility > SEE_INVISIBLE_LIVING)
			continue
		if(skip_lights && istype(machine, /obj/machinery/light))
			continue
		if(standing_only && (!machine.density || istype(machine, /obj/machinery/door)))
			continue
		found += machine

	if(length(found) <= cap)
		return found
	// view() is documented nowhere as returning in distance order, and which machines get
	// cut is the difference between a room hack and a corridor hack. Bucket by distance.
	var/list/nearest = list()
	for(var/distance in 0 to COMMUNION_MASS_RANGE)
		for(var/obj/machinery/machine as anything in found)
			if(get_dist(center, machine) != distance)
				continue
			nearest += machine
			if(length(nearest) >= cap)
				return nearest
	return nearest

// ===== OVERLOAD THE ROOM =====

/**
 * The single-target Overload, applied to everything at once, at full strength.
 *
 * Every machine gets the same blast the single-target hack gives one, heavy 1, light 3,
 * so this is twelve real explosions in a room, not twelve small ones. It levels the room:
 * EXPLODE_HEAVY always dismantles a wall, EXPLODE_LIGHT takes one at `prob(hardness)`, and
 * an outer wall in the pattern means the compartment vents. One EXPLODE_LIGHT alone is 30
 * brute, sixteen seconds of knockdown and a real chance of losing a limb, and nobody
 * standing in this gets only one.
 *
 * There is exactly one piece of counterplay and everybody gets it, the caster included:
 * five seconds of every machine in the room buzzing at `span_userdanger`. Leave.
 *
 * Two things keep it from being unbounded rather than merely enormous. The twelve-machine
 * cap holds the tick cost and the blast pattern to something a room can contain, and the
 * 0.2s stagger means the blasts land one at a time, which also means a machine killed by
 * an earlier blast simply no-ops when its own timer comes up, so the cascade eats itself
 * from the middle outwards instead of double-counting.
 */
/datum/machine_masshack/overload
	name = "Overload the Room"
	desc = "Feed every machine around you power at once, each one at full overload strength. Five seconds of the whole \
		room buzzing, then up to twelve real explosions land a fifth of a second apart. It takes the walls with it and \
		it will breach a hull if one is in the pattern. Lights just burst. Nothing that goes up comes back, and you are \
		standing in the middle of it, leave."
	radial_icon_state = "overload_machine"
	cooldown = 3 MINUTES

/datum/machine_masshack/overload/available(mob/living/user, turf/center)
	return length(communion_mass_machines(center, skip_lights = TRUE)) > 0

/datum/machine_masshack/overload/execute(mob/living/user, turf/center)
	var/list/targets = communion_mass_machines(center, skip_lights = TRUE)
	if(!length(targets))
		return FALSE
	user.playsound_local(user, 'sound/misc/interference.ogg', 60, FALSE)
	playsound(center, SFX_SPARKS, 70, TRUE)
	for(var/index in 1 to length(targets))
		var/obj/machinery/victim = targets[index]
		victim.audible_message(span_userdanger("[victim] starts buzzing, loudly."))
		var/datum/callback/burst = CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(communion_burst_machine), victim, COMMUNION_MASS_OVERLOAD_HEAVY, COMMUNION_MASS_OVERLOAD_LIGHT, COMMUNION_MASS_OVERLOAD_FLASH)
		addtimer(burst, COMMUNION_MASS_OVERLOAD_DELAY + ((index - 1) * COMMUNION_MASS_OVERLOAD_STAGGER))
	// Lights are outside the cap and go on the same clock, so the room goes dark as it goes up.
	for(var/obj/machinery/light/bulb in view(COMMUNION_MASS_RANGE, center))
		addtimer(CALLBACK(bulb, TYPE_PROC_REF(/obj/machinery/light, break_light_tube)), COMMUNION_MASS_OVERLOAD_DELAY)
	to_chat(user, span_userdanger("Every machine in the room takes the charge. [length(targets)] of them. Get out."))
	return TRUE

// ===== ARC FLASH =====

/**
 * Every powered thing in the room earths itself through whoever is standing nearest to it,
 * five times over seven and a half seconds.
 *
 * Deliberately not `tesla_zap`: that proc is a chain, it damages every machine and
 * structure it hops through, it electrolyses the air on each landing, and it recurses
 * unboundedly out of the room. What is wanted here is one arc per person per volley from
 * whatever machine happens to be nearest them, so it is written out longhand.
 *
 * Iterating victims rather than sources is what bounds the damage: it does not matter
 * whether somebody is standing in front of one machine or ten, they take one arc per
 * volley. Move out of the room and the volleys stop finding you.
 */
/datum/machine_masshack/arc_flash
	name = "Arc Flash"
	desc = "Every powered machine around you starts earthing itself through whoever is standing nearest to it. Five \
		volleys a second and a half apart, 14 burn each, and it comes out of the wall rather than through their hands, \
		so insulated gloves do nothing. It hits everyone in the room except you, friend or not."
	radial_icon = 'icons/mob/actions/actions_spells.dmi'
	radial_icon_state = "lightning"
	cooldown = 2 MINUTES

/datum/machine_masshack/arc_flash/available(mob/living/user, turf/center)
	if(!length(communion_arc_sources(center)))
		return FALSE
	for(var/mob/living/candidate in view(COMMUNION_MASS_RANGE, center))
		if(candidate != user && candidate.stat != DEAD)
			return TRUE
	return FALSE

/datum/machine_masshack/arc_flash/execute(mob/living/user, turf/center)
	var/list/sources = communion_arc_sources(center)
	if(!length(sources))
		return FALSE
	// The charged room moves with its ship, and unloading it must end the remaining arcs.
	var/obj/effect/vestige_trial_marker/room = new(center)
	QDEL_IN(room, COMMUNION_ARC_PULSES * COMMUNION_ARC_INTERVAL)
	to_chat(user, span_boldwarning("Everything with a current in it starts looking for somewhere to put it."))
	for(var/pulse in 1 to COMMUNION_ARC_PULSES)
		addtimer(CALLBACK(src, PROC_REF(volley), WEAKREF(room), WEAKREF(user)), (pulse - 1) * COMMUNION_ARC_INTERVAL)
	return TRUE

/// One volley: everybody in the room takes an arc from the machine nearest them, if any.
/datum/machine_masshack/arc_flash/proc/volley(datum/weakref/room_ref, datum/weakref/caster_ref)
	var/turf/center = get_turf(room_ref?.resolve())
	if(QDELETED(center))
		return
	var/mob/living/caster = caster_ref?.resolve()
	// The sources are re-gathered every volley on purpose: a machine that lost power or
	// was destroyed between volleys stops throwing, and so does one that was never on.
	var/list/sources = communion_arc_sources(center)
	if(!length(sources))
		return
	var/landed = 0
	for(var/mob/living/victim in view(COMMUNION_MASS_RANGE, center))
		if(victim == caster || victim.stat == DEAD)
			continue
		var/obj/machinery/source = communion_nearest_source(victim, sources)
		if(isnull(source))
			continue
		source.Beam(victim, icon_state = "lightning[rand(1, 12)]", time = 0.4 SECONDS)
		do_sparks(2, FALSE, victim)
		// SHOCK_NOGLOVES because the current is coming out of the wall beside them rather
		// than through anything they are holding. SHOCK_NOSTUN because five volleys of
		// stock electrocution is a seven-second stunlock, and the counterplay is supposed
		// to be walking out of the room.
		victim.electrocute_act(COMMUNION_ARC_DAMAGE, source, flags = SHOCK_NOGLOVES|SHOCK_NOSTUN)
		landed++
	if(landed)
		playsound(center, 'sound/effects/magic/lightningbolt.ogg', 50, TRUE)

/// Powered machines in the room that could throw an arc.
/proc/communion_arc_sources(turf/center)
	var/list/sources = list()
	for(var/obj/machinery/machine as anything in communion_mass_machines(center, cap = COMMUNION_MASS_CAP))
		if(machine.is_operational)
			sources += machine
	return sources

/// The nearest source with line of sight to this victim, or null if none is close enough.
/proc/communion_nearest_source(mob/living/victim, list/sources)
	var/obj/machinery/closest
	var/closest_distance = COMMUNION_ARC_REACH + 1
	for(var/obj/machinery/candidate as anything in sources)
		if(QDELETED(candidate))
			continue
		var/distance = get_dist(candidate, victim)
		if(distance >= closest_distance)
			continue
		if(!can_see(candidate, victim, COMMUNION_ARC_REACH))
			continue
		closest = candidate
		closest_distance = distance
	return closest

// ===== WAKE THE MACHINES =====

/**
 * The room stands up and takes your side.
 *
 * `/mob/living/basic/mimic/copy/machine` is the same mob the malf AI's Override Machine
 * animates (malf_ai_modules.dm:485), so the animation, the visuals, the stat block and the
 * melee are all upstream's. Three things are ours:
 *
 * - The AI controller uses `/datum/targeting_strategy/basic/not_friends`. The stock mimic
 *   uses plain `/basic`, which reads factions only, and `befriend` writes the owner's
 *   REF into the MIMIC'S faction list, not the owner's, so a plain faction check does not
 *   match and the machine happily attacks the person who woke it. `not_friends` is the
 *   strategy that reads `BB_FRIENDS_LIST`, which is the half of `befriend` that knows who
 *   woke this thing up.
 *
 *   The catch, and it bit: `not_friends` also overrides `faction_check` to return FALSE
 *   unconditionally, "friends dont care about factions". Factions stop being a reason to
 *   spare anyone at all, so two woken machines sharing FACTION_MIMIC will happily beat each
 *   other to death. The friends list is the ONLY authority under this strategy, which is why
 *   [/datum/machine_masshack/wake] introduces every machine in a batch to every other one
 *   after they are all built. Anything added here that should not be attacked has to go on
 *   that list; adding a faction will not do it.
 * - A clock. Woken machines fall apart after two minutes rather than wandering the ship
 *   until the stock idle decay finishes them.
 * - Twice the health and twice the melee, because eight of these have to be worth three
 *   minutes on the same button as Overload the Room.
 *
 * The machine is consumed, `destroy_original` is TRUE, same as the malf module, because
 * the alternative (storing it inside the mob and dropping it on death, which is what
 * animated structures do) means forceMoving live machinery into a mob's contents and all
 * the power and pipe bookkeeping that implies. It is a real cost and the desc says so.
 */
/datum/machine_masshack/wake
	name = "Wake the Machines"
	desc = "Stand every free-standing machine in the room up to fight for you. Up to eight of them, twice as tough as an \
		animated machine and hitting twice as hard, for two minutes before they fall apart. They know you and nobody \
		else, everyone else in the room is a stranger to them. The machines do not come back."
	radial_icon_state = "override_machine"
	cooldown = 3 MINUTES

/datum/machine_masshack/wake/available(mob/living/user, turf/center)
	return length(communion_mass_machines(center, cap = COMMUNION_WAKE_CAP, standing_only = TRUE)) > 0

/datum/machine_masshack/wake/execute(mob/living/user, turf/center)
	var/list/targets = communion_mass_machines(center, cap = COMMUNION_WAKE_CAP, standing_only = TRUE)
	if(!length(targets))
		return FALSE
	user.playsound_local(user, 'sound/misc/interference.ogg', 60, FALSE)
	var/list/woken = list()
	for(var/obj/machinery/sleeper as anything in targets)
		sleeper.audible_message(span_userdanger("[sleeper] shudders, and stands up."))
		var/mob/living/basic/mimic/copy/machine/communion/risen = new(get_turf(sleeper), sleeper, user, TRUE)
		if(!QDELETED(risen))
			woken += risen
	if(!length(woken))
		return FALSE
	// Introduce the batch to each other, or they fight each other instead of anyone else.
	// Sharing FACTION_MIMIC does NOT cover this: not_friends overrides `faction_check` to
	// return FALSE unconditionally, so factions stop being a reason to spare anybody and the
	// friends list becomes the only one. See [/mob/living/basic/mimic/copy/machine/communion].
	for(var/mob/living/first as anything in woken)
		for(var/mob/living/second as anything in woken)
			if(first != second)
				first.befriend(second)
	to_chat(user, span_boldnotice("[length(woken)] of them get up. They know your face and each other's, and nobody else's."))
	return TRUE

/**
 * A machine woken by the capstone. See [/datum/machine_masshack/wake] for why each
 * difference from the stock animated machine is there.
 */
/mob/living/basic/mimic/copy/machine/communion
	ai_controller = /datum/ai_controller/basic_controller/mimic_copy/machine/communion

/datum/ai_controller/basic_controller/mimic_copy/machine/communion
	// not_friends is the whole point. See the file comment. It reads BB_FRIENDS_LIST,
	// which is the half of befriend() that actually knows who woke this thing up.
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic/not_friends,
	)
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/attack_obstacle_in_path,
		/datum/ai_planning_subtree/random_speech/when_has_target/communion_machine,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)

/datum/ai_planning_subtree/random_speech/when_has_target/communion_machine
	speech_chance = 6
	emote_hear = list()
	speak = list(
		"Clear the room.",
		"You are not on the list.",
		"Stand still.",
		"Instruction received.",
		"This is being logged.",
		"Stop moving.",
	)

// The stat block is set by CopyObject inside the parent's Initialize, so the scaling has
// to come after it. no_googlies defaults on because the stock mimic's googly eyes are the
// joke read of this mob and the wrong one here; the outline does the same job of telling
// the room which vending machine is somebody's.
/mob/living/basic/mimic/copy/machine/communion/Initialize(mapload, obj/copy, mob/living/creator, destroy_original = TRUE, no_googlies = TRUE)
	. = ..()
	maxHealth = round(maxHealth * COMMUNION_WAKE_SCALE)
	health = maxHealth
	melee_damage_lower = round(melee_damage_lower * COMMUNION_WAKE_SCALE)
	melee_damage_upper = round(melee_damage_upper * COMMUNION_WAKE_SCALE)
	// The stock decay exists so an animated object with nothing to kill eventually stops.
	// This one has a hard clock instead, so it does not quietly die mid-fight for standing
	// still, and does not outlive its two minutes for having something to chase.
	idledamage = FALSE
	add_filter(COMMUNION_WAKE_FILTER, 2, list("type" = "outline", "color" = COMMUNION_WAKE_COLOR, "size" = 1))
	addtimer(CALLBACK(src, PROC_REF(fall_apart)), COMMUNION_WAKE_DURATION)

/mob/living/basic/mimic/copy/machine/communion/proc/fall_apart()
	if(QDELETED(src) || stat == DEAD)
		return
	visible_message(span_warning("[src] stops dead, and falls over."))
	playsound(src, SFX_SPARKS, 50, TRUE)
	death()

#undef COMMUNION_MASS_RANGE
#undef COMMUNION_MASS_CAP
#undef COMMUNION_MASS_OVERLOAD_DELAY
#undef COMMUNION_MASS_OVERLOAD_STAGGER
#undef COMMUNION_MASS_OVERLOAD_HEAVY
#undef COMMUNION_MASS_OVERLOAD_LIGHT
#undef COMMUNION_MASS_OVERLOAD_FLASH
#undef COMMUNION_ARC_PULSES
#undef COMMUNION_ARC_INTERVAL
#undef COMMUNION_ARC_REACH
#undef COMMUNION_ARC_DAMAGE
#undef COMMUNION_WAKE_CAP
#undef COMMUNION_WAKE_DURATION
#undef COMMUNION_WAKE_SCALE
#undef COMMUNION_WAKE_FILTER
#undef COMMUNION_WAKE_COLOR

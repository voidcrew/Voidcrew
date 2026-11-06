/// Backgrounds: owned by P6. See data/backgrounds/spec.md.

/// How close a homesteader comes before the family greets them
#define HOMESTEAD_GREET_RANGE 7
/// How long before the same homesteader is greeted again
#define HOMESTEAD_GREET_COOLDOWN (10 MINUTES)

/// Every living member of the homestead family
/proc/homestead_family()
	return GLOB.homestead ? GLOB.homestead.living_members() : list()

// =========================================================================
// THE FAMILY ON THE HOMESTEAD
// =========================================================================

/// Every family member made this round who still exists, dead or alive
/datum/homestead/proc/all_members()
	. = list()
	for(var/datum/weakref/member_ref as anything in members)
		var/mob/living/basic/ambient_npc/homestead/member = member_ref.resolve()
		if(!QDELETED(member))
			. += member

/// The family members who are alive
/datum/homestead/proc/living_members()
	. = list()
	for(var/mob/living/basic/ambient_npc/homestead/member as anything in all_members())
		if(member.stat != DEAD)
			. += member

/// Takes `member` in as one of the family
/datum/homestead/proc/add_member(mob/living/basic/ambient_npc/homestead/member)
	member.homestead = src
	for(var/datum/weakref/member_ref as anything in members)
		if(member_ref.resolve() == member)
			return
	members += WEAKREF(member)
	if(length(bounds) >= 5)
		var/leash = BACKGROUND_HOMESTEAD_LEASH
		member.leash_bounds = list(bounds[1] - leash, bounds[2] - leash, bounds[3] + leash, bounds[4] + leash, bounds[5])

/// A spouse or child landmark on the stamped homestead finished loading: the family member is made there
/datum/homestead/proc/landmark_ready(obj/effect/landmark/homestead/landmark)
	if(istype(landmark, /obj/effect/landmark/homestead/spouse))
		spawn_member(/mob/living/basic/ambient_npc/homestead/spouse, landmark)
	else if(istype(landmark, /obj/effect/landmark/homestead/child))
		spawn_member(/mob/living/basic/ambient_npc/homestead/child, landmark)

/// Makes one family member at `landmark`, once per landmark. Returns the member, or null.
/datum/homestead/proc/spawn_member(member_type, obj/effect/landmark/homestead/landmark)
	if(QDELETED(landmark) || !isturf(landmark.loc))
		return null
	for(var/datum/weakref/used_ref as anything in used_landmarks)
		if(used_ref.resolve() == landmark)
			return null
	used_landmarks += WEAKREF(landmark)
	var/mob/living/basic/ambient_npc/homestead/member = new member_type(landmark.loc, src)
	return member

/// Makes anyone a landmark should have made and did not (a landmark whose late load was missed)
/datum/homestead/proc/ensure_family()
	if(length(bounds) < 5)
		return
	for(var/obj/effect/landmark/homestead/landmark in GLOB.landmarks_list)
		if(contains(landmark))
			landmark_ready(landmark)

/**
 * The family on the tick: anyone off the Frontier, or somewhere they cannot walk back from, is put
 * home (MOV-1); anyone off the leash walks home; and a homesteader coming home is greeted.
 */
/datum/homestead/proc/tend_family()
	var/list/living = living_members()
	for(var/mob/living/basic/ambient_npc/homestead/member as anything in living)
		var/turf/here = get_turf(member)
		if(!here || !isturf(member.loc) || !on_frontier(here) || here.z != member.home?.z)
			member.return_home()
			continue
		if(!member.leash_ok(here) && member.can_act() && !istype(member.activity, /datum/ambient_activity/go_home))
			member.start_activity(new /datum/ambient_activity/go_home(member))
	greet_homesteaders(living)

/// Greets each homesteader who comes back within HOMESTEAD_GREET_RANGE of the family, once per HOMESTEAD_GREET_COOLDOWN
/datum/homestead/proc/greet_homesteaders(list/living)
	for(var/datum/mind/mind as anything in background_active_minds(BACKGROUND_HOMESTEADER))
		var/mob/living/settler = mind.current
		var/key = homestead_settler_key(mind)
		var/turf/settler_turf = get_turf(settler)
		if(QDELETED(settler) || settler.stat != CONSCIOUS || settler_turf?.z != surface_z)
			near_family -= key
			continue
		var/mob/living/basic/ambient_npc/homestead/greeter
		var/anyone_near = FALSE
		for(var/mob/living/basic/ambient_npc/homestead/member as anything in living)
			if(get_dist(member, settler) > HOMESTEAD_GREET_RANGE)
				continue
			anyone_near = TRUE
			if(!greeter && member.can_greet() && can_see(member, settler, HOMESTEAD_GREET_RANGE))
				greeter = member
		if(!anyone_near)
			near_family -= key
			continue
		if(near_family[key])
			continue
		near_family[key] = TRUE
		if(!greeter || greeted[key] + HOMESTEAD_GREET_COOLDOWN > world.time)
			continue
		greeted[key] = world.time
		greeter.greet(settler)

/// A player killed one of the family: logged, and admins told once per killer (MP-11)
/datum/homestead/proc/member_killed(mob/living/basic/ambient_npc/homestead/member, mob/living/killer)
	var/killer_ckey = killer?.ckey
	record_metric(METRIC_BACKGROUND, "family_death", other_ckey = killer_ckey, subject = "[member.type]", location = member)
	if(!killer_ckey)
		return
	log_combat(killer, member, "killed", null, "(homestead family)")
	if(alerted_killers[killer_ckey])
		return
	alerted_killers[killer_ckey] = TRUE
	message_admins("[ADMIN_LOOKUPFLW(killer)] killed [member.real_name], one of the homestead family, at [ADMIN_VERBOSEJMP(member)].")
	log_game("[key_name(killer)] killed [member.real_name], one of the homestead family, at [AREACOORD(member)].")

// =========================================================================
// THE DOORS
// =========================================================================

/// Watches one of the homestead's airlocks: no animal but the family opens it, and a cellar door is barred while the family hides
/datum/homestead/proc/watch_door(obj/machinery/door/door, cellar = FALSE)
	RegisterSignal(door, COMSIG_OBJ_ALLOWED, PROC_REF(door_allowed), override = TRUE)
	if(cellar)
		cellar_doors[REF(door)] = TRUE

/// Whether the cellar is barred: while anything hostile is near the house, and until it has been quiet a while
/datum/homestead/proc/cellar_barred()
	return !safe || world.time < safe_since + 30 SECONDS

/// Whether `person` is one of the homesteaders
/proc/is_homesteader(mob/person)
	var/datum/background_state/state = person?.mind?.background_state
	return state && !state.ended && state.key == BACKGROUND_HOMESTEADER

/**
 * Who opens a homestead door. The family, always. Into a barred cellar, the family and the
 * homesteaders only. Otherwise anyone with hands: players, and bandits, who work a door fine; but
 * no livestock, dog or wild animal without a player in it.
 */
/datum/homestead/proc/door_allowed(obj/machinery/door/source, mob/accessor)
	SIGNAL_HANDLER
	if(!ismob(accessor) || istype(accessor, /mob/living/basic/ambient_npc/homestead))
		return NONE
	if(cellar_doors[REF(source)] && cellar_barred())
		return is_homesteader(accessor) ? NONE : COMPONENT_OBJ_DISALLOW
	if(accessor.client || istype(accessor, /mob/living/simple_animal/hostile/asteroid/hermit))
		return NONE
	if(!isanimal_or_basicmob(accessor))
		return NONE
	// A ridden horse goes where its rider opens the door
	for(var/mob/rider as anything in accessor.buckled_mobs)
		if(rider.client)
			return NONE
	return COMPONENT_OBJ_DISALLOW

// =========================================================================
// THE FAMILY
// =========================================================================

/**
 * One of the homestead's family. Made at a landmark by code, never mapped. Never despawned
 * (TRAIT_HOMESTEAD_RESIDENT), never allied with the planet's wildlife, never teleported (the base
 * NPC refuses every teleport it is put through, TEL-1), kept home by a leash (MOV-1). A death is
 * for the round; a revived member simply carries on (TAK-2).
 */
/mob/living/basic/ambient_npc/homestead
	name = "settler"
	desc = "Lives and works on the homestead."
	dialogue_file = "homestead_family.json"
	random_name = FALSE
	death_cash_low = 0
	death_cash_high = 0
	speech_pace = 1.5
	/// The homestead they belong to
	var/datum/homestead/homestead
	/// The day number they last had supper
	var/supper_day = -1
	/// The player who last hurt them, and when
	var/datum/weakref/last_attacker_ref
	var/last_attacked_at = 0
	/// Weakref to the bed they sleep in
	var/datum/weakref/bed_ref
	/// Works the field when it needs it
	var/field_worker = FALSE

/mob/living/basic/ambient_npc/homestead/Initialize(mapload, datum/homestead/new_homestead)
	pick_family_name(new_homestead || GLOB.homestead)
	. = ..(mapload)
	ADD_TRAIT(src, TRAIT_HOMESTEAD_RESIDENT, BACKGROUND_TRAIT)
	transform = standing_transform()
	// Family of the homestead that made them, or of the one they were put down on
	var/datum/homestead/home_place = new_homestead
	if(!home_place && GLOB.homestead?.contains(src))
		home_place = GLOB.homestead
	home_place?.add_member(src)

/mob/living/basic/ambient_npc/homestead/Destroy()
	homestead = null
	last_attacker_ref = null
	bed_ref = null
	return ..()

/// A first name for their gender and the family's surname
/mob/living/basic/ambient_npc/homestead/proc/pick_family_name(datum/homestead/family)
	if(random_gender)
		gender = pick(MALE, FEMALE)
		random_gender = FALSE
	var/first = pick(gender == FEMALE ? GLOB.first_names_female : GLOB.first_names_male)
	var/last = family?.surname || pick(GLOB.last_names)
	name = "[first] [last]"
	real_name = name

/mob/living/basic/ambient_npc/homestead/should_inherit_planetary_faction()
	return FALSE

/// The transform they stand with
/mob/living/basic/ambient_npc/homestead/proc/standing_transform()
	return matrix()

/// The transform they lie with, in bed or dead
/mob/living/basic/ambient_npc/homestead/proc/lying_transform()
	return matrix().Turn(90)

// Looks reset the transform; ours put it back
/mob/living/basic/ambient_npc/homestead/look_dead()
	. = ..()
	transform = lying_transform()

/mob/living/basic/ambient_npc/homestead/look_alive()
	. = ..()
	transform = standing_transform()

/// Whether they would stop and greet someone now: awake, not hiding, not in bed, not already busy with something urgent
/mob/living/basic/ambient_npc/homestead/proc/can_greet()
	if(!can_act() || buckled)
		return FALSE
	return !(activity?.priority >= AMBIENT_PRIORITY_REACTION)

/// Greets `settler` by name, with a line for `context` ("greet" coming home, "welcome" on arrival)
/mob/living/basic/ambient_npc/homestead/proc/greet(mob/living/settler, context = "greet")
	if(!can_greet())
		return
	var/datum/ambient_activity/homestead_greet/greeting = new(src, settler)
	greeting.context = context
	start_activity(greeting)

/// Hostiles near the house: they head for the cellar
/mob/living/basic/ambient_npc/homestead/proc/take_shelter()
	if(!can_act() || istype(activity, /datum/ambient_activity/homestead_hide))
		return
	start_activity(new /datum/ambient_activity/homestead_hide(src))

/// Put back at the house: carried off the Frontier, or somewhere they cannot walk back from
/mob/living/basic/ambient_npc/homestead/proc/return_home()
	var/turf/target = home
	if(!target || target == get_turf(src))
		return
	end_activity()
	if(stat == CONSCIOUS)
		speak_context("going_home", null, TRUE)
	if(buckled)
		buckled.unbuckle_mob(src, force = TRUE)
	forceMove(target)
	leash_broken_at = 0

// Off the leash with no way to walk back: home, never faded out
/mob/living/basic/ambient_npc/homestead/give_up_leash()
	return_home()

/mob/living/basic/ambient_npc/homestead/on_attacked(datum/source, atom/attacker, attack_flags)
	if(ismob(attacker) && (attack_flags & (ATTACKER_DAMAGING_ATTACK | ATTACKER_STAMINA_ATTACK)))
		var/mob/living/hitter = attacker
		if(hitter.ckey)
			last_attacker_ref = WEAKREF(hitter)
			last_attacked_at = world.time
			log_combat(hitter, src, "attacked", null, "(homestead family)")
	return ..()

/mob/living/basic/ambient_npc/homestead/react_attacked(atom/attacker)
	. = ..()
	// Hurt at home: they get inside
	if(stat == CONSCIOUS && homestead?.contains(src))
		take_shelter()

/mob/living/basic/ambient_npc/homestead/death(gibbed)
	var/was_alive = stat != DEAD
	. = ..()
	if(!was_alive || !homestead)
		return
	var/mob/living/killer = (world.time - last_attacked_at < 30 SECONDS) ? last_attacker_ref?.resolve() : null
	homestead.member_killed(src, killer)

// =========================================================================
// THE SPOUSE
// =========================================================================

/mob/living/basic/ambient_npc/homestead/spouse
	desc = "Lives and works on the homestead. Usually by the stove."
	dialogue_section = "spouse"
	field_worker = TRUE
	outfit_choices = list(
		/datum/outfit/job/botanist,
		/datum/outfit/job/cook,
	)
	routine = list(
		/datum/ambient_activity/homestead_cook = 5,
		/datum/ambient_activity/homestead_tend = 3,
		/datum/ambient_activity/homestead_feed = 2,
		/datum/ambient_activity/sit = 1,
		/datum/ambient_activity/chat = 1,
		/datum/ambient_activity/idle = 1,
	)

// =========================================================================
// THE CHILDREN
// =========================================================================

/// Overalls and boots for the yard
/datum/outfit/homestead_child
	name = "Homestead child"
	uniform = /obj/item/clothing/under/misc/overalls
	shoes = /obj/item/clothing/shoes/sneakers/brown

/// The same, under a hat a size too big
/datum/outfit/homestead_child/hat
	name = "Homestead child (hat)"
	head = /obj/item/clothing/head/cowboy/brown

/mob/living/basic/ambient_npc/homestead/child
	desc = "A homestead kid. Dirt on both knees."
	dialogue_section = "child"
	outfit_choices = list(
		/datum/outfit/homestead_child,
		/datum/outfit/homestead_child/hat,
	)
	maxHealth = 50
	health = 50
	// Quicker than the grown-ups
	speed = 1.5
	speech_pace = 1.2
	routine = list(
		/datum/ambient_activity/homestead_tag = 4,
		/datum/ambient_activity/homestead_pet_dog = 2,
		/datum/ambient_activity/homestead_eggs = 3,
		/datum/ambient_activity/wander = 2,
		/datum/ambient_activity/chat = 1,
		/datum/ambient_activity/sit = 1,
	)

// Three quarters of a grown-up, feet still on the floor
/mob/living/basic/ambient_npc/homestead/child/standing_transform()
	var/matrix/shape = matrix()
	shape.Scale(0.75)
	shape.Translate(0, -4)
	return shape

/mob/living/basic/ambient_npc/homestead/child/lying_transform()
	var/matrix/shape = matrix()
	shape.Scale(0.75)
	shape.Turn(90)
	return shape

#undef HOMESTEAD_GREET_RANGE
#undef HOMESTEAD_GREET_COOLDOWN

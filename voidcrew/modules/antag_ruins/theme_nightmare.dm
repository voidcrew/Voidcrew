/**
 * # The Gloaming: nightmare vestige
 *
 * A freighter that went dark mid-burn, in every sense. The map itself is the
 * hazard: bring a light, and know the patron wants it gone. Every trial is a
 * lesson in the dark: unravel a lamp circuit, haunt its watchman, or carry
 * a fragile night through searching beams. The boons
 * are the nightmare's own: the shadow it walks, the terror it projects, the
 * lights it puts out, and the wounds the dark closes when no one is looking.
 *
 * Two upgrade chains (the shadow-walk and the terror) plus two standalones
 * (the snuff and the dark-heal), all human-castable ports, the nightmare's
 * body IS the antag, so nothing here needs a shadow species or a heart of
 * darkness to work.
 */

// Tuning constants for the Stranger's ports (file-local, #undef at bottom)
/// Brute+burn per SSobj tick the Umbral Passage's deeper dark knits (base jaunt is 1.5)
#define VESTIGE_UMBRAL_HEAL_RATE 3
/// How far Creeping Dread bleeds terror into the dark around its target
#define VESTIGE_DREAD_RADIUS 4
/// Radius of lights Snuff reaches out and puts out
#define VESTIGE_SNUFF_RADIUS 4
/// Brute+burn a single Heart of Darkness closes, castable only in the dark
#define VESTIGE_DARKHEAL_AMOUNT 25

// ===== PATRON =====

/mob/living/basic/vestige_patron/stranger
	name = "the Stranger"
	desc = "A silhouette with its proportions slightly off, pinned under a dead floodlight like a moth. It is only visible because it is darker than the dark behind it."
	gender = NEUTER
	outfit_path = /datum/outfit/job/assistant
	appearance_tint = "#151515"
	trial_types = list(
		/datum/vestige_trial/snuffed_flame,
		/datum/vestige_trial/the_watched,
		/datum/vestige_trial/long_night,
	)
	boon_types = list(
		/datum/vestige_boon/spell/shadow_walk,
		/datum/vestige_boon/spell/shadow_walk/umbral,
		/datum/vestige_boon/spell/terrorize,
		/datum/vestige_boon/spell/terrorize/creeping_dread,
		/datum/vestige_boon/spell/snuff,
		/datum/vestige_boon/spell/heart_of_darkness,
	)
	idle_lines = list(
		"You brought a light. They always bring a light. Put it out and we can talk properly.",
		"There were four hundred lights on this ship. I remember every one of them going out.",
		"The dark isn't empty. The dark is full. It's the light that's empty.",
		"I'm not trapped under this lamp. The lamp is trapped over me.",
		"Fear is just the dark, felt from the inside. I can teach you to be the room instead of the person standing in it.",
		"Sit a while. Don't fill the silence. That's where I keep everything worth having.",
	)
	accept_line = "Good. Go into the dark, and do the work the dark asks of you."
	busy_line = "One debt. Then another. Not both at once."
	fulfilled_line = "You've already learned that one. The dark doesn't repeat itself."
	renounce_line = "Then keep squinting."
	claim_line = "You're owed. I always pay. Take it."
	exhausted_line = "You've got everything I kept. The rest went out with the lights."
	remember_line = "You went dark. Everything does. What you earned was waiting where you left it."

// ===== TRIAL OF THE SNUFFED FLAME =====

/datum/vestige_trial/snuffed_flame
	parent_type = /datum/vestige_trial/field_encounter
	name = "Trial of the Snuffed Flame"
	desc = "Deploy the censer's nine linked lamps on a clear five-by-five patch of ground. Touch a lamp with the censer to reverse it and its orthogonal neighbors two tiles away: light becomes dark, dark rekindles. Make all nine dark together. The initial pattern is always solvable; inspect the connections and plan which lights must return before they can all go out. Ordinary room lights are outside this circuit."
	var/obj/item/vestige_censer/censer

/datum/vestige_trial/snuffed_flame/on_accepted(mob/living/user)
	..()
	censer = hand_over(user, new /obj/item/vestige_censer(get_turf(user)))

/datum/vestige_trial/snuffed_flame/Destroy()
	QDEL_NULL(censer)
	return ..()

/datum/vestige_trial/snuffed_flame/setup_field(turf/center, mob/living/user)
	for(var/offset_x in list(-2, 0, 2))
		for(var/offset_y in list(-2, 0, 2))
			add_node(locate(center.x + offset_x, center.y + offset_y, center.z), "linked darklight lamp")
	// Scrambling the solved state by legal moves guarantees a solution.
	var/list/scramble = shuffle(field_nodes.Copy())
	for(var/index in 1 to 5)
		reverse_lamps(scramble[index])
	if(!burning_lamps())
		reverse_lamps(field_nodes[1])

/datum/vestige_trial/snuffed_flame/proc/burning_lamps()
	var/burning = 0
	for(var/obj/structure/vestige_field_node/node as anything in field_nodes)
		burning += node.lit
	return burning

/datum/vestige_trial/snuffed_flame/get_progress_text()
	return "Linked lamps still burning: [burning_lamps()]/9. The censer reverses a lamp and its orthogonal neighbors."

/datum/vestige_trial/snuffed_flame/proc/reverse_lamps(obj/structure/vestige_field_node/pressed)
	for(var/obj/structure/vestige_field_node/node as anything in field_nodes)
		if(node == pressed || (get_dist(node, pressed) == 2 && (node.x == pressed.x || node.y == pressed.y)))
			node.light_state(!node.lit)
	refresh_tracker()

/obj/item/vestige_censer
	name = "darklight censer"
	desc = "A lantern that burns backwards. It reverses your trial's linked lamps and has no appetite beyond that loaned circuit."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "syndilantern"
	color = "#6a6a8a"
	w_class = WEIGHT_CLASS_SMALL

/obj/item/vestige_censer/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/datum/vestige_trial/snuffed_flame/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || trial.censer != src || !(interacting_with in trial.field_nodes) || !user.Adjacent(interacting_with))
		return NONE
	trial.reverse_lamps(interacting_with)
	playsound(src, 'sound/effects/magic/blind.ogg', 30, TRUE)
	if(!trial.burning_lamps())
		trial.complete()
	return ITEM_INTERACT_SUCCESS

// ===== TRIAL OF THE WATCHED =====

/datum/vestige_trial/the_watched
	parent_type = /datum/vestige_trial/field_encounter
	name = "Trial of the Watched"
	desc = "Deploy the watchman's five-by-five lamp circuit. Snuff a corner lamp with the eye to draw the watchman over to relight it. While it works, hold the eye on its back from two to four tiles away. Haunt it at two different corners, escape its search each time, then return the eye to the central focus. Its projected forward beam, not the room's normal lighting, reveals you. One second in that beam erases your progress."
	var/obj/item/vestige_regard/eye
	var/list/haunted_corners = list()
	var/obj/structure/vestige_field_node/repair_target
	var/repair_until = 0
	var/search_until = 0
	var/obj/effect/vestige_trial_marker/search_spot

/datum/vestige_trial/the_watched/on_accepted(mob/living/user)
	..()
	eye = hand_over(user, new /obj/item/vestige_regard(get_turf(user)))

/datum/vestige_trial/the_watched/Destroy()
	QDEL_NULL(eye)
	return ..()

/datum/vestige_trial/the_watched/clear_field()
	QDEL_NULL(search_spot)
	return ..()

/datum/vestige_trial/the_watched/setup_field(turf/center, mob/living/user)
	haunted_corners.Cut()
	repair_target = null
	repair_until = 0
	search_until = 0
	actor = add_node(center, "searching watchman")
	actor.show_facing = TRUE
	actor.icon = 'icons/mob/silicon/aibots.dmi'
	actor.icon_state = "cleanbot0"
	actor.setDir(SOUTH)
	for(var/index in 1 to 4)
		var/obj/structure/vestige_field_node/lamp = add_node(corner_turf(index), "watchman's lamp [index]", index)
		lamp.light_state(TRUE)
	add_node(center, "haunting's end", 5)

/datum/vestige_trial/the_watched/get_progress_text()
	return "Corners haunted: [length(haunted_corners)]/2. [world.time < search_until ? "The watchman searches where you stood: withdraw!" : "Snuff a lamp, then haunt its repairer from behind."]"

/datum/vestige_trial/the_watched/field_tick(mob/living/user, seconds_per_tick)
	if(in_sight(user))
		if(!suspicion)
			actor.balloon_alert(user, "beam found you! move!")
			actor.color = "#ff3333"
		suspicion += seconds_per_tick
		if(suspicion >= 1)
			haunted_corners.Cut()
			suspicion = 0
			QDEL_NULL(search_spot)
			search_spot = mark_turf(get_turf(user))
			search_until = world.time + 5 SECONDS
			refresh_tracker()
	else
		suspicion = 0
		actor.color = "#ad8de0"
	if(world.time < next_step)
		return
	next_step = world.time + 1 SECONDS
	if(world.time < search_until)
		var/turf/searched = get_turf(search_spot)
		if(searched && get_turf(actor) != searched)
			step_towards(actor, searched)
		else
			actor.setDir(turn(actor.dir, 90))
		return
	if(QDELETED(repair_target) || repair_target.lit)
		repair_target = null
		for(var/obj/structure/vestige_field_node/lamp as anything in field_nodes)
			if((lamp.field_tag in 1 to 4) && !lamp.lit)
				if(!repair_target || get_dist(actor, lamp) < get_dist(actor, repair_target))
					repair_target = lamp
		repair_until = 0
	if(!repair_target)
		// No extinguished lamp: visibly scan; do not assume generic NPC searching.
		actor.setDir(turn(actor.dir, 90))
		return
	if(get_turf(actor) != get_turf(repair_target))
		step_towards(actor, repair_target)
		return
	if(!repair_until)
		repair_until = world.time + 5 SECONDS
		actor.balloon_alert(user, "relighting this lamp...")
	else if(world.time >= repair_until)
		repair_target.light_state(TRUE)
		repair_target = null
		repair_until = 0

/datum/vestige_trial/the_watched/proc/can_haunt(mob/living/user)
	return repair_target && repair_until > world.time && !(repair_target.field_tag in haunted_corners) && get_dist(actor, user) >= 2 && get_dist(actor, user) <= 4 && !in_sight(user) && can_see(actor, user, 4) && world.time >= search_until

/obj/item/vestige_regard
	name = "the Stranger's regard"
	desc = "An eye for the loaned watchman: snuff its lamps, haunt it from behind during repairs, and evade its searching beam."
	icon = 'icons/obj/medical/organs/organs.dmi'
	icon_state = "eyes"
	w_class = WEIGHT_CLASS_TINY

/obj/item/vestige_regard/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/datum/vestige_trial/the_watched/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || trial.eye != src || !(interacting_with in trial.field_nodes))
		return NONE
	var/obj/structure/vestige_field_node/node = interacting_with
	if(node.field_tag in 1 to 4)
		if(user.Adjacent(node) && node.lit)
			node.light_state(FALSE)
			return ITEM_INTERACT_SUCCESS
		return ITEM_INTERACT_BLOCKING
	if(node.field_tag == 5)
		if(user.Adjacent(node) && length(trial.haunted_corners) >= 2 && world.time >= trial.search_until && !trial.in_sight(user))
			trial.complete()
		return ITEM_INTERACT_SUCCESS
	if(node != trial.actor || !trial.can_haunt(user))
		balloon_alert(user, "haunt repairs from behind!")
		return ITEM_INTERACT_BLOCKING
	var/obj/structure/vestige_field_node/lamp = trial.repair_target
	if(!do_after(user, 1.5 SECONDS, target = node))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(trial) || user.mind?.active_vestige_trial != trial || !user.is_holding(src) || trial.repair_target != lamp || !trial.can_haunt(user))
		return ITEM_INTERACT_BLOCKING
	trial.haunted_corners += lamp.field_tag
	lamp.light_state(TRUE)
	trial.repair_target = null
	trial.repair_until = 0
	QDEL_NULL(trial.search_spot)
	trial.search_spot = trial.mark_turf(get_turf(user))
	trial.search_until = world.time + 5 SECONDS
	node.balloon_alert(user, "something behind me?!")
	trial.refresh_tracker()
	return ITEM_INTERACT_SUCCESS

/obj/item/vestige_regard/ranged_interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	return interact_with_atom(interacting_with, user, modifiers)

// ===== TRIAL OF THE LONG NIGHT =====

/datum/vestige_trial/long_night
	parent_type = /datum/vestige_trial/field_encounter
	name = "Trial of the Long Night"
	desc = "Deploy the five-by-five sweeping-light field. Stand on refuge 1 and touch it with the gloom-glass to charge it, then carry the glass in hand to refuges 3, 2 and 4 in that order. Gold tiles are the moving beams; red tiles show where they move next, two seconds ahead. Touching a beam empties the fragile charge. Refuges shelter and recharge you only when touched; leaving the field or stowing the glass empties it. If empty, return to the last refuge. The field works even in a dark room."
	var/obj/item/vestige_gloom_glass/glass
	var/route_index = 0
	var/list/refuge_route = list(1, 3, 2, 4)
	var/charge = 0
	var/beam_step = 0
	var/next_beam = 0
	var/list/refuges = list()

/datum/vestige_trial/long_night/on_accepted(mob/living/user)
	..()
	glass = hand_over(user, new /obj/item/vestige_gloom_glass(get_turf(user)))

/datum/vestige_trial/long_night/Destroy()
	QDEL_NULL(glass)
	return ..()

/datum/vestige_trial/long_night/setup_field(turf/center, mob/living/user)
	route_index = 0
	charge = 0
	beam_step = 0
	next_beam = world.time
	refuges.Cut()
	for(var/index in 1 to 4)
		var/obj/structure/vestige_field_node/refuge = add_node(corner_turf(index), "dark refuge [index]", index)
		refuges += refuge
	for(var/turf/spot in range(2, center))
		if(abs(spot.x - center.x) == 2 && abs(spot.y - center.y) == 2)
			continue
		add_node(spot, "sweeping sunbeam")

/datum/vestige_trial/long_night/get_progress_text()
	var/next_refuge = refuge_route[min(route_index + 1, 4)]
	return "Transfers: [max(0, route_index - 1)]/3. Glass: [charge ? "charged" : "empty"]. Next: refuge [next_refuge].[route_index ? " Recharge at refuge [refuge_route[route_index]] if empty." : ""]"

/datum/vestige_trial/long_night/proc/beam_hits(turf/spot, step_number)
	var/list/offset = field_offset(spot)
	if(!offset)
		return FALSE
	var/row = (step_number % 5) - 2
	var/column = 2 - ((step_number + 2) % 5)
	return offset[2] == row || offset[1] == column

/datum/vestige_trial/long_night/field_tick(mob/living/user, seconds_per_tick)
	var/turf/center = get_turf(field_center)
	if(world.time >= next_beam)
		beam_step++
		next_beam = world.time + 2 SECONDS
		for(var/obj/structure/vestige_field_node/node as anything in field_nodes)
			if(node.field_tag)
				continue
			var/is_lit = beam_hits(get_turf(node), beam_step)
			node.light_state(is_lit)
			node.color = is_lit ? "#ffe6a0" : beam_hits(get_turf(node), beam_step + 1) ? "#ff5555" : "#352849"
	if(charge <= 0)
		return
	if(!user.is_holding(glass) || get_dist(user, center) > 2)
		charge = 0
		refresh_tracker()
		return
	for(var/obj/structure/vestige_field_node/refuge as anything in refuges)
		if(get_turf(refuge) == get_turf(user))
			return
	if(!beam_hits(get_turf(user), beam_step))
		return
	charge = 0
	glass.balloon_alert(user, "empty; return to refuge!")
	refresh_tracker()

/obj/item/vestige_gloom_glass
	name = "gloom-glass"
	desc = "Carry it through your sweeping-light field in hand. Stand directly on a refuge and touch it with the glass to transfer its charge."
	icon = 'icons/obj/debris.dmi'
	icon_state = "large"
	color = "#101015"
	w_class = WEIGHT_CLASS_SMALL

/obj/item/vestige_gloom_glass/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/connect_loc, list(COMSIG_MOVABLE_MOVED = PROC_REF(on_holder_moved)))

/// A fast step through a beam must count even between field processing ticks.
/obj/item/vestige_gloom_glass/proc/on_holder_moved(atom/movable/source, atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	SIGNAL_HANDLER
	// Shuttle relocation uses abstract_move, whose no-effects movement may
	// run before the field's other turfs and origin have been relocated.
	if(!momentum_change || !isliving(source))
		return
	var/mob/living/user = source
	var/datum/vestige_trial/long_night/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || trial.glass != src)
		return
	var/turf/center = get_turf(trial.field_center)
	if(!center || trial.field_center.shuttle_moving)
		return
	if(!isturf(user.loc) || user.z != center.z)
		trial.field_abandoned()
		return
	trial.field_tick(user, 0)

/obj/item/vestige_gloom_glass/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/datum/vestige_trial/long_night/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || trial.glass != src || !(interacting_with in trial.refuges) || get_turf(user) != get_turf(interacting_with))
		return NONE
	var/obj/structure/vestige_field_node/refuge = interacting_with
	if(trial.route_index && refuge.field_tag == trial.refuge_route[trial.route_index])
		trial.charge = 1
		balloon_alert(user, "recharged")
		trial.refresh_tracker()
		return ITEM_INTERACT_SUCCESS
	if(refuge.field_tag != trial.refuge_route[min(trial.route_index + 1, 4)] || (trial.route_index && !trial.charge))
		balloon_alert(user, "wrong refuge or empty glass!")
		return ITEM_INTERACT_BLOCKING
	trial.route_index++
	trial.charge = 1
	trial.refresh_tracker()
	if(trial.route_index >= 4)
		trial.complete()
	return ITEM_INTERACT_SUCCESS

/datum/vestige_trial/long_night/field_abandoned()
	charge = 0
	refresh_tracker()

/obj/item/vestige_gloom_glass/dropped(mob/user, silent = FALSE)
	. = ..()
	var/datum/vestige_trial/long_night/trial = user.mind?.active_vestige_trial
	if(istype(trial) && trial.glass == src)
		trial.field_abandoned()

// ===== BOONS =====

// --- Chain: the shadow walk ---

// The nightmare's jaunt, granted as-is: upstream ships it with
// spell_requirements = NONE, and light already polices it.
/datum/vestige_boon/spell/shadow_walk
	name = "Shadow Walk"
	desc = "Sink into darkness and move through it unseen. You can only enter and stay where it's actually dark."
	grant_text = "The dark stops being a place and starts being a door."
	spell_type = /datum/action/cooldown/spell/jaunt/shadow_walk

/datum/vestige_boon/spell/shadow_walk/umbral
	name = "Umbral Passage"
	desc = "The shadow walk, improved. It heals you faster while you're under, works in dimmer light than before, and leaves you briefly quick enough to dodge bullets when you surface."
	grant_text = "You sink deeper into the dark than the walk ever let you before, and it doesn't push back."
	upgrades_from = /datum/vestige_boon/spell/shadow_walk
	spell_type = /datum/action/cooldown/spell/jaunt/shadow_walk/vestige_umbral

/**
 * The shadow walk mastered: a subtype of the nightmare's own jaunt (still
 * spell_requirements = NONE, still light-policed) that tolerates dimmer tiles,
 * heals faster inside the dark, and leaves a two-second echo of the nightmare's
 * bullet-dodge reflexes on whoever surfaces from it.
 */
/datum/action/cooldown/spell/jaunt/shadow_walk/vestige_umbral
	name = "Umbral Passage"
	desc = "Slip into darkness and move through it unseen, healing as you go. Works in dimmer light, and you're hard to hit for a moment after you come out."
	light_threshold = 0.35
	jaunt_type = /obj/effect/dummy/phased_mob/shadow/vestige_umbral

/// A deeper shadow: heals faster than the base jaunt and, on ejecting the
/// jaunter, leaves them with a brief flicker of the nightmare's reflexes.
/obj/effect/dummy/phased_mob/shadow/vestige_umbral
	healing_rate = VESTIGE_UMBRAL_HEAL_RATE

/obj/effect/dummy/phased_mob/shadow/vestige_umbral/eject_jaunter(forced_out = FALSE)
	var/mob/living/emerging = jaunter
	. = ..()
	if(isliving(emerging) && !QDELETED(emerging))
		emerging.apply_status_effect(/datum/status_effect/shadow/nightmare)

// --- Chain: the terror ---

// The nightmare's Terrorize, granted as-is: upstream ships it with
// spell_requirements = NONE and it only applies the (self-contained) terror
// status effect, so it works on a plain human caster untouched.
/datum/vestige_boon/spell/terrorize
	name = "Terrorize"
	desc = "Stare someone down in the dark and fill them with dread until they shake and stutter. It only works on a target standing in darkness, so put the lights out first."
	grant_text = "You catch your own reflection in a dead screen, and it holds your gaze a half-second too long."
	spell_type = /datum/action/cooldown/spell/pointed/terrorize

/datum/vestige_boon/spell/terrorize/creeping_dread
	name = "Creeping Dread"
	desc = "The same terror, except it spreads. Anyone else standing in the dark near your target catches it too."
	grant_text = "The dread you carry stops being something you aim and starts being something you spill."
	upgrades_from = /datum/vestige_boon/spell/terrorize
	spell_type = /datum/action/cooldown/spell/pointed/terrorize/vestige_dread

/**
 * Terrorize that spreads. The parent cast lays terror on the aimed target
 * (and keeps the must-be-in-the-dark targeting); this seeps the same dread
 * into every other human standing in darkness nearby, the caster excepted.
 */
/datum/action/cooldown/spell/pointed/terrorize/vestige_dread
	name = "Creeping Dread"
	desc = "Terrify someone standing in the dark, and everyone else standing in the dark around them."
	cooldown_time = 30 SECONDS

/datum/action/cooldown/spell/pointed/terrorize/vestige_dread/cast(mob/living/carbon/human/cast_on)
	. = ..()
	// range(), not view(): the whole point is bystanders standing in the dark, and
	// view() drops fully-darkened tiles (the same reason base Terrorize counts light with range())
	for(var/mob/living/carbon/human/bystander in range(VESTIGE_DREAD_RADIUS, cast_on))
		if(bystander == cast_on || bystander == owner)
			continue
		var/turf/bystander_turf = get_turf(bystander)
		if(!bystander_turf || bystander_turf.get_lumcount() > LIGHTING_TILE_IS_DARK)
			continue
		bystander.apply_status_effect(/datum/status_effect/terrified)

// --- Standalone: the snuff ---

/datum/vestige_boon/spell/snuff
	name = "Snuff"
	desc = "Put out every working light around you at once. Not shorted, not overloaded, just out. They stay out until someone fits new tubes."
	grant_text = "The nearest light dims for a moment, as if it has just remembered it is mortal."
	spell_type = /datum/action/cooldown/spell/aoe/vestige_snuff

/**
 * The Stranger's signature: silently break every working light tube in a
 * radius. No shock, no fanfare. The light is simply gone, permanently, until
 * someone fits a fresh tube. Sets the darkness the other Gloaming boons feed on.
 */
/datum/action/cooldown/spell/aoe/vestige_snuff
	name = "Snuff"
	desc = "Put out every working light around you. They stay dark until someone fits a new tube."
	button_icon = 'voidcrew/modules/antag_ruins/icons/vestige.dmi'
	button_icon_state = "snuff"
	background_icon_state = "bg_alien"
	overlay_icon_state = "bg_alien_border"
	// A tube going dead has more in common with an EMP than with a magic word
	sound = 'sound/effects/empulse.ogg'
	cooldown_time = 40 SECONDS
	spell_requirements = NONE
	aoe_radius = VESTIGE_SNUFF_RADIUS

/datum/action/cooldown/spell/aoe/vestige_snuff/get_things_to_cast_on(atom/center)
	return RANGE_TURFS(aoe_radius, center)

/datum/action/cooldown/spell/aoe/vestige_snuff/after_cast(atom/cast_on)
	. = ..()
	if(owner)
		owner.visible_message(
			span_boldwarning("The lights around [owner] go out all at once, without a sound."),
			span_notice("You put them out. All of them."),
		)

/datum/action/cooldown/spell/aoe/vestige_snuff/cast_on_thing_in_aoe(turf/victim, mob/living/caster)
	for(var/obj/machinery/light/light in victim)
		if(light.status != LIGHT_OK || !light.on)
			continue
		light.break_light_tube(skip_sound_and_sparks = TRUE)

// --- Standalone: the dark-heal ---

/datum/vestige_boon/spell/heart_of_darkness
	name = "Heart of Darkness"
	desc = "Stand somewhere dark and pull the dark into your wounds to close them. It won't work anywhere there's light."
	grant_text = "Something cold settles in behind your sternum. Now and then it offers to help."
	spell_type = /datum/action/cooldown/spell/vestige_darkheal

/**
 * A human-castable echo of the nightmare's heart: a burst of the dark
 * regeneration a shadow gets for free, but only where it's dark enough to hide
 * the working. Self-only, dark-gated, cooldown-paced.
 */
/datum/action/cooldown/spell/vestige_darkheal
	name = "Heart of Darkness"
	desc = "Heal your wounds using the surrounding dark. Only works where it's dark."
	button_icon = 'icons/mob/actions/actions_revenant.dmi'
	button_icon_state = "blight"
	background_icon_state = "bg_alien"
	overlay_icon_state = "bg_alien_border"
	sound = 'sound/effects/magic/curse.ogg'
	cooldown_time = 30 SECONDS
	spell_requirements = NONE
	/// Brute and burn a single cast closes
	var/heal_amount = VESTIGE_DARKHEAL_AMOUNT

/datum/action/cooldown/spell/vestige_darkheal/can_cast_spell(feedback = TRUE)
	. = ..()
	if(!.)
		return FALSE
	var/turf/cast_turf = get_turf(owner)
	if(!cast_turf || cast_turf.get_lumcount() > LIGHTING_TILE_IS_DARK)
		if(feedback)
			to_chat(owner, span_warning("There's too much light here. It only works in the dark."))
		return FALSE
	return TRUE

/datum/action/cooldown/spell/vestige_darkheal/cast(mob/living/cast_on)
	. = ..()
	cast_on.heal_overall_damage(brute = heal_amount, burn = heal_amount, required_bodytype = BODYTYPE_ORGANIC)
	cast_on.visible_message(
		span_warning("[cast_on]'s wounds darken, then close over with something that is not quite skin."),
		span_boldnotice("The dark pours into you and closes what was torn open."),
	)

#undef VESTIGE_UMBRAL_HEAL_RATE
#undef VESTIGE_DREAD_RADIUS
#undef VESTIGE_SNUFF_RADIUS
#undef VESTIGE_DARKHEAL_AMOUNT

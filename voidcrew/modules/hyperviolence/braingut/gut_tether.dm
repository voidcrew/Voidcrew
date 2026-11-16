// Gut tether (hyperviolence, braingut part): while spilled guts lie on the floor near their owner, a
// strand of gut joins them. Walking too far drags the guts along and hurts. A sharp item on the guts
// cuts the strand. Idea from Vanderlin's gut rope (Monkestation/Vanderlin 1fc0bf8, AGPL code); this is
// a rewrite on tg's /datum/beam, with a strand sprite drawn for this module.

/// One piece of the strand. Lies on the floor, so mobs walk over it rather than under it.
/obj/effect/ebeam/hv_gut
	name = "intestines"
	layer = BELOW_MOB_LAYER
	emissive = FALSE

/// The strand of gut between a disemboweled victim and their spilled guts. Owned by the disembowel wound.
/// Destroys itself when the victim or the guts are deleted.
/datum/hv_gut_tether
	/// Whose guts these are.
	var/mob/living/carbon/victim
	/// The spilled guts.
	var/obj/item/hv_intestines/guts
	/// The drawn strand. Purely visual; the tether still holds when it is missing.
	var/datum/beam/strand
	/// Set once the strand is cut or torn. A cut tether never reconnects.
	var/cut = FALSE
	/// World time the next tug is allowed to hurt.
	var/next_yank = 0
	/// The tiles the victim has left since the guts last lay beside them, oldest first: the way the guts
	/// are dragged in when the strand pulls tight.
	var/list/turf/trail = list()
	/// The timer of the guts' next step along the trail while they are being dragged in.
	var/drag_timer
	/// Set while the tether itself moves the guts, to tell that from anyone else moving them.
	var/dragging = FALSE

/datum/hv_gut_tether/New(mob/living/carbon/victim, obj/item/hv_intestines/guts)
	src.victim = victim
	src.guts = guts
	RegisterSignal(victim, COMSIG_MOVABLE_MOVED, PROC_REF(on_victim_moved))
	RegisterSignal(victim, COMSIG_QDELETING, PROC_REF(on_end_deleted))
	RegisterSignal(guts, COMSIG_MOVABLE_MOVED, PROC_REF(on_guts_moved))
	RegisterSignal(guts, COMSIG_QDELETING, PROC_REF(on_end_deleted))
	RegisterSignal(guts, COMSIG_ATOM_ITEM_INTERACTION, PROC_REF(on_guts_item_interaction))
	refresh()

/datum/hv_gut_tether/Destroy()
	stop_drag()
	trail = null
	drop_strand()
	if(victim)
		UnregisterSignal(victim, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
	if(guts)
		UnregisterSignal(guts, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING, COMSIG_ATOM_ITEM_INTERACTION))
	victim = null
	guts = null
	return ..()

/// Whether the guts are lying on the floor on the victim's level, so the strand is taut between them.
/datum/hv_gut_tether/proc/connected()
	return !cut && isturf(victim.loc) && isturf(guts.loc) && victim.z == guts.z

/// Brings the drawn strand in line with the state of the tether.
/datum/hv_gut_tether/proc/refresh()
	if(!connected() || get_dist(victim, guts) > HV_GUT_TETHER_SNAP_RANGE)
		drop_strand()
		return
	if(strand)
		return
	strand = victim.Beam(guts, "gut_beam", 'voidcrew/modules/hyperviolence/braingut/icons/gore_guts.dmi', INFINITY, HV_GUT_TETHER_SNAP_RANGE + 2, /obj/effect/ebeam/hv_gut, emissive = FALSE)
	RegisterSignal(strand, COMSIG_QDELETING, PROC_REF(on_strand_deleted))

/// Removes the drawn strand, if there is one.
/datum/hv_gut_tether/proc/drop_strand()
	if(!strand)
		return
	UnregisterSignal(strand, COMSIG_QDELETING)
	QDEL_NULL(strand)

/// The beam removes itself when either end is deleted or they drift too far apart.
/datum/hv_gut_tether/proc/on_strand_deleted(datum/beam/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_QDELETING)
	strand = null

/// The victim or the guts are being deleted: nothing left to tether.
/datum/hv_gut_tether/proc/on_end_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/datum/hv_gut_tether/proc/on_guts_moved(atom/movable/source, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	if(cut)
		return
	// Someone else has moved them: the way the victim went no longer leads to where they lie.
	if(!dragging)
		stop_drag()
	if(connected() && get_dist(victim, guts) > HV_GUT_TETHER_SNAP_RANGE)
		INVOKE_ASYNC(src, PROC_REF(tear), FALSE)
		return
	refresh()

/datum/hv_gut_tether/proc/on_victim_moved(atom/movable/source, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	if(cut)
		return
	if(!connected())
		// guts left behind on another level are gone for good; guts in someone's hands or a container only wait
		if(isturf(victim.loc) && isturf(guts.loc))
			cut = TRUE
		drop_strand()
		return
	var/distance = get_dist(victim, guts)
	if(distance > HV_GUT_TETHER_SNAP_RANGE)
		INVOKE_ASYNC(src, PROC_REF(tear), TRUE)
		return
	note_step(old_loc)
	if(distance > HV_GUT_TETHER_RANGE)
		// the guts follow where the victim was, so they trail a few steps behind
		var/turf/behind = isturf(old_loc) ? old_loc : victim.loc
		if(!length(trail))
			trail += behind
		drag_guts()
		INVOKE_ASYNC(src, PROC_REF(yank), behind)
	refresh()

/// Remembers the tile the victim has just left. Beside the guts again the strand is slack and there is
/// nothing to remember; a victim who doubles back takes the loop out of the way.
/datum/hv_gut_tether/proc/note_step(atom/old_loc)
	if(get_dist(victim, guts) <= 1)
		trail.Cut()
		return
	var/doubled_back = trail.Find(victim.loc)
	if(doubled_back)
		trail.Cut(doubled_back)
		return
	if(!isturf(old_loc) || old_loc == guts.loc)
		return
	trail += old_loc
	if(length(trail) > HV_GUT_TETHER_SNAP_RANGE)
		trail.Cut(1, 2)

/// The strand has pulled tight: the guts are dragged in along the way the victim went, to the tile behind
/// them. Their first step is taken at once and the rest follow a tile at a time, so they are seen sliding
/// across the floor (a move of more than one tile has no glide: the guts used to vanish from where they
/// lay and appear behind the victim).
/datum/hv_gut_tether/proc/drag_guts()
	if(drag_timer)
		return
	drag_step()

/// One tile further along the trail.
/datum/hv_gut_tether/proc/drag_step()
	drag_timer = null
	if(QDELETED(src) || cut || !connected())
		return
	// Tiles they already lie on are behind them.
	while(length(trail) && trail[1] == guts.loc)
		trail.Cut(1, 2)
	if(!length(trail))
		return
	var/turf/next = trail[1]
	if(get_dist(guts, next) > 1)
		// Not beside the start of the trail (someone moved them): straight toward it.
		next = get_step_towards(guts, next)
	else
		trail.Cut(1, 2)
	dragging = TRUE
	guts.set_glide_size(DELAY_TO_GLIDE_SIZE(HV_GUT_DRAG_STEP))
	guts.forceMove(next)
	dragging = FALSE
	if(QDELETED(src) || cut || !length(trail))
		return
	drag_timer = addtimer(CALLBACK(src, PROC_REF(drag_step)), HV_GUT_DRAG_STEP, TIMER_STOPPABLE|TIMER_DELETE_ME)

/// Stops dragging the guts in and forgets the way the victim went.
/datum/hv_gut_tether/proc/stop_drag()
	if(drag_timer)
		deltimer(drag_timer)
		drag_timer = null
	trail?.Cut()

/// A tug on the strand: it hurts, at most once per cooldown, and a standing victim is pulled off their feet.
/datum/hv_gut_tether/proc/yank(turf/behind)
	if(QDELETED(src) || cut || world.time < next_yank)
		return
	next_yank = world.time + HV_GUT_YANK_COOLDOWN
	victim.add_splatter_floor(behind, small_drip = TRUE)
	if(victim.stat == DEAD)
		return
	victim.apply_damage(HV_GUT_YANK_DAMAGE, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND, wound_clothing = FALSE)
	victim.visible_message(span_danger("[victim] drags [victim.p_their()] guts across the floor!"), span_userdanger("Your guts drag across the floor!"))
	victim.emote("scream")
	if(victim.body_position == STANDING_UP)
		victim.Knockdown(1 SECONDS)

/// The strand parts for good, from a cut or because it was stretched too far. The victim feels it.
/datum/hv_gut_tether/proc/tear(stretched)
	if(QDELETED(src) || cut)
		return
	cut = TRUE
	drop_strand()
	if(victim.stat == DEAD)
		return
	if(stretched)
		victim.visible_message(span_danger("[victim]'s guts tear loose!"), span_userdanger("Your guts tear loose!"))
	victim.apply_damage(HV_GUT_YANK_DAMAGE * 2, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND, wound_clothing = FALSE)
	victim.emote("scream")
	victim.Knockdown(3 SECONDS)

/// Anyone can cut the strand with something sharp.
/datum/hv_gut_tether/proc/on_guts_item_interaction(obj/item/source, mob/living/user, obj/item/tool, list/modifiers)
	SIGNAL_HANDLER
	if(!connected() || !tool.get_sharpness())
		return NONE
	INVOKE_ASYNC(src, PROC_REF(cut_with), user, tool)
	return ITEM_INTERACT_SUCCESS

/datum/hv_gut_tether/proc/can_cut()
	return !QDELETED(src) && connected()

/datum/hv_gut_tether/proc/cut_with(mob/living/user, obj/item/tool)
	user.visible_message(span_danger("[user] cuts at [victim]'s guts with [tool]!"), span_danger("You cut at [victim == user ? "your" : "[victim]'s"] guts with [tool]."))
	playsound(guts, 'sound/items/weapons/slice.ogg', 60, TRUE)
	if(!do_after(user, 1 SECONDS, target = guts, extra_checks = CALLBACK(src, PROC_REF(can_cut))))
		return
	tear(FALSE)

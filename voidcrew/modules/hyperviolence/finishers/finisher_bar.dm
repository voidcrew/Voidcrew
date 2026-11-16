/**
 * # Execution bars
 *
 * tg's progress bar over someone doing an execution or a finisher, from the start of the move to the kill,
 * shown to everyone who can see them. tg's do_after bar is a client image only its user sees; this is an
 * object on the executioner's tile instead, so BYOND shows it to whoever has that tile in view (the victim,
 * bystanders, ghosts) and to anyone who walks into view while it runs, with nothing to keep track of.
 * It draws on tg's progress bar plane, so it sits above every body whatever the rows are.
 *
 * Users: /datum/hv_finisher (every finisher, chrome or boss), gun executions and the Mantis impale.
 */

/// Matches tg's PROGRESSBAR_HEIGHT: how far a bar stacks above another
#define HV_EXEC_BAR_HEIGHT 6
/// Matches tg's PROGRESSBAR_ANIMATION_TIME: the fade in and out
#define HV_EXEC_BAR_FADE 5

/obj/effect/abstract/hv_exec_bar
	name = "progress"
	icon = 'icons/effects/progressbar.dmi'
	icon_state = "prog_bar_0"
	plane = ABOVE_HUD_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	appearance_flags = APPEARANCE_UI_IGNORE_ALPHA
	anchored = TRUE
	/// Who is doing the execution; the bar stands over them
	var/mob/living/owner
	/// How long from the start to the kill
	var/total = 1
	/// world.time it began
	var/started_at = 0
	/// Set once it is fading out
	var/ending = FALSE
	/// The next refill of the bar
	var/update_timer
	/// Height it rests at over the owner
	var/rest_z = 0

/obj/effect/abstract/hv_exec_bar/Initialize(mapload, mob/living/executioner, total)
	. = ..()
	if(QDELETED(executioner) || !isnum(total) || total <= 0)
		return INITIALIZE_HINT_QDEL
	owner = executioner
	src.total = total
	started_at = world.time
	// Centred over the top of their sprite, however big it is (a 64px boss is drawn up from its tile, shifted left by half the extra width)
	var/list/icon_size = executioner.icon ? get_icon_dimensions(executioner.icon) : list("width" = ICON_SIZE_X, "height" = ICON_SIZE_Y)
	pixel_w = executioner.base_pixel_x + (icon_size["width"] - ICON_SIZE_X) / 2
	// Above any do_after bars the executioner already has over themselves
	var/list/own_bars = LAZYACCESS(executioner.progressbars, executioner)
	rest_z = executioner.base_pixel_y + icon_size["height"] + HV_EXEC_BAR_HEIGHT * length(own_bars)
	alpha = 0
	animate(src, pixel_z = rest_z, alpha = 255, time = HV_EXEC_BAR_FADE, easing = SINE_EASING)
	RegisterSignal(owner, COMSIG_QDELETING, PROC_REF(on_owner_deleted))
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_owner_moved))
	tick()

/obj/effect/abstract/hv_exec_bar/Destroy()
	if(update_timer)
		deltimer(update_timer)
		update_timer = null
	if(owner)
		UnregisterSignal(owner, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED))
		owner = null
	return ..()

/// Fills the bar to how far along the move is. It holds full if the kill is a beat late.
/obj/effect/abstract/hv_exec_bar/proc/tick()
	update_timer = null
	if(ending)
		return
	var/progress = clamp((world.time - started_at) / total, 0, 1)
	icon_state = "prog_bar_[round(progress * 100, 5)]"
	if(progress >= 1)
		return
	update_timer = addtimer(CALLBACK(src, PROC_REF(tick)), max(world.tick_lag, total / 20), TIMER_STOPPABLE|TIMER_DELETE_ME)

/// Ends the bar: full when the kill landed, tg's failed look when it was called off. Fades out, then goes.
/obj/effect/abstract/hv_exec_bar/proc/finish(success)
	if(ending || QDELETED(src))
		return
	ending = TRUE
	if(update_timer)
		deltimer(update_timer)
		update_timer = null
	icon_state = success ? "prog_bar_100" : "[icon_state]_fail"
	animate(src, alpha = 0, time = HV_EXEC_BAR_FADE)
	QDEL_IN(src, HV_EXEC_BAR_FADE)

/obj/effect/abstract/hv_exec_bar/proc/on_owner_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/// Stays over the executioner. Walking off ends the move itself (each user checks that); the bar follows until it does.
/obj/effect/abstract/hv_exec_bar/proc/on_owner_moved(datum/source)
	SIGNAL_HANDLER
	if(isturf(owner.loc))
		abstract_move(owner.loc)
	else
		finish(FALSE)

/**
 * Puts a bar over [executioner] that fills over [total] deciseconds, seen by everyone who can see them.
 * Returns it, for the caller to finish(); null if there is nowhere to put it.
 */
/proc/hv_exec_bar_start(mob/living/executioner, total)
	if(QDELETED(executioner) || !isturf(executioner.loc) || !isnum(total) || total <= 0)
		return null
	var/obj/effect/abstract/hv_exec_bar/bar = new(executioner.loc, executioner, total)
	return QDELETED(bar) ? null : bar

#undef HV_EXEC_BAR_HEIGHT
#undef HV_EXEC_BAR_FADE

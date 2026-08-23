/**
 * # Text morph
 *
 * Animates one string into another, character by character, left to right,
 * with a short band of scrambled characters riding just ahead of the reveal
 * point so the transition reads as a transformation rather than a wipe.
 *
 * It does not know or care what it is animating. It just hands finished
 * frames to a callback, which is what lets the same datum drive runechat
 * maptext today and anything else later.
 *
 * Frames are strings, so the consumer can drop them straight into maptext.
 */
/datum/text_morph
	/// Starting text, split into renderable units.
	var/list/from_units
	/// Destination text, split into renderable units.
	var/list/to_units
	var/from_length = 0
	var/to_length = 0
	/// Total animation time.
	var/duration = TRANSLATION_MORPH_DURATION
	/// Characters of scramble ahead of the reveal point.
	var/scramble_width = TRANSLATION_MORPH_SCRAMBLE
	/// world.time when the animation started.
	var/start_time = 0
	/// Handle for the repeating frame timer.
	var/timer_id
	/// Invoked with the frame string every tick. Required.
	var/datum/callback/on_frame
	/// Invoked once when the animation completes or is cancelled. Optional.
	var/datum/callback/on_finish
	/// Set once we have finished, so a late timer tick cannot double-fire.
	var/finished = FALSE

/datum/text_morph/New(from_text, to_text, datum/callback/on_frame, datum/callback/on_finish, duration, scramble_width)
	. = ..()
	src.from_units = translation_charlist(from_text)
	src.to_units = translation_charlist(to_text)
	src.from_length = length(from_units)
	src.to_length = length(to_units)
	src.on_frame = on_frame
	src.on_finish = on_finish
	if(!isnull(duration))
		src.duration = duration
	if(!isnull(scramble_width))
		src.scramble_width = scramble_width

/datum/text_morph/Destroy(force)
	if(timer_id)
		deltimer(timer_id)
		timer_id = null
	on_frame = null
	on_finish = null
	from_units = null
	to_units = null
	return ..()

/**
 * Characters used for the scramble band.
 *
 * Deliberately ASCII only: the source text already supplies the Cyrillic, and
 * keeping the pool free of < > and & means a frame can never produce broken
 * markup.
 *
 * It must also exclude _ + | and ^. Every frame goes back through
 * apply_message_emphasis(), so two random plus signs landing in the same
 * frame would be read as +bold+ markup and wrap part of the line in <b>,
 * corrupting the animation. The scramble band must never be able to invent
 * emphasis that was not in the player's own text.
 */
/datum/text_morph/proc/scramble_pool()
	var/static/list/pool
	if(isnull(pool))
		pool = translation_charlist("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#%*=~")
	return pool

/// Starts the animation. Emits the first frame immediately so there is no gap.
/datum/text_morph/proc/start()
	if(finished || timer_id)
		return
	start_time = world.time
	timer_id = addtimer(CALLBACK(src, PROC_REF(advance)), TRANSLATION_MORPH_INTERVAL, TIMER_STOPPABLE | TIMER_LOOP)
	advance()

/// Stops early and jumps straight to the destination text.
/datum/text_morph/proc/skip_to_end()
	if(finished)
		return
	emit(build_frame(1))
	complete()

/datum/text_morph/proc/advance()
	if(finished)
		return
	var/elapsed = world.time - start_time
	var/progress = duration > 0 ? clamp(elapsed / duration, 0, 1) : 1
	emit(build_frame(progress))
	if(progress >= 1)
		complete()

/datum/text_morph/proc/emit(frame)
	if(on_frame)
		on_frame.Invoke(frame)

/datum/text_morph/proc/complete()
	if(finished)
		return
	finished = TRUE
	if(timer_id)
		deltimer(timer_id)
		timer_id = null
	if(on_finish)
		on_finish.Invoke()
	qdel(src)

/**
 * Builds a single frame.
 *
 * progress 0 gives the original text exactly, progress 1 gives the
 * destination text exactly. In between, the string length interpolates
 * between the two so a longer translation grows into place instead of
 * appearing all at once, and characters resolve left to right.
 */
/datum/text_morph/proc/build_frame(progress)
	if(progress <= 0)
		return jointext(from_units, "")
	if(progress >= 1)
		return jointext(to_units, "")

	var/frame_length = round(LERP(from_length, to_length, progress))
	frame_length = max(frame_length, 1)
	// How far the "settled" front has travelled through the destination text.
	var/revealed = to_length * progress
	var/list/pool = scramble_pool()
	var/pool_length = length(pool)
	var/list/frame = list()

	for(var/i in 1 to frame_length)
		if(i <= revealed && i <= to_length)
			// Already resolved.
			frame += to_units[i]
		else if(i <= revealed + scramble_width)
			// The churning band just ahead of the front.
			frame += pool[rand(1, pool_length)]
		else if(i <= from_length)
			// Not reached yet, still showing the original.
			frame += from_units[i]
		else
			// Translation is longer than the original and we have run out of
			// source characters to show, so churn until the front arrives.
			frame += pool[rand(1, pool_length)]

	return jointext(frame, "")

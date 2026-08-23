/**
 * # Runechat translation support
 *
 * Runechat maptext is rendered server side, which is what makes translating
 * it possible at all - but it also means the morph animation has to run in
 * DM, one maptext assignment per frame.
 *
 * The pieces needed to re-render the body text are captured in
 * generate_image() (see the VOIDCREW EDIT markers in
 * code/datums/chatmessage.dm) because they are locals there and there is no
 * clean hook to recover them afterwards.
 *
 * ## Known limitation
 *
 * When a message's text changes length, the bubbles stacked above it do not
 * re-stack. finish_image_generation() offsets every older bubble at the same
 * turf based on this one's measured height, and that has already happened by
 * the time a translation lands. grow_to_fit() therefore only ever grows the
 * box, never shrinks it, so text can never be clipped - but a translation
 * that is much taller than the original may visually crowd whatever is
 * sitting above it for the rest of its (short) lifespan. In practice a say
 * is one or two lines and lives five seconds, so this is rarely visible.
 */
/datum/chatmessage
	/// Opening wrapper spans, captured during generate_image().
	var/translate_wrapper_open
	/// Closing wrapper spans, captured during generate_image().
	var/translate_wrapper_close
	/// Icon prefixes (radio glyph, language glyph) that sit before the body.
	var/translate_prefix
	/// The body text currently being displayed, without wrapper or prefix.
	var/translate_body
	/// Handle for the scheduled qdel, so the fadeout can be pushed back.
	var/destruction_timer
	/// Copies of CHAT_MESSAGE_EOL_FADE / CHAT_MESSAGE_GRACE_PERIOD, which are
	/// #undef'd at the bottom of code/datums/chatmessage.dm.
	var/translate_eol_fade = 0
	var/translate_grace_period = 0

/// TRUE if this message captured enough state to be re-rendered later.
/datum/chatmessage/proc/can_retext()
	return !isnull(message) && !isnull(owned_by) && !isnull(translate_wrapper_open)

/// Renders body text through the captured wrapper.
/datum/chatmessage/proc/render_body(body)
	var/mob/viewer = owned_by?.mob
	var/emphasised = viewer ? viewer.apply_message_emphasis(body) : body
	return "[translate_wrapper_open][translate_prefix][emphasised][translate_wrapper_close]"

/**
 * Swaps the displayed body text.
 *
 * Deliberately does not re-measure - MeasureText() is expensive enough that
 * core defers it across ticks, and calling it once per animation frame per
 * client would be reckless. Size the box once up front with grow_to_fit()
 * instead.
 */
/datum/chatmessage/proc/set_display_text(body)
	if(!can_retext())
		return FALSE
	translate_body = body
	message.maptext = MAPTEXT(render_body(body))
	return TRUE

/**
 * Grows the maptext box so the given text will fit, if it does not already.
 *
 * Call once with the longest text the message will ever show (usually the
 * finished translation) before starting an animation. Only grows, so nothing
 * that currently fits can start clipping.
 */
/datum/chatmessage/proc/grow_to_fit(body)
	if(!can_retext())
		return FALSE
	var/measured
	WXH_TO_HEIGHT(owned_by.MeasureText(render_body(body), null, message.maptext_width), measured)
	var/wanted = measured * 1.25
	if(wanted > message.maptext_height)
		message.maptext_height = wanted
	return TRUE

/**
 * Pushes the fadeout back so a freshly translated bubble can actually be read.
 *
 * Without this the translation inherits whatever is left of the original five
 * second lifespan. A backend round trip plus the morph can easily eat a second
 * of that, leaving a long sentence on screen for less time than it takes to
 * read - and it is text the viewer has not seen before, unlike the original.
 *
 * Restarts the alpha timeline from now and reschedules the destruction timer.
 * Core only ever shortens lifespans (exponential decay in
 * finish_image_generation), so it never needed to move the qdel; lengthening
 * does, or the datum is deleted mid-fade and Destroy() stack traces.
 */
/datum/chatmessage/proc/extend_lifespan(extra_time)
	if(extra_time <= 0 || isnull(message) || isnull(owned_by) || !destruction_timer)
		return FALSE

	var/now = REALTIMEOFDAY
	var/time_spent = now - animate_start
	var/current_alpha = get_current_alpha(time_spent)

	// Whatever hold time was left, plus the extension.
	var/hold = max(0, animate_lifespan - translate_eol_fade - time_spent) + extra_time

	animate_start = now
	animate_lifespan = hold + translate_eol_fade

	message.alpha = current_alpha
	if(current_alpha < 255)
		// Already fading. Bring it back up rather than snapping to full.
		animate(message, alpha = 255, time = TRANSLATION_RUNECHAT_RECOVER_TIME)
		animate(alpha = 255, time = hold)
	else
		animate(message, alpha = 255, time = hold)
	animate(alpha = 0, time = translate_eol_fade)

	// The timer lives on SSrunechat, not SStimer. deltimer() defaults to
	// SStimer and would silently find nothing, leaving the original timer to
	// fire at the old time and delete us mid-fade.
	deltimer(destruction_timer, SSrunechat)
	var/datum/callback/reap = CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(qdel), src)
	destruction_timer = addtimer(reap, animate_lifespan + translate_grace_period, TIMER_DELETE_ME | TIMER_STOPPABLE, SSrunechat)
	return TRUE

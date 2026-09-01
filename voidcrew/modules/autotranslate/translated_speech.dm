/**
 * # Translated speech
 *
 * One of these exists per (listener, spoken line) pair while a translation is
 * in flight. It owns the pending indicator, the runechat morph, and the
 * message it sends to the chat panel, and it deletes itself once everything
 * has settled.
 *
 * ## Usage
 *
 * Order matters, because a cache hit resolves synchronously:
 *
 *   var/datum/translated_speech/handle = new(target_client, raw_message, "ru", "en")
 *   raw_message = handle.wrapped_text()           // inject before compose_message()
 *   var/datum/chatmessage/bubble = create_chat_message(...)
 *   handle.attach_runechat(bubble)                // optional
 *   handle.begin()                                // last
 *
 * If begin() returns FALSE nothing was dispatched, the handle has already
 * cleaned itself up, and the message displays untranslated as normal.
 *
 * Scope note: this is wired for mob say only. Radio, emotes, LOOC and the
 * rest are intentionally out of scope - radio does not even use the same chat
 * span, and emotes are excluded from IC language handling upstream.
 */
/datum/translated_speech
	/// Shared between DM and the chat panel so both agree which line this is.
	var/id
	/// Who is seeing this. Null once they disconnect.
	var/client/owner
	/// Text as originally displayed, html-encoded, no wrapper.
	var/original_text
	/// Filled in on success.
	var/translated_text
	var/state = TRANSLATION_PENDING
	var/source_language
	var/target_language

	/// The runechat bubble, if this listener had runechat enabled.
	var/datum/weakref/runechat_ref
	/// The body text as the bubble actually rendered it - already clipped to
	/// the viewer max_chat_length preference, which original_text is not.
	var/runechat_base
	/// Running morph, if any.
	var/datum/text_morph/active_morph
	/// Repeating timer for the runechat pending dots.
	var/pending_timer
	var/pending_index = 1
	/// Retries left while waiting for a bubble's image generation to finish.
	var/bind_attempts = 0

	/// Set once the chat panel has been told the outcome.
	var/chat_notified = FALSE

/datum/translated_speech/New(client/owner, original_text, source_language, target_language)
	. = ..()
	src.id = next_translation_id()
	src.owner = owner
	src.original_text = original_text
	src.source_language = source_language
	src.target_language = target_language
	if(owner)
		RegisterSignal(owner, COMSIG_QDELETING, PROC_REF(on_owner_deleted))

/datum/translated_speech/Destroy(force)
	stop_pending_indicator()
	if(active_morph)
		QDEL_NULL(active_morph)
	if(owner)
		UnregisterSignal(owner, COMSIG_QDELETING)
		owner = null
	runechat_ref = null
	return ..()

/datum/translated_speech/proc/on_owner_deleted(datum/source)
	SIGNAL_HANDLER
	owner = null
	qdel(src)

/**
 * The text to feed into the say pipeline in place of the raw message.
 *
 * The wrapper span survives compose_message() into the final chat HTML so the
 * panel can find this line later. Runechat strips spans during
 * generate_image(), so the maptext path is unaffected.
 */
/datum/translated_speech/proc/wrapped_text()
	return wrap_translatable(original_text, id)

/**
 * Registers the runechat bubble this listener got, if any.
 *
 * The bubble is very often not renderable yet at this point:
 * /datum/chatmessage/New() dispatches generate_image() through INVOKE_ASYNC,
 * and generate_image() parks itself on SSrunechat when the tick is already
 * over budget. So we take the reference now and bind to its text once it
 * exists, rather than testing can_retext() here and silently dropping the
 * runechat half of the effect whenever the server is busy.
 */
/datum/translated_speech/proc/attach_runechat(datum/chatmessage/bubble)
	if(isnull(bubble))
		return FALSE
	runechat_ref = WEAKREF(bubble)
	bind_attempts = 0
	try_bind_runechat()
	return TRUE

/**
 * Resolves the bubble and, the first time it is renderable, captures the body
 * text as it was actually rendered - already clipped to the viewer's
 * max_chat_length, which original_text is not.
 *
 * Returns null if the bubble is gone or not ready yet.
 */
/datum/translated_speech/proc/resolve_runechat()
	var/datum/chatmessage/bubble = runechat_ref?.resolve()
	if(isnull(bubble) || !bubble.can_retext())
		return null
	if(isnull(runechat_base))
		runechat_base = bubble.translate_body
	return bubble

/// Polls briefly for the bubble's image generation to finish, then starts the
/// pending indicator on it.
/datum/translated_speech/proc/try_bind_runechat()
	if(QDELETED(src) || state != TRANSLATION_PENDING)
		return
	var/datum/chatmessage/bubble = resolve_runechat()
	if(bubble)
		// Size for the indicator before showing it. Core measured the box for
		// the bare text, so appending dots can push a line out of a box that
		// was never measured to hold them - which reads as the message losing
		// characters the moment translation starts.
		bubble.grow_to_fit("[runechat_base][widest_pending_frame()]")
		start_pending_indicator()
		return
	// Distinguish "not ready yet" from "actually gone".
	if(isnull(runechat_ref?.resolve()))
		return
	bind_attempts++
	if(bind_attempts > TRANSLATION_BIND_MAX_ATTEMPTS)
		return
	addtimer(CALLBACK(src, PROC_REF(try_bind_runechat)), TRANSLATION_BIND_RETRY_INTERVAL)

/**
 * Dispatches the request. Call last.
 *
 * Returns FALSE if nothing could be dispatched, in which case this datum has
 * already deleted itself.
 */
/datum/translated_speech/proc/begin()
	if(!SSautotranslate.request_translation(original_text, source_language, target_language, CALLBACK(src, PROC_REF(on_result))))
		state = TRANSLATION_FAILED
		qdel(src)
		return FALSE
	return TRUE

/datum/translated_speech/proc/on_result(text, success)
	if(QDELETED(src))
		return
	stop_pending_indicator()

	if(!success || !istext(text) || !length(text))
		state = TRANSLATION_FAILED
		restore_runechat_original()
		push_chat_update()
		qdel(src)
		return

	state = TRANSLATION_DONE
	translated_text = text
	push_chat_update()
	start_runechat_morph()

/**
 * Tells the chat panel the outcome exactly once.
 *
 * Only the final text is sent - the panel plays its own animation. Streaming
 * twenty frames per message per client would put real traffic on the wire for
 * something the browser can do by itself.
 *
 * This goes through SSchat rather than straight down the tgui window, and
 * that is not incidental. BYOND's output() to the panel drops messages: it is
 * the whole reason SSchat carries sequence numbers and implements a resend
 * protocol (see chat/handlers.ts). A notice sent on the raw window channel
 * has no such protection and silently vanishes some of the time.
 *
 * Riding SSchat also fixes ordering for free. Payloads are delivered in
 * sequence, and the chat line is always queued before this, so the notice can
 * no longer overtake the line it refers to.
 */
/datum/translated_speech/proc/push_chat_update()
	if(chat_notified)
		return
	chat_notified = TRUE
	if(isnull(owner))
		// Silent here would be nasty to diagnose: runechat resolves through
		// the chatmessage's own client reference, so it keeps working while
		// chat quietly never hears anything.
		SSautotranslate.chat_updates_dropped++
		return
	SSautotranslate.chat_updates_sent++
	SSchat.queue(owner, list(
		// internal/ types are always accepted by every chat page and are
		// never combined with neighbouring messages.
		"type" = TRANSLATION_PANEL_MESSAGE,
		"id" = id,
		"status" = state,
		"original" = original_text,
		"text" = translated_text,
		// Milliseconds, so the panel can match the runechat timing.
		"duration" = TRANSLATION_MORPH_DURATION * 100,
		"scramble" = TRANSLATION_MORPH_SCRAMBLE,
	))

// -----------------------------------------------------------------------------
// Runechat pending indicator
// -----------------------------------------------------------------------------

/datum/translated_speech/proc/start_pending_indicator()
	if(pending_timer || isnull(runechat_ref))
		return
	pending_index = 1
	pending_timer = addtimer(CALLBACK(src, PROC_REF(advance_pending_indicator)), TRANSLATION_PENDING_INTERVAL, TIMER_STOPPABLE | TIMER_LOOP)
	// After arming the timer, so a bubble that vanished between binding and
	// now can actually stop it again.
	advance_pending_indicator()

/// The longest frame the pending indicator will ever show, for sizing.
/datum/translated_speech/proc/widest_pending_frame()
	var/list/frames = GLOB.translation_pending_frames
	var/widest = ""
	for(var/frame in frames)
		if(length(frame) > length(widest))
			widest = frame
	return widest

/datum/translated_speech/proc/stop_pending_indicator()
	if(!pending_timer)
		return
	deltimer(pending_timer)
	pending_timer = null

/datum/translated_speech/proc/advance_pending_indicator()
	var/datum/chatmessage/bubble = resolve_runechat()
	if(isnull(bubble))
		stop_pending_indicator()
		return
	var/list/frames = GLOB.translation_pending_frames
	var/frame = frames[pending_index]
	pending_index = (pending_index % length(frames)) + 1
	bubble.set_display_text("[runechat_base][frame]")

// -----------------------------------------------------------------------------
// Runechat morph
// -----------------------------------------------------------------------------

/datum/translated_speech/proc/start_runechat_morph()
	if(QDELETED(src))
		return

	var/datum/chatmessage/bubble = resolve_runechat()
	if(isnull(bubble))
		// A cache hit resolves synchronously, which can land before the
		// bubble's image has been generated. Give it the same short grace
		// period that binding gets before writing the runechat half off.
		if(!isnull(runechat_ref?.resolve()) && bind_attempts <= TRANSLATION_BIND_MAX_ATTEMPTS)
			bind_attempts++
			addtimer(CALLBACK(src, PROC_REF(start_runechat_morph)), TRANSLATION_BIND_RETRY_INTERVAL)
			return
		// Bubble faded out, or this listener has runechat off. Chat has been
		// notified, so we are done.
		qdel(src)
		return

	var/destination = clip_for_runechat(translated_text)
	// Size the box once, for the longest thing it will ever show. Intermediate
	// morph frames interpolate between the two lengths so they never exceed
	// this.
	bubble.grow_to_fit(destination)

	// Give the reader time on text they have not seen before. Whatever the
	// backend round trip and the morph cost has already come out of the
	// bubble's original five seconds.
	bubble.extend_lifespan(translation_read_time(destination))

	active_morph = new /datum/text_morph(
		runechat_base,
		destination,
		CALLBACK(src, PROC_REF(on_morph_frame)),
		CALLBACK(src, PROC_REF(on_morph_finished)),
	)
	active_morph.start()

/datum/translated_speech/proc/on_morph_frame(frame)
	var/datum/chatmessage/bubble = runechat_ref?.resolve()
	if(isnull(bubble))
		if(active_morph)
			QDEL_NULL(active_morph)
		qdel(src)
		return
	bubble.set_display_text(frame)

/datum/translated_speech/proc/on_morph_finished()
	// text_morph deletes itself once it has fired this.
	active_morph = null
	qdel(src)

/// Puts the bubble back to exactly what it was, used when a request fails
/// after the pending dots have already been drawn onto it.
/datum/translated_speech/proc/restore_runechat_original()
	var/datum/chatmessage/bubble = runechat_ref?.resolve()
	if(isnull(bubble))
		return
	bubble.set_display_text(runechat_base)

/// Runechat clips the body to the viewer max_chat_length preference. A
/// translation can be longer than what it replaces, so it gets the same
/// treatment or it would overflow the bubble.
/datum/translated_speech/proc/clip_for_runechat(text)
	var/limit = owner?.prefs?.read_preference(/datum/preference/numeric/max_chat_length)
	if(!limit)
		return text
	if(length_char(text) <= limit)
		return text
	return copytext_char(text, 1, limit + 1) + "..."

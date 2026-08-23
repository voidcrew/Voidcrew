/**
 * # Auto-translate debug verbs
 *
 * Lets the presentation layer be built and tuned before any backend exists.
 * The fake provider answers after a short delay with a mangled version of the
 * input, which is enough to drive the pending indicator, the morph, and the
 * length-change handling.
 *
 * The test verb also doubles as a worked example of the API - it does, by
 * hand, exactly what the say pipeline would do.
 */

ADMIN_VERB(autotranslate_test, R_DEBUG, "Test Translation Morph", "Fires a fake translated say at yourself, on both chat and runechat.", ADMIN_CATEGORY_DEBUG, message as text)
	var/mob/speaker = user.mob
	if(isnull(speaker))
		to_chat(user, span_warning("You need a mob for this."))
		return

	message = sanitize(copytext(message, 1, MAX_MESSAGE_LEN))
	if(!length(message))
		return

	// --- this block mirrors what the say pipeline would do, in order --------

	// 1. Make the handle. Nothing has been dispatched yet.
	var/datum/translated_speech/handle = new(user, message, "ru", "en")

	// 2. Wrap the spoken text so the chat panel can find it later, then build
	//    the chat line exactly as compose_message() would.
	var/wrapped = handle.wrapped_text()
	to_chat(
		user,
		span_game_say("<span class='name'>[speaker.name]</span> <span class='message'>says, \"[wrapped]\"</span>"),
		type = MESSAGE_TYPE_LOCALCHAT,
	)

	// 3. Runechat gets the unwrapped text - generate_image() strips spans, so
	//    the wrapper would be discarded anyway.
	var/datum/chatmessage/bubble = speaker.create_chat_message(speaker, null, message, list("say"))
	handle.attach_runechat(bubble)

	// 4. Feed a canned result straight in, instead of handle.begin().
	//
	//    This verb exists to exercise the presentation layer, so it must not
	//    depend on which provider happens to be installed. Going through the
	//    subsystem would hand your text to the real backend as ru->en, and
	//    English in gives you near-identical English back - a morph from X to
	//    X, which looks exactly like the feature being broken.
	//
	//    Use "Translation: Diagnose" to test the backend instead.
	var/datum/callback/canned_result = CALLBACK(handle, TYPE_PROC_REF(/datum/translated_speech, on_result), autotranslate_fake_translation(message), TRUE)
	addtimer(canned_result, 0.4 SECONDS)

	// -----------------------------------------------------------------------

	to_chat(user, span_notice("Fed a canned translation in. This tests the display only - use Translation: Diagnose for the backend."))
	BLACKBOX_LOG_ADMIN_VERB("Test Translation Morph")

ADMIN_VERB(autotranslate_set_debug_provider, R_DEBUG, "Translation: Use Debug Provider", "Installs the fake translation backend.", ADMIN_CATEGORY_DEBUG, latency_ds as num|null)
	var/datum/translation_provider/debug/provider = new()
	if(!isnull(latency_ds))
		provider.latency = latency_ds
	SSautotranslate.set_provider(provider)
	to_chat(user, span_notice("Translation provider is now [provider.name], latency [provider.latency / 10]s."))
	BLACKBOX_LOG_ADMIN_VERB("Translation Use Debug Provider")

ADMIN_VERB(autotranslate_disable, R_DEBUG, "Translation: Disable", "Removes the translation backend. Messages display untranslated.", ADMIN_CATEGORY_DEBUG)
	SSautotranslate.set_provider(new /datum/translation_provider/none())
	to_chat(user, span_notice("Translation disabled."))
	BLACKBOX_LOG_ADMIN_VERB("Translation Disable")

ADMIN_VERB(autotranslate_clear_cache, R_DEBUG, "Translation: Clear Cache", "Empties the translation cache.", ADMIN_CATEGORY_DEBUG)
	var/cleared = SSautotranslate.clear_cache()
	to_chat(user, span_notice("Cleared [cleared] cached translation\s."))
	BLACKBOX_LOG_ADMIN_VERB("Translation Clear Cache")

/**
 * Isolates the DM half from the panel half.
 *
 * Pushes one request straight through the subsystem with no chat line and no
 * runechat attached, and reports each stage. If this says the backend
 * answered but a real say still shows the failure marker, the problem is in
 * the panel; if it stalls here, it is server side.
 */
ADMIN_VERB(autotranslate_diagnose, R_DEBUG, "Translation: Diagnose", "Runs one translation end to end and reports each stage.", ADMIN_CATEGORY_DEBUG, message as text)
	message = sanitize(copytext_char(message, 1, MAX_MESSAGE_LEN))
	if(!length(message))
		message = "test"

	var/datum/translation_provider/current = SSautotranslate.provider
	var/list/report = list()
	report += span_boldnotice("Auto Translate diagnosis")
	report += "Provider: [current?.name || "NONE"]"
	report += "is_available(): [current?.is_available() ? "TRUE" : "FALSE"]"
	report += "supports(ru,en): [current?.supports("ru", "en") ? "TRUE" : "FALSE"]"
	report += "can_translate(ru,en): [SSautotranslate.can_translate("ru", "en") ? "TRUE" : "FALSE"]"
	report += "Subsystem can_fire: [SSautotranslate.can_fire ? "TRUE" : "FALSE"], initialized: [SSautotranslate.initialized ? "TRUE" : "FALSE"]"
	report += "Panel window: [isnull(user.tgui_panel?.window) ? "MISSING - chat updates cannot be delivered" : "present"]"
	report += "Source text: [message]"

	var/key = SSautotranslate.build_key(message, "ru", "en")
	report += "Cache key: [key]"
	report += "Already cached: [isnull(SSautotranslate.translation_cache[key]) ? "no" : "yes - will resolve synchronously"]"

	to_chat(user, boxed_message(jointext(report, "<br>")))

	if(!SSautotranslate.can_translate("ru", "en"))
		to_chat(user, span_warning("Nothing will be dispatched - no usable provider. Install one first."))
		return

	var/started = world.time
	var/dispatched = SSautotranslate.request_translation(
		message,
		"ru",
		"en",
		CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(autotranslate_report_result), user, started),
	)
	to_chat(user, span_notice("request_translation() returned [dispatched ? "TRUE" : "FALSE"]. Awaiting callback..."))
	if(!dispatched)
		to_chat(user, span_warning("Nothing dispatched, so no callback is coming."))

	BLACKBOX_LOG_ADMIN_VERB("Translation Diagnose")

/// Callback target for the diagnose verb.
/proc/autotranslate_report_result(client/user, started, result, success)
	if(isnull(user))
		return
	var/elapsed = (world.time - started) / 10
	if(success)
		to_chat(user, span_boldnotice("Translation callback after [elapsed]s: SUCCESS -> \"[result]\""))
	else
		to_chat(user, span_boldwarning("Translation callback after [elapsed]s: FAILED (result was null)"))

ADMIN_VERB(autotranslate_stats, R_DEBUG, "Translation: Stats", "Prints translation subsystem counters.", ADMIN_CATEGORY_DEBUG)
	to_chat(user, boxed_message(jointext(list(
		span_boldnotice("Auto Translate"),
		"Provider: [SSautotranslate.provider?.name || "none"]",
		"In flight: [length(SSautotranslate.active_requests)]",
		"Cached: [length(SSautotranslate.translation_cache)] / [SSautotranslate.max_cache_entries]",
		"Cache hits: [SSautotranslate.cache_hits], misses: [SSautotranslate.cache_misses]",
		"Dispatched: [SSautotranslate.requests_dispatched], deduplicated: [SSautotranslate.requests_deduplicated], failed: [SSautotranslate.requests_failed]",
		"Chat notices sent: [SSautotranslate.chat_updates_sent], dropped (no panel window): [SSautotranslate.chat_updates_dropped]",
	), "<br>")))
	BLACKBOX_LOG_ADMIN_VERB("Translation Stats")

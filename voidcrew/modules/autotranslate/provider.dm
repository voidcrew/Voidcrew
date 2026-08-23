/**
 * # Translation providers
 *
 * A provider is the thing that actually turns text in one language into text
 * in another. Nothing in this module knows how that happens - swap the
 * provider and the whole feature retargets.
 *
 * The contract is deliberately poll-based rather than callback-based, because
 * that is what rustg's async HTTP looks like: you kick a request off, then ask
 * every tick whether it is done. A future CTranslate2 provider fills in
 * begin() with a request to the local service and poll() with
 * request.is_complete().
 *
 * Providers must never block. begin() kicks work off, poll() reports on it.
 */

/// One unit of work. Created by SSautotranslate, handed to the provider.
/datum/translation_request
	/// Cache key this request was filed under.
	var/key
	/// Text as spoken, already html_encode()'d by the say pipeline.
	var/source_text
	var/source_language
	var/target_language
	/// Filled in by the provider on success.
	var/result
	/// Set by the provider (or the subsystem, on timeout) on failure.
	var/errored = FALSE
	var/error_reason
	/// world.time the request was dispatched.
	var/started_at = 0
	/// Callbacks waiting on this exact text. Invoked with (result, success).
	var/list/datum/callback/subscribers
	/// Free-form scratch space for the provider (an http_request, a job id...).
	var/provider_state

/datum/translation_request/New(key, source_text, source_language, target_language)
	. = ..()
	src.key = key
	src.source_text = source_text
	src.source_language = source_language
	src.target_language = target_language
	src.subscribers = list()

/datum/translation_request/Destroy(force)
	subscribers = null
	provider_state = null
	return ..()

/// Marks the request finished. Providers call one of these two from poll().
/datum/translation_request/proc/succeed(translated_text)
	result = translated_text
	errored = FALSE

/datum/translation_request/proc/fail(reason)
	errored = TRUE
	error_reason = reason


/**
 * Abstract provider. Subclass this to add a backend.
 */
/datum/translation_provider
	/// Shown in the subsystem stat entry and admin output.
	var/name = "Abstract"

/// Whether this provider is configured and usable right now.
/datum/translation_provider/proc/is_available()
	return FALSE

/// Whether this provider can handle a given direction.
/datum/translation_provider/proc/supports(source_language, target_language)
	return FALSE

/// Kick off the work. Must not block.
/datum/translation_provider/proc/begin(datum/translation_request/request)
	CRASH("begin() not implemented on [type]")

/// Called every subsystem tick for every in-flight request.
/// Return TRUE once the request is resolved, having called succeed() or fail().
/datum/translation_provider/proc/poll(datum/translation_request/request)
	CRASH("poll() not implemented on [type]")

/// Called when the subsystem gives up on a request, so the provider can clean
/// up whatever begin() allocated.
/datum/translation_provider/proc/abort(datum/translation_request/request)
	return


/**
 * The default. Does nothing, reports unavailable. With this installed the
 * whole feature is inert: messages display normally and no pending indicator
 * is ever shown.
 */
/datum/translation_provider/none
	name = "None"

/datum/translation_provider/none/is_available()
	return FALSE

/datum/translation_provider/none/supports(source_language, target_language)
	return FALSE


/**
 * Fake backend for working on the presentation layer without a model.
 *
 * Resolves after a configurable delay with a deterministic mangling of the
 * input, which is enough to exercise the pending indicator, the morph, and
 * the length-change handling. Never ship with this selected.
 */
/datum/translation_provider/debug
	name = "Debug (fake)"
	/// How long to pretend the backend took.
	var/latency = 0.4 SECONDS
	/// If set, every request resolves to exactly this string.
	var/forced_result
	/// Percentage of requests that fail, for exercising the failure path.
	var/failure_chance = 0

/datum/translation_provider/debug/is_available()
	return TRUE

/datum/translation_provider/debug/supports(source_language, target_language)
	return TRUE

/datum/translation_provider/debug/begin(datum/translation_request/request)
	// "Scheduling" is just remembering when we are allowed to answer.
	request.provider_state = world.time + latency

/datum/translation_provider/debug/poll(datum/translation_request/request)
	if(world.time < request.provider_state)
		return FALSE
	if(failure_chance && prob(failure_chance))
		request.fail("debug provider synthetic failure")
		return TRUE
	request.succeed(forced_result || autotranslate_fake_translation(request.source_text))
	return TRUE

/**
 * Produces something visibly different from the input, with a different
 * length, so the morph has something to chew on.
 *
 * Global rather than a provider method because the presentation test verb
 * needs it too, and that verb deliberately does not go near a provider.
 */
/proc/autotranslate_fake_translation(text)
	var/list/words = splittext(text, " ")
	var/list/out = list()
	for(var/word in words)
		if(!length(word))
			continue
		// Reverse each word. Uses the char list so multi-byte input survives.
		var/list/units = translation_charlist(word)
		var/list/reversed = list()
		for(var/i in length(units) to 1 step -1)
			reversed += units[i]
		out += jointext(reversed, "")
	return jointext(out, " ")
